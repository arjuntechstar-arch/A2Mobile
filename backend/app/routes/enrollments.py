from uuid import uuid4
import hashlib
import hmac
from urllib.parse import urlparse
from pydantic import BaseModel
from pymongo.errors import DuplicateKeyError
from fastapi import APIRouter, Depends, Header, HTTPException, Request, Query
from app.config import get_settings
from app.dependencies import get_current_user
from app.models import EnrollmentRequest, KycSubmit
from app.services.providers import Providers
from app.services.sessions import throttle
from app.services.schedules import installment_schedule
from app.timeutils import utcnow, as_utc
from app.routes.schemes import view

router = APIRouter(tags=["enrollment"])


@router.post("/kyc/pan/verify")
def submit_pan(payload: KycSubmit, request: Request, user=Depends(get_current_user)):
    if not payload.consent:
        raise HTTPException(422, "Consent to identity verification is required")
    if not user.phone_verified or not user.email_verified:
        raise HTTPException(422, "Verify your phone and email first")
    db = request.app.state.database.database
    throttle(db, "kyc", user.id, 5, 3600)
    result = Providers(get_settings()).verify_pan(payload.pan, payload.name)
    fingerprint = hmac.new(
        get_settings().jwt_secret.encode(), payload.pan.encode(), hashlib.sha256
    ).hexdigest()
    row = {
        "user_id": user.id,
        "pan_last4": payload.pan[-4:],
        "pan_fingerprint": fingerprint,
        **result,
        "verified_at": utcnow(),
        "consented_at": utcnow(),
    }
    db.kyc_verifications.replace_one({"user_id": user.id}, row, upsert=True)
    return {k: v for k, v in row.items() if k not in {"_id", "pan_fingerprint"}}


@router.get("/kyc/status")
def kyc_status(request: Request, user=Depends(get_current_user)):
    row = request.app.state.database.database.kyc_verifications.find_one(
        {"user_id": user.id}, {"_id": 0, "pan_fingerprint": 0}
    )
    return row or {"status": "NOT_SUBMITTED"}


class IdentityConsent(BaseModel):
    consent: bool


@router.post("/kyc/identity/start")
def start_identity(
    payload: IdentityConsent, request: Request, user=Depends(get_current_user)
):
    if not payload.consent or not user.phone_verified or not user.email_verified:
        raise HTTPException(422, "Verified contact details and consent are required")
    settings = get_settings()
    if not settings.public_app_url.startswith("https://"):
        raise HTTPException(
            503, "An HTTPS application URL must be configured for DigiLocker callbacks"
        )
    db = request.app.state.database.database
    if not db.kyc_verifications.find_one({"user_id": user.id, "status": "VERIFIED"}):
        raise HTTPException(422, "Verify your PAN first")
    throttle(db, "identity-start", user.id, 5, 3600)
    verification_id = uuid4().hex
    result = Providers(settings).cashfree(
        "POST",
        "digilocker",
        {
            "verification_id": verification_id,
            "document_requested": ["PAN"],
            "redirect_url": settings.public_app_url.rstrip("/") + "/?identity_return=1",
            "user_flow": "signin",
        },
    )
    url = result.get("url", "")
    parsed = urlparse(url)
    if parsed.scheme != "https" or not (parsed.hostname or "").endswith(
        ".cashfree.com"
    ):
        raise HTTPException(502, "Identity provider returned an invalid URL")
    db.identity_verifications.replace_one(
        {"_id": user.id},
        {
            "_id": user.id,
            "verification_id": verification_id,
            "provider_reference": result.get("reference_id"),
            "status": "PENDING",
            "created_at": utcnow(),
        },
        upsert=True,
    )
    return {"url": url}


@router.get("/kyc/identity/status")
def identity_status(request: Request, user=Depends(get_current_user)):
    db = request.app.state.database.database
    row = db.identity_verifications.find_one({"_id": user.id})
    if not row:
        return {"status": "NOT_SUBMITTED"}
    if row["status"] == "VERIFIED":
        return {"status": "VERIFIED"}
    throttle(db, "identity-poll", user.id, 20, 900)
    providers = Providers(get_settings())
    params = {"verification_id": row["verification_id"]}
    result = providers.cashfree("GET", "digilocker", params=params)
    state = result.get("status", "PENDING")
    if state == "AUTHENTICATED":
        document = providers.cashfree("GET", "digilocker/document/PAN", params=params)
        pan = document.get("pan", "")
        kyc = db.kyc_verifications.find_one({"user_id": user.id})
        fingerprint = hmac.new(
            get_settings().jwt_secret.encode(), pan.encode(), hashlib.sha256
        ).hexdigest()
        state = (
            "VERIFIED"
            if document.get("status") == "SUCCESS"
            and pan
            and kyc
            and hmac.compare_digest(fingerprint, kyc.get("pan_fingerprint", ""))
            else "REQUIRES_REVIEW"
        )
        # Retain no downloaded document, full PAN, address, DOB or photograph.
    db.identity_verifications.update_one(
        {"_id": user.id}, {"$set": {"status": state, "checked_at": utcnow()}}
    )
    return {"status": state}


@router.post("/enrollments", status_code=201)
def enroll(
    payload: EnrollmentRequest,
    request: Request,
    user=Depends(get_current_user),
    idempotency_key: str = Header(min_length=8, max_length=100),
):
    settings = get_settings()
    email_only = settings.app_environment == "development" and settings.local_email_only
    if not payload.accepted_terms or not user.email_verified or (not email_only and not user.phone_verified):
        raise HTTPException(
            422, "Verified contact details and accepted terms are required"
        )
    database = request.app.state.database
    enrollment_id = str(uuid4())
    settings = get_settings()
    skip_kyc = settings.app_environment == "development" and settings.local_skip_kyc

    def write(session):
        db = database.database
        previous = db.enrollments.find_one(
            {"user_id": user.id, "idempotency_key": idempotency_key}, session=session
        )
        if previous:
            if (
                previous["scheme_id"] != payload.scheme_id
                or previous["terms"]["version"] != payload.scheme_version
            ):
                raise HTTPException(
                    409, "This request key was already used for different terms"
                )
            return view(previous)
        kyc = db.kyc_verifications.find_one(
            {"user_id": user.id, "status": "VERIFIED"}, session=session
        )
        if not skip_kyc and (not kyc or not kyc.get("provider_reference")):
            raise HTTPException(422, "Provider-verified KYC is required")
        scheme = db.schemes.find_one(
            {
                "_id": payload.scheme_id,
                "active": True,
                "version": payload.scheme_version,
            },
            session=session,
        )
        if not scheme:
            raise HTTPException(
                409, "Scheme is unavailable or changed; review the current terms"
            )
        now = utcnow()
        policy = scheme["policy"]
        if policy.get("joining_opens_at") and now < as_utc(policy["joining_opens_at"]):
            raise HTTPException(422, "Joining has not opened")
        if policy.get("joining_closes_at") and now > as_utc(
            policy["joining_closes_at"]
        ):
            raise HTTPException(422, "Joining has closed")
        version = db.scheme_versions.find_one(
            {"scheme_id": payload.scheme_id, "version": payload.scheme_version},
            session=session,
        )
        terms = {**version["terms"], "version": version["version"]}
        row = {
            "_id": enrollment_id,
            "number": "ENR-" + enrollment_id[:8].upper(),
            "user_id": user.id,
            "scheme_id": payload.scheme_id,
            "terms": terms,
            "status": "ACTIVE",
            "accepted_at": now,
            "idempotency_key": idempotency_key,
            "kyc_reference": kyc.get("provider_reference") if kyc else None,
            "kyc_skipped_for_local_testing": skip_kyc,
            "phone_verification_skipped_for_local_testing": email_only,
        }
        db.enrollments.insert_one(row.copy(), session=session)
        schedule = installment_schedule(
            now, terms["installment_count"], terms["monthly_amount_paise"], policy
        )
        db.installments.insert_many(
            [{"enrollment_id": enrollment_id, **item} for item in schedule],
            session=session,
        )
        db.notifications.insert_one(
            {
                "user_id": user.id,
                "title": "Scheme activated",
                "body": f"You joined {terms['name']}.",
                "created_at": now,
                "read": False,
                "route": "/enrollments/" + enrollment_id,
            },
            session=session,
        )
        return view(row)

    try:
        return database.transaction(write)
    except DuplicateKeyError:
        previous = database.database.enrollments.find_one(
            {"user_id": user.id, "idempotency_key": idempotency_key}
        )
        if (
            previous
            and previous["scheme_id"] == payload.scheme_id
            and previous["terms"]["version"] == payload.scheme_version
        ):
            return view(previous)
        raise HTTPException(409, "An enrollment with this request key already exists")


@router.get("/enrollments")
def list_enrollments(
    request: Request,
    user=Depends(get_current_user),
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=100),
):
    db = request.app.state.database.database
    return [
        view(x)
        for x in db.enrollments.find({"user_id": user.id})
        .sort("accepted_at", -1)
        .skip(skip)
        .limit(limit)
    ]


@router.get("/enrollments/{enrollment_id}")
def get_enrollment(
    enrollment_id: str, request: Request, user=Depends(get_current_user)
):
    row = request.app.state.database.database.enrollments.find_one(
        {"_id": enrollment_id, "user_id": user.id}
    )
    if not row:
        raise HTTPException(404, "Enrollment not found")
    return view(row)


@router.get("/enrollments/{enrollment_id}/installments")
def installments(enrollment_id: str, request: Request, user=Depends(get_current_user)):
    db = request.app.state.database.database
    if not db.enrollments.find_one({"_id": enrollment_id, "user_id": user.id}):
        raise HTTPException(404, "Enrollment not found")
    return list(
        db.installments.find({"enrollment_id": enrollment_id}, {"_id": 0}).sort(
            "number", 1
        )
    )
