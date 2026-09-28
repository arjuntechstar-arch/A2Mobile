from datetime import datetime, timezone
from enum import StrEnum

from pydantic import BaseModel, EmailStr, Field


class Role(StrEnum):
    CUSTOMER = "customer"
    STORE_STAFF = "store_staff"
    ACCOUNTANT = "accountant"
    ADMIN = "admin"
    SUPER_ADMIN = "super_admin"


ROLE_PERMISSIONS: dict[Role, set[str]] = {
    Role.CUSTOMER: {"profile:read"},
    Role.STORE_STAFF: {"customer:read", "enrollment:read", "redemption:process"},
    Role.ACCOUNTANT: {"payment:read", "reconciliation:manage", "refund:read"},
    Role.ADMIN: {"customer:read", "customer:manage", "scheme:manage", "kyc:review", "payment:read", "report:read"},
    Role.SUPER_ADMIN: {"*"},
}


class UserRecord(BaseModel):
    id: str
    email: EmailStr
    password_hash: str
    role: Role
    is_active: bool = True
    phone: str | None = None
    phone_verified: bool = False
    email_verified: bool = False
    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))


class LoginRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)


class TokenPair(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"


class RefreshRequest(BaseModel):
    refresh_token: str


class CurrentUser(BaseModel):
    id: str
    email: EmailStr
    role: Role
    permissions: list[str]


class CreateAdminRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=12, max_length=128)
    role: Role = Role.ADMIN

class RegisterRequest(BaseModel):
    email: EmailStr
    phone: str = Field(pattern=r"^\+[1-9]\d{7,14}$")
    password: str = Field(min_length=12, max_length=128)
class OtpRequest(BaseModel): phone: str = Field(pattern=r"^\+[1-9]\d{7,14}$")
class OtpVerification(OtpRequest): code: str = Field(pattern=r"^\d{6}$")
class EmailVerification(BaseModel): token: str = Field(min_length=16)

class SchemeInput(BaseModel):
    code: str = Field(pattern=r"^[A-Z0-9_-]{3,32}$")
    name: str = Field(min_length=3, max_length=100)
    monthly_amount_paise: int = Field(gt=0)
    installment_count: int = Field(gt=0, le=60)
    benefit_paise: int = Field(ge=0)
class SchemeView(SchemeInput):
    id: str
    version: int
    active: bool

class KycStatus(StrEnum): NOT_SUBMITTED="NOT_SUBMITTED"; PENDING="PENDING"; VERIFIED="VERIFIED"; FAILED="FAILED"; REQUIRES_REVIEW="REQUIRES_REVIEW"
class KycSubmit(BaseModel): pan: str = Field(pattern=r"^[A-Z]{5}[0-9]{4}[A-Z]$")
class EnrollmentRequest(BaseModel): scheme_id: str; accepted_terms: bool
