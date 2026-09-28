import hashlib
import hmac
from uuid import uuid4
from urllib.parse import quote
from fastapi import APIRouter, Depends, HTTPException, Request, Header, Query
from pymongo.errors import DuplicateKeyError
from app.config import get_settings
from app.dependencies import get_current_user, require_permission
from app.models import PaymentOrderRequest, PaymentVerification
from app.services.providers import Providers
from app.services.lifecycle import refresh_enrollment
from app.routes.schemes import view
from app.timeutils import utcnow, as_utc

router = APIRouter(tags=["payments"])


def order_view(row):
    return {
        "order_id": row.get("gateway_order_id"),
        "amount_paise": row["amount_paise"],
        "currency": "INR",
        "status": row["status"],
        "key_id": get_settings().razorpay_key_id,
    }


@router.post("/payments/orders")
def create_order(
    payload: PaymentOrderRequest, request: Request, user=Depends(get_current_user)
):
    database = request.app.state.database
    providers = Providers(get_settings())
    from app.services.providers import require_config

    require_config(
        providers.settings.razorpay_key_id, providers.settings.razorpay_key_secret
    )
    local_id = uuid4().hex

    def reserve(session):
        db = database.database
        enrollment = db.enrollments.find_one(
            {"_id": payload.enrollment_id, "user_id": user.id, "status": "ACTIVE"},
            session=session,
        )
        if not enrollment:
            raise HTTPException(422, "Enrollment is not payable")
        installment = db.installments.find_one(
            {
                "enrollment_id": payload.enrollment_id,
                "number": payload.installment_number,
            },
            session=session,
        )
        if not installment or installment["status"] not in {"DUE", "OVERDUE"}:
            raise HTTPException(422, "Installment is not payable")
        policy = enrollment["terms"]["policy"]
        if as_utc(installment["due_date"]) > utcnow() and not policy.get(
            "advance_payments_allowed", False
        ):
            raise HTTPException(422, "This installment opens on its scheduled due date")
        if (
            as_utc(installment["overdue_at"]) <= utcnow()
            and not enrollment["terms"]["policy"]["late_payments_allowed"]
        ):
            raise HTTPException(
                422, "The accepted terms do not permit late payments. Contact support."
            )
        existing = db.payment_orders.find_one(
            {
                "enrollment_id": payload.enrollment_id,
                "installment_number": payload.installment_number,
            },
            session=session,
        )
        if existing:
            return existing
        # Serialize order creation with cancellation of this enrollment.
        db.enrollments.update_one(
            {"_id": payload.enrollment_id, "status": "ACTIVE"},
            {"$inc": {"payment_revision": 1}},
            session=session,
        )
        row = {
            "_id": local_id,
            "enrollment_id": payload.enrollment_id,
            "user_id": user.id,
            "installment_number": payload.installment_number,
            "amount_paise": installment["amount_paise"],
            "currency": "INR",
            "status": "CREATING",
            "created_at": utcnow(),
        }
        db.payment_orders.insert_one(row.copy(), session=session)
        return row

    try:
        row = database.transaction(reserve)
    except DuplicateKeyError:
        row = database.database.payment_orders.find_one(
            {
                "enrollment_id": payload.enrollment_id,
                "installment_number": payload.installment_number,
            }
        )
    if row["_id"] != local_id:
        if row.get("gateway_order_id"):
            return order_view(row)
        raise HTTPException(
            409,
            "An order is being created or requires reconciliation. Do not submit another payment.",
        )
    try:
        result = providers.razorpay(
            "POST",
            "orders",
            {"amount": row["amount_paise"], "currency": "INR", "receipt": local_id},
        )
        if (
            not result.get("id")
            or result.get("amount") != row["amount_paise"]
            or result.get("currency") != "INR"
        ):
            raise HTTPException(502, "Gateway returned an inconsistent order")
    except HTTPException:
        database.database.payment_orders.update_one(
            {"_id": local_id}, {"$set": {"status": "RECONCILIATION_REQUIRED"}}
        )
        raise
    database.database.payment_orders.update_one(
        {"_id": local_id},
        {"$set": {"gateway_order_id": result["id"], "status": "CREATED"}},
    )
    return order_view({**row, "gateway_order_id": result["id"], "status": "CREATED"})


def reconcile_payment(database, gateway_payment):
    if gateway_payment.get("status") != "captured":
        return {"status": "pending", "payment_id": gateway_payment.get("id")}
    payment_id = gateway_payment["id"]

    def write(session):
        db = database.database
        prior = db.payments.find_one(
            {"gateway_payment_id": payment_id}, session=session
        )
        if prior:
            return {"status": prior["status"].lower(), "payment_id": payment_id}
        order = db.payment_orders.find_one(
            {"gateway_order_id": gateway_payment.get("order_id")}, session=session
        )
        if not order:
            raise HTTPException(409, "Unknown order; reconciliation required")
        if (
            gateway_payment.get("amount") != order["amount_paise"]
            or gateway_payment.get("currency") != "INR"
        ):
            raise HTTPException(
                409, "Gateway amount/currency does not match the installment"
            )
        enrollment = db.enrollments.find_one(
            {"_id": order["enrollment_id"]}, session=session
        )
        if not enrollment or enrollment["status"] != "ACTIVE":
            raise HTTPException(409, "Enrollment requires manual reconciliation")
        now = utcnow()
        updated = db.installments.update_one(
            {
                "enrollment_id": order["enrollment_id"],
                "number": order["installment_number"],
                "status": {"$in": ["DUE", "OVERDUE"]},
            },
            {
                "$set": {
                    "status": "PAID",
                    "payment_id": payment_id,
                    "paid_at": now,
                    "reconciled": True,
                }
            },
            session=session,
        )
        if not updated.modified_count:
            raise HTTPException(
                409,
                "Installment already has a different payment; reconciliation required",
            )
        row = {
            "_id": payment_id,
            "gateway_payment_id": payment_id,
            "order_id": order["gateway_order_id"],
            "user_id": order["user_id"],
            "enrollment_id": order["enrollment_id"],
            "installment_number": order["installment_number"],
            "amount_paise": order["amount_paise"],
            "gateway_fee_paise": gateway_payment.get("fee"),
            "gateway_tax_paise": gateway_payment.get("tax"),
            "currency": "INR",
            "status": "CAPTURED",
            "reconciled_at": now,
            "created_at": now,
        }
        db.payments.insert_one(row, session=session)
        db.payment_orders.update_one(
            {"_id": order["_id"]},
            {
                "$set": {
                    "status": "PAID",
                    "payment_id": payment_id,
                    "reconciled_at": now,
                }
            },
            session=session,
        )
        db.receipts.insert_one(
            {
                "_id": "RCPT-" + payment_id,
                "payment_id": payment_id,
                "user_id": order["user_id"],
                "enrollment_id": order["enrollment_id"],
                "installment_number": order["installment_number"],
                "amount_paise": order["amount_paise"],
                "currency": "INR",
                "issued_at": now,
                "description": "Scheme contribution receipt",
                "is_tax_invoice": False,
            },
            session=session,
        )
        db.notifications.insert_one(
            {
                "user_id": order["user_id"],
                "title": "Payment received",
                "body": f"Installment {order['installment_number']} was reconciled.",
                "route": "/payments/" + payment_id,
                "created_at": now,
                "read": False,
            },
            session=session,
        )
        refresh_enrollment(db, order["enrollment_id"], session=session)
        return {"status": "captured", "payment_id": payment_id}

    return database.transaction(write)


@router.post("/payments/{order_id}/verify")
def verify(
    order_id: str,
    payload: PaymentVerification,
    request: Request,
    user=Depends(get_current_user),
):
    settings = get_settings()
    row = request.app.state.database.database.payment_orders.find_one(
        {"gateway_order_id": order_id, "user_id": user.id}
    )
    if not row:
        raise HTTPException(404, "Order not found")
    expected = hmac.new(
        settings.razorpay_key_secret.encode(),
        f"{order_id}|{payload.razorpay_payment_id}".encode(),
        hashlib.sha256,
    ).hexdigest()
    if not settings.razorpay_key_secret or not hmac.compare_digest(
        expected, payload.razorpay_signature
    ):
        raise HTTPException(400, "Invalid payment signature")
    payment = Providers(settings).razorpay(
        "GET", "payments/" + quote(payload.razorpay_payment_id, safe="")
    )
    if payment.get("order_id") != order_id:
        raise HTTPException(409, "Payment does not belong to this order")
    return reconcile_payment(request.app.state.database, payment)


@router.post("/webhooks/razorpay")
async def webhook(
    request: Request,
    x_razorpay_signature: str = Header(default=""),
    x_razorpay_event_id: str = Header(default=""),
):
    body = await request.body()
    secret = get_settings().razorpay_webhook_secret
    if not secret or not hmac.compare_digest(
        hmac.new(secret.encode(), body, hashlib.sha256).hexdigest(),
        x_razorpay_signature,
    ):
        raise HTTPException(401, "Invalid webhook signature")
    event = await request.json()
    event_id = x_razorpay_event_id or hashlib.sha256(body).hexdigest()
    db = request.app.state.database.database
    if db.payment_events.find_one({"_id": event_id, "processed": True}):
        return {"status": "duplicate"}
    entity = event.get("payload", {}).get("payment", {}).get("entity", {})
    if entity.get("id") and event.get("event") in {"payment.captured", "order.paid"}:
        # Authoritative API read also covers out-of-order callback/webhook delivery.
        payment = Providers(get_settings()).razorpay(
            "GET", "payments/" + quote(entity["id"], safe="")
        )
        reconcile_payment(request.app.state.database, payment)
    db.payment_events.update_one(
        {"_id": event_id},
        {
            "$setOnInsert": {"event": event.get("event"), "received_at": utcnow()},
            "$set": {"processed": True},
        },
        upsert=True,
    )
    return {"status": "accepted"}


@router.get("/payments")
def history(
    request: Request,
    user=Depends(get_current_user),
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=100),
):
    return [
        view(x)
        for x in request.app.state.database.database.payments.find({"user_id": user.id})
        .sort("created_at", -1)
        .skip(skip)
        .limit(limit)
    ]


@router.get("/payments/{payment_id}/receipt")
def receipt(payment_id: str, request: Request, user=Depends(get_current_user)):
    row = request.app.state.database.database.receipts.find_one(
        {"payment_id": payment_id, "user_id": user.id}
    )
    if not row:
        raise HTTPException(404, "Receipt not found")
    return view(row)


@router.post("/admin/payments/{order_id}/reconcile")
def reconcile_order(
    order_id: str,
    request: Request,
    user=Depends(require_permission("reconciliation:manage")),
):
    db = request.app.state.database.database
    order = db.payment_orders.find_one({"gateway_order_id": order_id})
    if not order:
        raise HTTPException(404, "Order not found")
    payments = Providers(get_settings()).razorpay(
        "GET", "orders/" + quote(order_id, safe="") + "/payments"
    )
    return {
        "results": [
            reconcile_payment(request.app.state.database, p)
            for p in payments.get("items", [])
        ]
    }


@router.post("/admin/payments/orders/{local_id}/recover")
def recover_order(
    local_id: str,
    request: Request,
    user=Depends(require_permission("reconciliation:manage")),
):
    """Match a gateway order by our unique receipt after an ambiguous create timeout."""
    db = request.app.state.database.database
    order = db.payment_orders.find_one({"_id": local_id})
    if not order:
        raise HTTPException(404, "Order not found")
    if order.get("gateway_order_id"):
        return order_view(order)
    provider = Providers(get_settings())
    # Search bounded pages from the original request time; do not create a second order.
    earliest = max(0, int(order["created_at"].timestamp()) - 60)
    for skip in range(0, 1000, 100):
        data = provider.razorpay("GET", f"orders?from={earliest}&count=100&skip={skip}")
        items = data.get("items", [])
        for item in items:
            if item.get("receipt") == local_id:
                if (
                    item.get("amount") != order["amount_paise"]
                    or item.get("currency") != "INR"
                ):
                    raise HTTPException(
                        409, "Gateway receipt has inconsistent financial details"
                    )
                db.payment_orders.update_one(
                    {"_id": local_id, "gateway_order_id": {"$exists": False}},
                    {"$set": {"gateway_order_id": item["id"], "status": "CREATED"}},
                )
                return order_view(db.payment_orders.find_one({"_id": local_id}))
        if len(items) < 100:
            break
    raise HTTPException(
        409,
        "No matching gateway order found. Resolve with the provider before attempting a new charge.",
    )
