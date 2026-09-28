import hashlib
import secrets
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


@router.post("/register", status_code=201)
def register(
    payload: RegisterRequest,
    request: Request,
    users: UserRepository = Depends(get_users),
    service=Depends(get_verification),
):
    throttle(database(request), "register", request.client.host, 5, 3600)
    providers = Providers(get_settings())
    providers.sms_ready()
    providers.email_ready()
    if users.by_email(str(payload.email)):
        raise HTTPException(
            409,
            "An account with that email already exists. Sign in to resend verification.",
        )
    if database(request).users.find_one({"phone": payload.phone}):
        raise HTTPException(409, "An account with this phone already exists")
    user = UserService(users).create(
        str(payload.email),
        payload.password,
        Role.CUSTOMER,
        phone=payload.phone,
        name=payload.name,
    )
    # A delivery failure leaves a recoverable unverified account; authenticated resend is available.
    deliver_phone(user, service, providers)
    deliver_email(user, service, providers)
    return {
        "id": user.id,
        "phone_verification_required": True,
        "email_verification_required": True,
    }


@router.post("/send-phone-otp", status_code=202)
def send_phone_otp(
    payload: OtpRequest,
    request: Request,
    user=Depends(get_current_user),
    service=Depends(get_verification),
):
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
    if user.phone != payload.phone:
        raise HTTPException(403, "Phone does not belong to this account")
    service.verify_phone(payload.phone, payload.code)
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
