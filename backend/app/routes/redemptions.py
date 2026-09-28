from uuid import uuid4, uuid5, NAMESPACE_URL
from urllib.parse import quote
from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel, Field
from app.config import get_settings
from app.dependencies import get_current_user, require_permission
from app.services.providers import Providers
from app.services.verification import VerificationService
from app.services.sessions import throttle
from app.routes.schemes import view
from app.timeutils import utcnow, as_utc

router = APIRouter(tags=["redemptions"])


class RedemptionRequest(BaseModel):
    enrollment_id: str


@router.post("/redemptions", status_code=201)
def request_redemption(
    payload: RedemptionRequest, request: Request, user=Depends(get_current_user)
):
    database = request.app.state.database

    def write(session):
        db = database.database
        prior = db.redemptions.find_one(
            {"enrollment_id": payload.enrollment_id, "customer_id": user.id},
            session=session,
        )
        if prior:
            return view(prior)
        enrollment = db.enrollments.find_one(
            {"_id": payload.enrollment_id, "user_id": user.id, "status": "COMPLETED"},
            session=session,
        )
        if not enrollment or as_utc(enrollment["redeem_by"]) < utcnow():
            raise HTTPException(422, "Enrollment is not eligible for redemption")
        db.enrollments.update_one(
            {"_id": enrollment["_id"], "status": "COMPLETED"},
            {"$set": {"status": "REDEMPTION_PENDING"}},
            session=session,
        )
        item = {
            "_id": str(uuid4()),
            "enrollment_id": enrollment["_id"],
            "customer_id": user.id,
            "eligible_value_paise": enrollment["eligible_value_paise"],
            "status": "PENDING",
            "requested_at": utcnow(),
        }
        db.redemptions.insert_one(item.copy(), session=session)
        return view(item)

    return database.transaction(write)


@router.get("/redemptions")
def redemptions(request: Request, user=Depends(get_current_user)):
    return [
        view(x)
        for x in request.app.state.database.database.redemptions.find(
            {"customer_id": user.id}
        ).limit(100)
    ]


@router.post("/redemptions/{redemption_id}/send-otp")
def redemption_otp(
    redemption_id: str, request: Request, user=Depends(get_current_user)
):
    db = request.app.state.database.database
    if not db.redemptions.find_one(
        {"_id": redemption_id, "customer_id": user.id, "status": "PENDING"}
    ):
        raise HTTPException(404, "Pending redemption not found")
    if not user.phone_verified:
        raise HTTPException(422, "Verified phone required")
    providers = Providers(get_settings())
    providers.sms_ready()
    throttle(db, "redemption-otp", user.id, 5, 3600)
    service = VerificationService(db, get_settings().jwt_secret)
    code = service.issue_phone("redemption:" + redemption_id)
    providers.send_sms(
        user.phone,
        f"Your store redemption code is {code}. Share it only with staff when collecting your purchase. Valid for 10 minutes.",
    )
    return {"status": "sent"}


class RedemptionComplete(BaseModel):
    otp: str = Field(pattern=r"^\d{6}$")
    invoice_reference: str = Field(min_length=2, max_length=100)
    store_id: str
    product_reference: str = Field(min_length=2, max_length=200)
    invoice_value_paise: int = Field(gt=0)


@router.post("/admin/redemptions/{redemption_id}/complete")
def complete(
    redemption_id: str,
    payload: RedemptionComplete,
    request: Request,
    user=Depends(require_permission("redemption:process")),
):
    database = request.app.state.database
    db = database.database
    row = db.redemptions.find_one({"_id": redemption_id})
    if not row:
        raise HTTPException(404, "Redemption not found")
    if row["status"] == "COMPLETED":
        return view(row)
    if not db.stores.find_one({"_id": payload.store_id, "active": True}):
        raise HTTPException(422, "Active store required")
    if payload.invoice_value_paise < row["eligible_value_paise"]:
        raise HTTPException(422, "Invoice value must cover the redemption value")

    # Challenge consumption and the financial transition share one transaction.
    def write(session):
        from app.services.verification import VerificationService

        service = VerificationService(db, get_settings().jwt_secret)
        subject = "redemption:" + redemption_id
        challenge = db.otp_challenges.find_one_and_delete(
            {
                "phone": subject,
                "digest": service._digest(subject, payload.otp),
                "expires": {"$gt": utcnow()},
            },
            session=session,
        )
        if not challenge:
            raise HTTPException(400, "Invalid or expired redemption code")
        current = db.redemptions.find_one(
            {"_id": redemption_id, "status": "PENDING"}, session=session
        )
        if not current:
            raise HTTPException(409, "Redemption is unavailable")
        enrollment = db.enrollments.find_one(
            {"_id": current["enrollment_id"]}, session=session
        )
        if not enrollment or as_utc(enrollment["redeem_by"]) < utcnow():
            raise HTTPException(
                422, "The redemption validity period has ended; contact support"
            )
        data = {
            **payload.model_dump(exclude={"otp"}),
            "status": "COMPLETED",
            "processed_by": user.id,
            "redeemed_value_paise": current["eligible_value_paise"],
            "completed_at": utcnow(),
        }
        db.redemptions.update_one(
            {"_id": redemption_id, "status": "PENDING"}, {"$set": data}, session=session
        )
        updated = db.enrollments.update_one(
            {"_id": current["enrollment_id"], "status": "REDEMPTION_PENDING"},
            {"$set": {"status": "REDEEMED"}},
            session=session,
        )
        if not updated.modified_count:
            raise HTTPException(409, "Enrollment is unavailable")
        db.notifications.insert_one(
            {
                "user_id": current["customer_id"],
                "title": "Redemption complete",
                "body": "Your store redemption has been recorded.",
                "read": False,
                "created_at": utcnow(),
                "route": "/redemptions",
            },
            session=session,
        )
        return view({**current, **data})

    throttle(db, "redemption-verify", user.id, 10, 900)
    return database.transaction(write)


class Cancellation(BaseModel):
    reason: str = Field(min_length=5, max_length=1000)


@router.post("/enrollments/{enrollment_id}/cancel")
def cancel(
    enrollment_id: str,
    payload: Cancellation,
    request: Request,
    user=Depends(get_current_user),
):
    database = request.app.state.database

    def write(session):
        db = database.database
        prior = db.refunds.find_one(
            {"enrollment_id": enrollment_id, "user_id": user.id}, session=session
        )
        if prior:
            return view(prior)
        enrollment = db.enrollments.find_one(
            {"_id": enrollment_id, "user_id": user.id, "status": "ACTIVE"},
            session=session,
        )
        if not enrollment or not enrollment["terms"]["policy"]["cancellation_allowed"]:
            raise HTTPException(
                422, "Cancellation is unavailable under the accepted terms"
            )
        if db.payment_orders.count_documents(
            {
                "enrollment_id": enrollment_id,
                "status": {"$in": ["CREATING", "CREATED", "RECONCILIATION_REQUIRED"]},
            },
            session=session,
        ):
            raise HTTPException(
                409, "Resolve outstanding payment orders before cancellation"
            )
        payments = list(
            db.payments.find(
                {"enrollment_id": enrollment_id, "status": "CAPTURED"}, session=session
            )
        )
        contributions = sum(p["amount_paise"] for p in payments)
        deduction = min(
            contributions, enrollment["terms"]["policy"]["refund_deduction_paise"]
        )
        item = {
            "_id": str(uuid4()),
            "enrollment_id": enrollment_id,
            "user_id": user.id,
            "reason": payload.reason,
            "contributions_paise": contributions,
            "deduction_paise": deduction,
            "amount_paise": contributions - deduction,
            "status": "PENDING_APPROVAL",
            "created_at": utcnow(),
        }
        db.enrollments.update_one(
            {"_id": enrollment_id, "status": "ACTIVE"},
            {"$set": {"status": "CANCELLATION_PENDING"}},
            session=session,
        )
        db.refunds.insert_one(item.copy(), session=session)
        return view(item)

    return database.transaction(write)


class RefundDecision(BaseModel):
    approved: bool
    reason: str = Field(min_length=5, max_length=1000)


@router.post("/admin/refunds/{refund_id}/decision")
def refund_decision(
    refund_id: str,
    payload: RefundDecision,
    request: Request,
    user=Depends(require_permission("refund:manage")),
):
    database = request.app.state.database

    def write(session):
        db = database.database
        item = db.refunds.find_one({"_id": refund_id}, session=session)
        if not item:
            raise HTTPException(404, "Refund not found")
        if item["status"] != "PENDING_APPROVAL":
            return view(item)
        state = "APPROVED" if payload.approved else "REJECTED"
        db.refunds.update_one(
            {"_id": refund_id},
            {
                "$set": {
                    "status": state,
                    "decision_reason": payload.reason,
                    "approved_by": user.id,
                    "decided_at": utcnow(),
                }
            },
            session=session,
        )
        db.enrollments.update_one(
            {"_id": item["enrollment_id"], "status": "CANCELLATION_PENDING"},
            {"$set": {"status": "CANCELLED" if payload.approved else "ACTIVE"}},
            session=session,
        )
        return {**view(item), "status": state}

    return database.transaction(write)


@router.post("/admin/refunds/{refund_id}/execute")
def execute_refund(
    refund_id: str, request: Request, user=Depends(require_permission("refund:manage"))
):
    db = request.app.state.database.database
    refund = db.refunds.find_one(
        {"_id": refund_id, "status": {"$in": ["APPROVED", "PROCESSING", "PROCESSED"]}}
    )
    if not refund:
        raise HTTPException(409, "Approved refund not found")
    if refund["status"] == "PROCESSED":
        return view(refund)
    providers = Providers(get_settings())
    payments = list(
        db.payments.find(
            {"enrollment_id": refund["enrollment_id"], "status": "CAPTURED"}
        ).sort("_id", 1)
    )
    remaining = refund["amount_paise"]
    results = []
    for payment in payments:
        amount = min(remaining, payment["amount_paise"])
        if amount <= 0:
            break
        key = str(uuid5(NAMESPACE_URL, refund_id + ":" + payment["_id"]))
        # Gateway idempotency protects retries, including an ambiguous timeout.
        existing = next(
            (
                r
                for r in refund.get("gateway_refunds", [])
                if r["payment_id"] == payment["_id"]
            ),
            None,
        )
        if existing:
            result = providers.razorpay(
                "GET", "refunds/" + quote(existing["gateway_refund_id"], safe="")
            )
        else:
            result = providers.razorpay(
                "POST",
                "payments/" + quote(payment["_id"], safe="") + "/refund",
                {"amount": amount, "speed": "normal", "receipt": refund_id},
                headers={"X-Refund-Idempotency": key},
            )
        if result.get("payment_id") != payment["_id"] or result.get("amount") != amount:
            raise HTTPException(
                502, "Gateway refund response did not match the approved request"
            )
        results.append(
            {
                "payment_id": payment["_id"],
                "gateway_refund_id": result["id"],
                "amount_paise": amount,
                "status": result["status"],
            }
        )
        remaining -= amount
    if remaining:
        raise HTTPException(
            409, "Reconciled contributions do not cover the approved refund"
        )
    state = (
        "PROCESSED"
        if all(r["status"] == "processed" for r in results)
        else "PROCESSING"
    )
    db.refunds.update_one(
        {"_id": refund_id},
        {
            "$set": {
                "status": state,
                "gateway_refunds": results,
                "executed_by": user.id,
                "updated_at": utcnow(),
            }
        },
    )
    return view(db.refunds.find_one({"_id": refund_id}))


@router.get("/refunds")
def refunds(request: Request, user=Depends(get_current_user)):
    return [
        view(x)
        for x in request.app.state.database.database.refunds.find(
            {"user_id": user.id}
        ).limit(100)
    ]
