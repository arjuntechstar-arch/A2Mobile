from datetime import timedelta

import jwt
from fastapi import APIRouter, Depends, HTTPException, Request, status

from app.config import Settings, get_settings
from app.dependencies import as_current_user, get_current_user, get_users
from app.models import CurrentUser, LoginRequest, RefreshRequest, TokenPair, UserRecord, RegisterRequest, OtpRequest, OtpVerification, EmailVerification, Role
from app.security import create_token, decode_token, verify_password
from app.services.users import UserRepository
from app.services.users import UserService
from app.services.verification import VerificationService

router = APIRouter(prefix="/auth", tags=["authentication"])


def tokens_for(user: UserRecord, settings: Settings) -> TokenPair:
    return TokenPair(
        access_token=create_token(user, "access", timedelta(minutes=settings.access_token_minutes), settings),
        refresh_token=create_token(user, "refresh", timedelta(days=settings.refresh_token_days), settings),
    )


def get_verification(request: Request) -> VerificationService:
    return VerificationService(request.app.state.database.database, get_settings().jwt_secret)


@router.post("/register", status_code=status.HTTP_201_CREATED)
def register(payload: RegisterRequest, users: UserRepository = Depends(get_users), service: VerificationService = Depends(get_verification)):
    if users.by_email(str(payload.email)):
        raise HTTPException(status_code=409, detail="An account with that email already exists")
    user = UserService(users).create(str(payload.email), payload.password, Role.CUSTOMER)
    user.phone = payload.phone
    users.save(user)
    service.issue_phone(payload.phone)
    service.issue_email(user.id)
    return {"id": user.id, "phone_verification_required": True, "email_verification_required": True}


@router.post("/send-phone-otp", status_code=status.HTTP_202_ACCEPTED)
def send_phone_otp(payload: OtpRequest, service: VerificationService = Depends(get_verification)):
    service.issue_phone(payload.phone)
    return {"status": "accepted"}


@router.post("/verify-phone-otp", response_model=CurrentUser)
def verify_phone_otp(payload: OtpVerification, user: UserRecord = Depends(get_current_user), users: UserRepository = Depends(get_users), service: VerificationService = Depends(get_verification)):
    if user.phone != payload.phone:
        raise HTTPException(status_code=403, detail="Phone does not belong to this account")
    service.verify_phone(payload.phone, payload.code)
    user.phone_verified = True
    users.save(user)
    return as_current_user(user)


@router.post("/verify-email", response_model=CurrentUser)
def verify_email(payload: EmailVerification, users: UserRepository = Depends(get_users), service: VerificationService = Depends(get_verification)):
    user = users.by_id(service.verify_email(payload.token))
    if user is None:
        raise HTTPException(status_code=400, detail="Verification account no longer exists")
    user.email_verified = True
    users.save(user)
    return as_current_user(user)


@router.post("/login", response_model=TokenPair)
def login(payload: LoginRequest, users: UserRepository = Depends(get_users), settings: Settings = Depends(get_settings)) -> TokenPair:
    user = users.by_email(str(payload.email))
    if user is None or not user.is_active or not verify_password(payload.password, user.password_hash):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid email or password")
    return tokens_for(user, settings)


@router.post("/refresh", response_model=TokenPair)
def refresh(payload: RefreshRequest, users: UserRepository = Depends(get_users), settings: Settings = Depends(get_settings)) -> TokenPair:
    try:
        token = decode_token(payload.refresh_token, "refresh", settings)
    except jwt.PyJWTError:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid or expired refresh token")
    user = users.by_id(token["sub"])
    if user is None or not user.is_active:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Account is unavailable")
    return tokens_for(user, settings)


@router.get("/me", response_model=CurrentUser)
def me(user: UserRecord = Depends(get_current_user)) -> CurrentUser:
    return as_current_user(user)
