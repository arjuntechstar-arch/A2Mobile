import hashlib
import hmac
import secrets
import time
from pydantic import BaseModel, Field, EmailStr
from datetime import timedelta
from urllib.parse import quote

from fastapi import APIRouter, Depends, HTTPException, Request

from app.config import get_settings
from app.dependencies import as_current_user, get_current_user, get_users
from app.models import (
    CurrentUser,
    LoginRequest,
    RefreshRequest,
    TokenPair,
    UserRecord,
    RegisterRequest,
    OtpRequest,
    OtpVerification,
    EmailVerification,
    Role,
    EmailRequest,
    ResetPasswordRequest,
)
from app.security import verify_password, hash_password
from app.services.users import UserRepository, UserService
from app.services.verification import VerificationService
from app.services.providers import Providers
from app.services.sessions import throttle, issue_tokens, consume_refresh
from app.timeutils import utcnow
from app.services.firebase_phone import verify_phone_token

router = APIRouter(prefix="/auth", tags=["authentication"])


def database(request):
    return request.app.state.database.database


def get_verification(request: Request):
    return VerificationService(database(request), get_settings().jwt_secret)


def deliver_phone(user, service, providers):
    providers.sms_ready()
    code = service.issue_phone(user.phone)
    providers.send_sms(
        user.phone,
        f"Your Mobile Shop verification code is {code}. It expires in 10 minutes. Do not share it.",
    )


def deliver_email(user, service, providers):
    providers.email_ready()
    token = service.issue_email(user.id)
    link = (
        providers.settings.public_app_url.rstrip("/") + "/?verify_email=" + quote(token)
    )
    providers.send_email(
        str(user.email),
        "Verify your email",
        f"Open this link to verify your email (valid for 24 hours):\n{link}",
    )


class SignupEmailRequest(BaseModel):
    email: EmailStr


class VerifiedRegistration(RegisterRequest):
    email_code: str = Field(min_length=8, max_length=8)
    firebase_id_token: str = Field(min_length=20, max_length=16384)


@router.post("/registration/email", status_code=202)
def registration_email(payload: SignupEmailRequest, request: Request):
    db = database(request)
    email = str(payload.email).lower()
    throttle(db, "signup-email-ip", request.client.host, 10, 3600)
    throttle(db, "signup-email", email, 3, 600)
    if db.users.find_one({"email": email}):
        raise HTTPException(409, "An account with this email already exists. Sign in.")
    settings = get_settings()
    providers = Providers(settings)
    providers.email_ready()
    code = secrets.token_hex(4).upper()
    digest = hmac.new(settings.jwt_secret.encode(), f"{email}:{code}".encode(), hashlib.sha256).hexdigest()
    db.signup_emails.update_one({"_id": email}, {"$set": {
        "digest": digest, "expires": utcnow() + timedelta(minutes=10), "attempts": 0}}, upsert=True)
    providers.send_email(email, "Verify your email to create your account",
                         f"Your account creation code is {code}. It expires in 10 minutes.")
    return {"status": "sent"}


@router.post("/register", status_code=201)
def register(payload: VerifiedRegistration, request: Request):
    from uuid import uuid4
    from pymongo import ReturnDocument
    from pymongo.errors import DuplicateKeyError
    db = database(request)
    settings = get_settings()
    throttle(db, "register", request.client.host, 10, 3600)
    if settings.phone_verification_provider != "firebase":
        raise HTTPException(503, "Firebase signup verification is not configured")
    email = str(payload.email).lower()
    challenge = db.signup_emails.find_one_and_update(
        {"_id": email, "expires": {"$gt": utcnow()}, "attempts": {"$lt": 5}},
        {"$inc": {"attempts": 1}}, return_document=ReturnDocument.AFTER)
    digest = hmac.new(settings.jwt_secret.encode(), f"{email}:{payload.email_code.upper()}".encode(), hashlib.sha256).hexdigest()
    if not challenge or not secrets.compare_digest(challenge["digest"], digest):
        raise HTTPException(400, "Invalid or expired email code")
    claims = verify_phone_token(payload.firebase_id_token, settings)
    checked_phone_claims(claims, payload.phone)
    user = UserRecord(id=str(uuid4()), email=email, name=payload.name, phone=payload.phone,
                      password_hash=hash_password(payload.password), role=Role.CUSTOMER,
                      phone_verified=True, email_verified=True)
    document = user.model_dump()
    document["_id"] = document.pop("id")
    def write(session):
        consumed = db.signup_emails.delete_one({"_id": email, "digest": digest,
            "expires": {"$gt": utcnow()}}, session=session)
        if not consumed.deleted_count:
            raise HTTPException(400, "Email code expired or already used")
        db.users.insert_one(document.copy(), session=session)
    try:
        request.app.state.database.transaction(write)
    except DuplicateKeyError:
        raise HTTPException(409, "An account with this email or phone already exists. Sign in.")
    return {"id": user.id, "phone_verified": True, "email_verified": True}


@router.post("/send-phone-otp", status_code=202)
def send_phone_otp(
    payload: OtpRequest,
    request: Request,
    user=Depends(get_current_user),
    service=Depends(get_verification),
):
    if get_settings().phone_verification_provider == "firebase":
        raise HTTPException(409, "Use Firebase phone verification in the app")
    if user.phone != payload.phone:
        raise HTTPException(403, "Phone does not belong to this account")
    throttle(database(request), "send-otp", user.id, 5, 3600)
    deliver_phone(user, service, Providers(get_settings()))
    return {"status": "sent"}


@router.post("/send-email-verification", status_code=202)
def send_email(
    request: Request, user=Depends(get_current_user), service=Depends(get_verification)
):
    throttle(database(request), "send-email", user.id, 5, 3600)
    deliver_email(user, service, Providers(get_settings()))
    return {"status": "sent"}


@router.post("/verify-phone-otp", response_model=CurrentUser)
def verify_phone_otp(
    payload: OtpVerification,
    user=Depends(get_current_user),
    users=Depends(get_users),
    service=Depends(get_verification),
):
    if get_settings().phone_verification_provider == "firebase":
        raise HTTPException(409, "Use Firebase phone verification in the app")
    if user.phone != payload.phone:
        raise HTTPException(403, "Phone does not belong to this account")
    service.verify_phone(payload.phone, payload.code)
    user.phone_verified = True
    users.save(user)
    return as_current_user(user)


def checked_phone_claims(claims, phone):
    if (not phone or claims.get("phone_number") != phone
            or claims.get("firebase", {}).get("sign_in_provider") != "phone"):
        raise HTTPException(403, "Verified phone does not match this account")
    authenticated_at = claims.get("auth_time")
    if not isinstance(authenticated_at, (int, float)) or not 0 <= time.time() - authenticated_at <= 600:
        raise HTTPException(401, "Phone verification expired. Request a new code.")


class FirebasePhoneRequest(BaseModel):
    id_token: str = Field(min_length=20, max_length=16384)


@router.post("/verify-phone-firebase", response_model=CurrentUser)
def verify_phone_firebase(payload: FirebasePhoneRequest, request: Request,
                          user=Depends(get_current_user), users=Depends(get_users)):
    settings = get_settings()
    if settings.phone_verification_provider != "firebase":
        raise HTTPException(409, "Firebase phone verification is not enabled")
    throttle(database(request), "firebase-phone", user.id, 10, 3600)
    claims = verify_phone_token(payload.id_token, settings)
    checked_phone_claims(claims, user.phone)
    user.phone_verified = True
    users.save(user)
    return as_current_user(user)


@router.post("/verify-email", response_model=CurrentUser)
def verify_email(
    payload: EmailVerification,
    users=Depends(get_users),
    service=Depends(get_verification),
):
    user = users.by_id(service.verify_email(payload.token))
    if user is None:
        raise HTTPException(400, "Verification account no longer exists")
    user.email_verified = True
    users.save(user)
    return as_current_user(user)


@router.post("/login", response_model=TokenPair)
def login(payload: LoginRequest, request: Request, users=Depends(get_users)):
    db = database(request)
    throttle(db, "login-ip", request.client.host, 60, 900)
    throttle(db, "login-account", str(payload.email).lower(), 15, 900)
    user = users.by_email(str(payload.email))
    if (
        user is None
        or not user.is_active
        or not verify_password(payload.password, user.password_hash)
    ):
        raise HTTPException(401, "Invalid email or password")
    return issue_tokens(db, user, get_settings())


@router.post("/refresh", response_model=TokenPair)
def refresh(payload: RefreshRequest, request: Request, users=Depends(get_users)):
    settings = get_settings()
    user = users.by_id(
        consume_refresh(database(request), payload.refresh_token, settings)
    )
    if user is None or not user.is_active:
        raise HTTPException(401, "Account is unavailable")
    return issue_tokens(database(request), user, settings)


@router.post("/logout")
def logout(payload: RefreshRequest, request: Request):
    try:
        consume_refresh(database(request), payload.refresh_token, get_settings())
    except HTTPException:
        pass
    return {"status": "signed_out"}


@router.get("/me", response_model=CurrentUser)
def me(user: UserRecord = Depends(get_current_user)):
    return as_current_user(user)


@router.post("/forgot-password", status_code=202)
def forgot_password(payload: EmailRequest, request: Request, users=Depends(get_users)):
    db = database(request)
    throttle(db, "reset-ip", request.client.host, 10, 3600)
    providers = Providers(get_settings())
    providers.email_ready()
    user = users.by_email(str(payload.email))
    if user:
        throttle(db, "reset-account", user.id, 3, 3600)
        token = secrets.token_urlsafe(32)
        digest = hashlib.sha256(token.encode()).hexdigest()
        db.password_resets.replace_one(
            {"_id": user.id},
            {
                "_id": user.id,
                "digest": digest,
                "expires": utcnow() + timedelta(minutes=30),
            },
            upsert=True,
        )
        link = (
            providers.settings.public_app_url.rstrip("/")
            + "/?reset_password="
            + quote(token)
        )
        providers.send_email(
            str(user.email),
            "Reset your password",
            f"Reset your password using this link within 30 minutes:\n{link}",
        )
    return {"status": "If this account exists, a reset email has been sent."}


@router.post("/reset-password")
def reset_password(
    payload: ResetPasswordRequest, request: Request, users=Depends(get_users)
):
    db = database(request)
    throttle(db, "reset-attempt", request.client.host, 20, 900)
    row = db.password_resets.find_one_and_delete(
        {
            "digest": hashlib.sha256(payload.token.encode()).hexdigest(),
            "expires": {"$gt": utcnow()},
        }
    )
    if not row:
        raise HTTPException(400, "Invalid or expired reset link")
    user = users.by_id(row["_id"])
    if not user:
        raise HTTPException(400, "Account is unavailable")
    user.password_hash = hash_password(payload.password)
    users.save(user)
    db.sessions.update_many({"user_id": user.id}, {"$set": {"revoked": True}})
    db.users.update_one({"_id": user.id}, {"$set": {"tokens_valid_after": utcnow()}})
    return {"status": "Password updated. Sign in again."}
