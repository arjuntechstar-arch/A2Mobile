import base64
import binascii
from pathlib import Path
from uuid import uuid4
from bson import ObjectId
from fastapi import APIRouter, Depends, HTTPException, Query, Request
from pydantic import BaseModel, Field
from typing import Literal
from app.dependencies import get_current_user, require_permission, as_current_user
from app.models import ProfileUpdate, SupportInput
from app.routes.schemes import view
from app.timeutils import utcnow
from app.services.encryption import encrypt_profile, decrypt_profile

router = APIRouter(tags=["operations"])


@router.get("/app-config")
def app_config():
    from app.config import get_settings

    settings = get_settings()
    # Only Firebase's PUBLIC client configuration is exposed, never service-account data.
    allowed = {
        "apiKey",
        "appId",
        "messagingSenderId",
        "projectId",
        "authDomain",
        "storageBucket",
        "iosBundleId",
    }
    return {
        "phoneVerificationProvider": settings.phone_verification_provider,
        "firebase": {
            platform: {key: value for key, value in options.items() if key in allowed}
            for platform, options in settings.firebase_client_options.items()
        },
        "vapidKey": settings.firebase_web_vapid_key,
    }


def db(request):
    return request.app.state.database.database


def identifier(value):
    return ObjectId(value) if ObjectId.is_valid(value) else value


@router.get("/me")
def profile(request: Request, user=Depends(get_current_user)):
    result = as_current_user(user).model_dump()
    stored = db(request).customer_profiles.find_one({"_id": user.id}, {"_id": 0}) or {}
    result["profile"] = (
        decrypt_profile(stored["encrypted"]) if "encrypted" in stored else stored
    )
    return result


@router.patch("/me")
def update_profile(
    payload: ProfileUpdate, request: Request, user=Depends(get_current_user)
):
    encrypted = encrypt_profile(payload.model_dump(exclude={"phone"}))
    values = {"name": payload.name}
    if payload.phone and payload.phone != user.phone:
        if db(request).users.find_one(
            {"phone": payload.phone, "_id": {"$ne": user.id}}
        ):
            raise HTTPException(409, "This phone is already registered")
        values.update(phone=payload.phone, phone_verified=False)
    db(request).users.update_one({"_id": user.id}, {"$set": values})
    db(request).customer_profiles.replace_one(
        {"_id": user.id}, {"_id": user.id, "encrypted": encrypted}, upsert=True
    )
    return {"status": "updated"}


@router.get("/dashboard")
def customer_dashboard(request: Request, user=Depends(get_current_user)):
    database = db(request)
    enrollments = list(database.enrollments.find({"user_id": user.id}))
    result = []
    for enrollment in enrollments:
        rows = list(
            database.installments.find({"enrollment_id": enrollment["_id"]}).sort(
                "number", 1
            )
        )
        paid = [i for i in rows if i["status"] == "PAID"]
        next_due = next((i for i in rows if i["status"] in {"DUE", "OVERDUE"}), None)
        result.append(
            {
                **view(enrollment),
                "paid_paise": sum(i["amount_paise"] for i in paid),
                "paid_installments": len(paid),
                "next_due": (
                    {k: v for k, v in next_due.items() if k != "_id"}
                    if next_due
                    else None
                ),
            }
        )
    return {
        "enrollments": result,
        "unread_notifications": database.notifications.count_documents(
            {"user_id": user.id, "read": False}
        ),
    }


@router.get("/notifications")
def notifications(
    request: Request,
    user=Depends(get_current_user),
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=100),
):
    return [
        view(x)
        for x in db(request)
        .notifications.find({"user_id": user.id})
        .sort("created_at", -1)
        .skip(skip)
        .limit(limit)
    ]


@router.patch("/notifications/{notification_id}/read")
def read_notification(
    notification_id: str, request: Request, user=Depends(get_current_user)
):
    result = db(request).notifications.update_one(
        {"_id": identifier(notification_id), "user_id": user.id},
        {"$set": {"read": True}},
    )
    if not result.matched_count:
        raise HTTPException(404, "Notification not found")
    return {"read": True}


class DeviceInput(BaseModel):
    token: str = Field(min_length=20, max_length=4096)
    platform: Literal["android", "ios", "web"]


@router.post("/notifications/devices")
def device(payload: DeviceInput, request: Request, user=Depends(get_current_user)):
    db(request).notification_devices.update_one(
        {"token": payload.token},
        {
            "$set": {
                "user_id": user.id,
                "platform": payload.platform,
                "updated_at": utcnow(),
            }
        },
        upsert=True,
    )
    return {"status": "registered"}


@router.delete("/notifications/devices")
def remove_device(
    payload: DeviceInput, request: Request, user=Depends(get_current_user)
):
    db(request).notification_devices.delete_one(
        {"token": payload.token, "user_id": user.id}
    )
    return {"status": "removed"}


@router.post("/support/tickets", status_code=201)
def ticket(payload: SupportInput, request: Request, user=Depends(get_current_user)):
    item = {
        "_id": str(uuid4()),
        "user_id": user.id,
        **payload.model_dump(),
        "status": "OPEN",
        "created_at": utcnow(),
        "replies": [],
    }
    db(request).support_tickets.insert_one(item.copy())
    return view(item)


@router.get("/support/tickets")
def tickets(
    request: Request,
    user=Depends(get_current_user),
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=100),
):
    return [
        view(x)
        for x in db(request)
        .support_tickets.find({"user_id": user.id})
        .sort("created_at", -1)
        .skip(skip)
        .limit(limit)
    ]


class TicketReply(BaseModel):
    message: str = Field(min_length=1, max_length=5000)
    status: Literal["OPEN", "IN_PROGRESS", "RESOLVED", "CLOSED"]


@router.patch("/admin/support/{ticket_id}")
def reply(
    ticket_id: str,
    payload: TicketReply,
    request: Request,
    user=Depends(require_permission("support:manage")),
):
    result = db(request).support_tickets.update_one(
        {"_id": ticket_id},
        {
            "$set": {"status": payload.status},
            "$push": {
                "replies": {
                    "message": payload.message,
                    "actor_id": user.id,
                    "created_at": utcnow(),
                }
            },
        },
    )
    if not result.matched_count:
        raise HTTPException(404, "Ticket not found")
    return {"status": payload.status}


# Each resource has an explicit permission and safe projection. No arbitrary collection access.
RESOURCES = {
    "users": (
        "users",
        "admin:manage",
        {"role": {"$ne": "customer"}},
        {"password_hash": 0, "tokens_valid_after": 0},
    ),
    "customers": (
        "users",
        "customer:read",
        {"role": "customer"},
        {"password_hash": 0, "tokens_valid_after": 0},
    ),
    "schemes": ("schemes", "scheme:manage", {}, {}),
    "enrollments": ("enrollments", "enrollment:read", {}, {}),
    "installments": ("installments", "enrollment:read", {}, {}),
    "kyc": ("kyc_verifications", "kyc:review", {}, {"pan_fingerprint": 0}),
    "payments": ("payments", "payment:read", {}, {}),
    "orders": ("payment_orders", "reconciliation:manage", {}, {}),
    "overdue": ("installments", "enrollment:read", {"status": "OVERDUE"}, {}),
    "completed": (
        "enrollments",
        "enrollment:read",
        {"status": {"$in": ["COMPLETED", "REDEEMED"]}},
        {},
    ),
    "redemptions": ("redemptions", "redemption:process", {}, {}),
    "refunds": ("refunds", "refund:read", {}, {}),
    "support": ("support_tickets", "support:manage", {}, {}),
    "audit": ("audit_logs", "audit:read", {}, {}),
    "notifications": ("notifications", "notification:manage", {}, {}),
    "stores": ("stores", "settings:manage", {}, {}),
    "banners": ("settings", "settings:manage", {"_id": "banner"}, {}),
    "settings": ("settings", "settings:manage", {}, {}),
}


@router.get("/admin/resources/{resource}")
def resources(
    resource: str,
    request: Request,
    user=Depends(get_current_user),
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=100),
):
    from app.models import ROLE_PERMISSIONS

    if resource not in RESOURCES:
        raise HTTPException(404, "Resource not found")
    collection, permission, query, projection = RESOURCES[resource]
    permissions = ROLE_PERMISSIONS[user.role]
    if "*" not in permissions and permission not in permissions:
        raise HTTPException(403, "Insufficient permission")
    cursor = (
        db(request)[collection]
        .find(query, projection)
        .sort("_id", -1)
        .skip(skip)
        .limit(limit)
    )
    items = [view(x) for x in cursor]
    customer_resources = {
        "enrollments",
        "installments",
        "kyc",
        "payments",
        "orders",
        "overdue",
        "completed",
        "redemptions",
        "refunds",
        "support",
        "notifications",
    }
    customer_ids = (
        {item["user_id"] for item in items if item.get("user_id")}
        if resource in customer_resources
        else set()
    )
    customer_names = (
        {
            str(customer["_id"]): customer.get("name")
            or customer.get("email")
            or "Customer"
            for customer in db(request).users.find(
                {"_id": {"$in": [identifier(value) for value in customer_ids]}},
                {"name": 1, "email": 1},
            )
        }
        if customer_ids
        else {}
    )
    for item in items:
        if resource in customer_resources and item.get("user_id"):
            item["customer_name"] = customer_names.get(
                str(item["user_id"]), "Unavailable customer"
            )
        if isinstance(item.get("terms"), dict) and item["terms"].get("name"):
            item["scheme_name"] = item["terms"]["name"]
    return {
        "items": items,
        "total": db(request)[collection].count_documents(query),
        "skip": skip,
        "limit": limit,
    }


@router.get("/admin/reports/summary")
def report(request: Request, user=Depends(require_permission("report:read"))):
    database = db(request)
    from datetime import timedelta, timezone
    from app.services.schedules import policy_timezone

    local_now = utcnow().astimezone(policy_timezone({}))
    day_start = local_now.replace(hour=0, minute=0, second=0, microsecond=0).astimezone(
        timezone.utc
    )
    month_start = local_now.replace(
        day=1, hour=0, minute=0, second=0, microsecond=0
    ).astimezone(timezone.utc)

    def contributions_since(start):
        items = list(
            database.payments.aggregate(
                [
                    {"$match": {"status": "CAPTURED", "created_at": {"$gte": start}}},
                    {"$group": {"_id": None, "total": {"$sum": "$amount_paise"}}},
                ]
            )
        )
        return items[0]["total"] if items else 0

    captured = list(
        database.payments.aggregate(
            [
                {"$match": {"status": "CAPTURED"}},
                {
                    "$group": {
                        "_id": None,
                        "amount": {"$sum": "$amount_paise"},
                        "fees": {"$sum": "$gateway_fee_paise"},
                    }
                },
            ]
        )
    )
    liability = list(
        database.enrollments.aggregate(
            [
                {"$match": {"status": {"$in": ["COMPLETED", "REDEMPTION_PENDING"]}}},
                {"$group": {"_id": None, "amount": {"$sum": "$terms.benefit_paise"}}},
            ]
        )
    )
    return {
        "active_schemes": database.schemes.count_documents({"active": True}),
        "due_today": database.installments.count_documents(
            {
                "status": {"$in": ["DUE", "OVERDUE"]},
                "due_date": {"$gte": day_start, "$lt": day_start + timedelta(days=1)},
            }
        ),
        "received_today_paise": contributions_since(day_start),
        "monthly_collection_paise": contributions_since(month_start),
        "customers": database.users.count_documents({"role": "customer"}),
        "verified_customers": database.users.count_documents(
            {"role": "customer", "phone_verified": True, "email_verified": True}
        ),
        "active_enrollments": database.enrollments.count_documents(
            {"status": "ACTIVE"}
        ),
        "completed_enrollments": database.enrollments.count_documents(
            {"status": "COMPLETED"}
        ),
        "overdue_installments": database.installments.count_documents(
            {"status": "OVERDUE"}
        ),
        "pending_kyc": database.kyc_verifications.count_documents(
            {"status": {"$in": ["PENDING", "REQUIRES_REVIEW"]}}
        ),
        "contributions_paise": captured[0]["amount"] if captured else 0,
        "gateway_fees_paise": captured[0]["fees"] if captured else 0,
        "benefit_liability_paise": liability[0]["amount"] if liability else 0,
        "pending_redemptions": database.redemptions.count_documents(
            {"status": "PENDING"}
        ),
    }


@router.get("/admin/reports/collections")
def collections_report(
    request: Request,
    user=Depends(require_permission("report:read")),
    group: Literal["day", "month", "scheme", "customer"] = "day",
):
    database = db(request)
    expression = {
        "day": {
            "$dateToString": {
                "format": "%Y-%m-%d",
                "date": "$created_at",
                "timezone": "Asia/Kolkata",
            }
        },
        "month": {
            "$dateToString": {
                "format": "%Y-%m",
                "date": "$created_at",
                "timezone": "Asia/Kolkata",
            }
        },
        "customer": "$user_id",
        "scheme": "$enrollment.scheme_id",
    }[group]
    pipeline = [{"$match": {"status": "CAPTURED"}}]
    if group == "scheme":
        pipeline += [
            {
                "$lookup": {
                    "from": "enrollments",
                    "localField": "enrollment_id",
                    "foreignField": "_id",
                    "as": "enrollment",
                }
            },
            {"$unwind": "$enrollment"},
        ]
    pipeline += [
        {
            "$group": {
                "_id": expression,
                "contributions_paise": {"$sum": "$amount_paise"},
                "count": {"$sum": 1},
                "gateway_fees_paise": {"$sum": "$gateway_fee_paise"},
            }
        },
        {"$sort": {"_id": -1}},
        {"$limit": 1000},
    ]
    return [{"group": x.pop("_id"), **x} for x in database.payments.aggregate(pipeline)]


class StoreInput(BaseModel):
    name: str = Field(min_length=2, max_length=200)
    address: str = Field(min_length=5, max_length=1000)
    phone: str = Field(pattern=r"^\+[1-9]\d{7,14}$")
    active: bool = True


@router.post("/admin/stores", status_code=201)
def create_store(
    payload: StoreInput,
    request: Request,
    user=Depends(require_permission("settings:manage")),
):
    item = {"_id": str(uuid4()), **payload.model_dump()}
    db(request).stores.insert_one(item.copy())
    return view(item)


class BannerSlide(BaseModel):
    title: str = Field(default="", max_length=120)
    body: str = Field(default="", max_length=500)
    # A 5 MB upload expands to about 7 MB when encoded as a data URL.
    image: str = Field(default="", max_length=4 * ((5 * 1024 * 1024 + 2) // 3) + 32)


class BannerInput(BaseModel):
    mode: Literal["content", "images"] = "content"
    title: str = Field(default="", max_length=120)
    body: str = Field(default="", max_length=500)
    slides: list[BannerSlide] = Field(default_factory=list, max_length=8)
    active: bool = True


def _save_banner_image(data_url: str, request: Request) -> str:
    prefix, separator, encoded = data_url.partition(",")
    allowed = {
        "data:image/jpeg;base64": ".jpg",
        "data:image/png;base64": ".png",
        "data:image/webp;base64": ".webp",
    }
    if not separator or prefix not in allowed:
        raise HTTPException(400, "Use a PNG, JPEG, or WebP banner image")
    try:
        binary = base64.b64decode(encoded, validate=True)
    except (ValueError, binascii.Error):
        raise HTTPException(400, "Banner image is invalid")
    if not binary or len(binary) > 5 * 1024 * 1024:
        raise HTTPException(400, "Banner images must be smaller than 5 MB")
    valid_image = (
        (prefix == "data:image/jpeg;base64" and binary.startswith(b"\xff\xd8\xff"))
        or (
            prefix == "data:image/png;base64"
            and binary.startswith(b"\x89PNG\r\n\x1a\n")
        )
        or (
            prefix == "data:image/webp;base64"
            and binary.startswith(b"RIFF")
            and binary[8:12] == b"WEBP"
        )
    )
    if not valid_image:
        raise HTTPException(400, "Banner image data is invalid")
    directory = Path(request.app.state.settings.upload_directory) / "banners"
    directory.mkdir(parents=True, exist_ok=True)
    filename = f"{uuid4()}{allowed[prefix]}"
    (directory / filename).write_bytes(binary)
    return f"/uploads/banners/{filename}"


@router.put("/admin/banner")
def update_banner(
    payload: BannerInput,
    request: Request,
    user=Depends(require_permission("settings:manage")),
):
    if payload.mode == "content" and not (
        payload.title.strip() or payload.body.strip()
    ):
        raise HTTPException(422, "Banner content needs a title or message")
    slides = []
    if payload.mode == "images":
        if not payload.slides:
            raise HTTPException(422, "Add at least one banner image")
        for slide in payload.slides:
            image = (
                _save_banner_image(slide.image, request)
                if slide.image.startswith("data:image/")
                else slide.image
            )
            if not image.startswith("/uploads/banners/"):
                raise HTTPException(400, "Banner image is invalid")
            slides.append(
                {
                    "title": slide.title.strip(),
                    "body": slide.body.strip(),
                    "image": image,
                }
            )
    item = {
        "_id": "banner",
        "mode": payload.mode,
        "title": payload.title.strip(),
        "body": payload.body.strip(),
        "slides": slides,
        "active": payload.active,
        "updated_at": utcnow(),
    }
    db(request).settings.replace_one({"_id": "banner"}, item, upsert=True)
    return view(item)


@router.get("/banner")
def public_banner(request: Request):
    item = db(request).settings.find_one({"_id": "banner", "active": True})
    return (
        view(item)
        if item
        else {"mode": "content", "title": "", "body": "", "slides": []}
    )


class ContentInput(BaseModel):
    title: str = Field(min_length=2, max_length=200)
    body: str = Field(min_length=1, max_length=20000)
    active: bool = True


@router.put("/admin/content/{key}")
def content(
    key: Literal["faq", "terms", "privacy", "contact"],
    payload: ContentInput,
    request: Request,
    user=Depends(require_permission("settings:manage")),
):
    db(request).settings.replace_one(
        {"_id": key},
        {"_id": key, **payload.model_dump(), "updated_at": utcnow()},
        upsert=True,
    )
    return {"status": "updated"}


@router.get("/content/{key}")
def public_content(
    key: Literal["faq", "terms", "privacy", "contact"], request: Request
):
    item = db(request).settings.find_one({"_id": key, "active": True})
    if not item:
        raise HTTPException(404, "The store has not published this content")
    return view(item)


class NotificationInput(BaseModel):
    user_id: str
    title: str = Field(min_length=2, max_length=120)
    body: str = Field(min_length=1, max_length=1000)


@router.post("/admin/notifications", status_code=201)
def send_notification(
    payload: NotificationInput,
    request: Request,
    user=Depends(require_permission("notification:manage")),
):
    if not db(request).users.find_one({"_id": payload.user_id}):
        raise HTTPException(404, "Customer not found")
    item = {
        "_id": str(uuid4()),
        **payload.model_dump(),
        "created_at": utcnow(),
        "read": False,
        "route": "/notifications",
    }
    db(request).notifications.insert_one(item.copy())
    return view(item)


class KycReview(BaseModel):
    status: Literal["FAILED", "REQUIRES_REVIEW"]
    reason: str = Field(min_length=5, max_length=1000)


@router.patch("/admin/kyc/{user_id}/review")
def review_kyc(
    user_id: str,
    payload: KycReview,
    request: Request,
    user=Depends(require_permission("kyc:review")),
):
    result = db(request).kyc_verifications.update_one(
        {"user_id": user_id},
        {
            "$set": {
                "status": payload.status,
                "review_reason": payload.reason,
                "reviewed_by": user.id,
                "reviewed_at": utcnow(),
            }
        },
    )
    if not result.matched_count:
        raise HTTPException(404, "KYC record not found")
    db(request).notifications.insert_one(
        {
            "user_id": user_id,
            "title": "KYC review update",
            "body": payload.reason,
            "read": False,
            "created_at": utcnow(),
            "route": "/profile",
        }
    )
    return {"status": payload.status}


@router.put("/admin/stores/{store_id}")
def update_store(
    store_id: str,
    payload: StoreInput,
    request: Request,
    user=Depends(require_permission("settings:manage")),
):
    result = db(request).stores.update_one(
        {"_id": store_id}, {"$set": payload.model_dump()}
    )
    if not result.matched_count:
        raise HTTPException(404, "Store not found")
    return {"status": "updated"}


@router.get("/admin/system/status")
def system_status(
    request: Request, user=Depends(require_permission("settings:manage"))
):
    from app.config import get_settings

    s = get_settings()
    return {
        "database_transactions": bool(
            request.app.state.database.client.admin.command("hello").get("setName")
        ),
        "razorpay_configured": bool(
            s.razorpay_key_id and s.razorpay_key_secret and s.razorpay_webhook_secret
        ),
        "sms_configured": bool(
            s.twilio_account_sid
            and s.twilio_auth_token
            and s.twilio_messaging_service_sid
        ),
        "email_configured": bool(
            s.email_smtp_host
            and s.email_smtp_username
            and s.email_smtp_password
            and s.email_from
        ),
        "kyc_configured": bool(s.cashfree_client_id and s.cashfree_client_secret),
        "push_configured": bool(s.firebase_credentials and s.firebase_client_options),
    }
