from datetime import datetime, timezone
from enum import StrEnum

from pydantic import (
    BaseModel,
    EmailStr,
    Field,
    ConfigDict,
    model_validator,
    field_validator,
)
from typing import Literal


class Role(StrEnum):
    CUSTOMER = "customer"
    STORE_STAFF = "store_staff"
    ACCOUNTANT = "accountant"
    ADMIN = "admin"
    SUPER_ADMIN = "super_admin"


ROLE_PERMISSIONS: dict[Role, set[str]] = {
    Role.CUSTOMER: {"profile:read"},
    Role.STORE_STAFF: {
        "customer:read",
        "enrollment:read",
        "redemption:process",
        "support:manage",
    },
    Role.ACCOUNTANT: {
        "payment:read",
        "enrollment:read",
        "reconciliation:manage",
        "refund:read",
        "refund:manage",
        "report:read",
    },
    Role.ADMIN: {
        "customer:read",
        "customer:manage",
        "scheme:manage",
        "enrollment:read",
        "kyc:review",
        "payment:read",
        "report:read",
        "support:manage",
        "notification:manage",
        "settings:manage",
        "audit:read",
    },
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
    name: str = ""
    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))


class PasswordRequest(BaseModel):
    @field_validator("password", check_fields=False)
    @classmethod
    def bcrypt_length(cls, value):
        if len(value.encode("utf-8")) > 72:
            raise ValueError("Password must fit within 72 UTF-8 bytes")
        return value


class LoginRequest(PasswordRequest):
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
    name: str = ""
    phone: str | None = None
    phone_verified: bool = False
    email_verified: bool = False


class CreateAdminRequest(PasswordRequest):
    email: EmailStr
    password: str = Field(min_length=12, max_length=128)
    role: Role = Role.ADMIN


class RegisterRequest(PasswordRequest):
    name: str = Field(min_length=2, max_length=120)
    email: EmailStr
    phone: str = Field(pattern=r"^\+[1-9]\d{7,14}$")
    password: str = Field(min_length=12, max_length=128)


class OtpRequest(BaseModel):
    phone: str = Field(pattern=r"^\+[1-9]\d{7,14}$")


class OtpVerification(OtpRequest):
    code: str = Field(pattern=r"^\d{6}$")


class EmailVerification(BaseModel):
    token: str = Field(min_length=16)


class SchemePolicy(BaseModel):
    model_config = ConfigDict(extra="forbid")
    joining_opens_at: datetime | None = None
    joining_closes_at: datetime | None = None
    due_rule: Literal["ANNIVERSARY", "FIXED_DAY"] = "ANNIVERSARY"
    due_day: int = Field(default=1, ge=1, le=28)
    timezone: Literal["Asia/Kolkata", "UTC"] = "Asia/Kolkata"
    advance_payments_allowed: bool = False
    grace_days: int = Field(default=7, ge=0, le=60)
    late_payments_allowed: bool = True
    cancellation_allowed: bool = True
    refund_deduction_paise: int = Field(default=0, ge=0)
    redemption_valid_days: int = Field(default=365, ge=1, le=3650)
    reminder_days: list[int] = Field(
        default_factory=lambda: [7, 3, 1, 0], max_length=10
    )
    terms_text: str = Field(min_length=20, max_length=20000)

    @model_validator(mode="after")
    def validate_policy(self):
        if self.joining_opens_at and self.joining_closes_at:
            if self.joining_closes_at <= self.joining_opens_at:
                raise ValueError("Joining close must follow opening")
        if any(day < 0 or day > 60 for day in self.reminder_days):
            raise ValueError("Reminder days must be between 0 and 60")
        return self


class SchemeInput(BaseModel):
    model_config = ConfigDict(extra="forbid")
    code: str = Field(pattern=r"^[A-Z0-9_-]{3,32}$")
    name: str = Field(min_length=3, max_length=100)
    monthly_amount_paise: int = Field(gt=0)
    installment_count: int = Field(gt=0, le=60)
    benefit_paise: int = Field(ge=0)
    policy: SchemePolicy


class SchemeView(SchemeInput):
    id: str
    version: int
    active: bool


class KycStatus(StrEnum):
    NOT_SUBMITTED = "NOT_SUBMITTED"
    PENDING = "PENDING"
    VERIFIED = "VERIFIED"
    FAILED = "FAILED"
    REQUIRES_REVIEW = "REQUIRES_REVIEW"


class KycSubmit(BaseModel):
    pan: str = Field(pattern=r"^[A-Z]{5}[0-9]{4}[A-Z]$")
    name: str = Field(min_length=2, max_length=120)
    consent: bool


class EnrollmentRequest(BaseModel):
    scheme_id: str
    scheme_version: int = Field(ge=1)
    accepted_terms: bool


class ProfileUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")
    name: str = Field(min_length=2, max_length=120)
    phone: str | None = Field(default=None, pattern=r"^\+[1-9]\d{7,14}$")
    address: str = Field(default="", max_length=1000)
    nominee_name: str = Field(default="", max_length=120)
    nominee_relationship: str = Field(default="", max_length=80)


class PaymentOrderRequest(BaseModel):
    enrollment_id: str
    installment_number: int = Field(ge=1, le=60)


class PaymentVerification(BaseModel):
    razorpay_payment_id: str = Field(pattern=r"^pay_[A-Za-z0-9]+$")
    razorpay_signature: str = Field(pattern=r"^[a-f0-9]{64}$")


class SupportInput(BaseModel):
    subject: str = Field(min_length=3, max_length=200)
    message: str = Field(min_length=5, max_length=5000)


class EmailRequest(BaseModel):
    email: EmailStr


class ResetPasswordRequest(PasswordRequest):
    token: str = Field(min_length=20, max_length=200)
    password: str = Field(min_length=12, max_length=72)
