from fastapi import APIRouter, Depends, HTTPException, status

from app.dependencies import as_current_user, get_users, require_permission
from app.models import CreateAdminRequest, CurrentUser, Role, UserRecord
from app.services.users import UserRepository, UserService
from pydantic import BaseModel, Field, EmailStr, ConfigDict
from fastapi import Request
from app.timeutils import utcnow

router = APIRouter(prefix="/admin", tags=["admin"])


@router.post("/users", response_model=CurrentUser, status_code=status.HTTP_201_CREATED)
def create_admin(
    payload: CreateAdminRequest,
    _: UserRecord = Depends(require_permission("admin:manage")),
    users: UserRepository = Depends(get_users),
) -> CurrentUser:
    if payload.role == Role.CUSTOMER:
        raise HTTPException(
            status_code=422,
            detail="Customer accounts are created through customer onboarding",
        )
    try:
        return as_current_user(
            UserService(users).create(
                str(payload.email), payload.password, payload.role
            )
        )
    except ValueError as exc:
        raise HTTPException(status_code=409, detail=str(exc))


class AccountStatus(BaseModel):
    is_active: bool


class CustomerUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")
    name: str | None = Field(default=None, min_length=2, max_length=120)
    email: EmailStr | None = None
    phone: str | None = Field(default=None, pattern=r"^\+[1-9]\d{7,14}$")
    is_active: bool | None = None


@router.patch("/customers/{user_id}")
def customer_status(
    user_id: str,
    payload: CustomerUpdate,
    request: Request,
    actor=Depends(require_permission("customer:manage")),
):
    database = request.app.state.database
    changes = payload.model_dump(exclude_unset=True)
    if not changes or any(value is None for value in changes.values()):
        raise HTTPException(422, "Provide non-empty customer fields")
    if "email" in changes:
        changes["email"] = str(changes["email"]).lower()
    def write(session):
        db = database.database
        user = db.users.find_one({"_id": user_id, "role": Role.CUSTOMER}, session=session)
        if not user:
            raise HTTPException(404, "Customer not found")
        updates = dict(changes)
        for field in ("email", "phone"):
            if field in changes and changes[field] != user.get(field):
                updates[field + "_verified"] = False
        if "email_verified" in updates:
            db.email_verifications.delete_many({"user_id": user_id}, session=session)
            db.password_resets.delete_many({"user_id": user_id}, session=session)
        if "phone_verified" in updates:
            db.otp_challenges.delete_many({"phone": user.get("phone")}, session=session)
            db.otp_challenges.delete_many({"phone": updates["phone"]}, session=session)
        db.users.update_one({"_id": user_id}, {"$set": updates}, session=session)
        if updates.get("is_active") is False or "email_verified" in updates or "phone_verified" in updates:
            db.sessions.update_many({"user_id": user_id}, {"$set": {"revoked": True}}, session=session)
        db.audit_logs.insert_one({"actor_id": actor.id, "action": "customer_updated", "user_id": user_id,
                                  "fields": list(updates), "created_at": utcnow()}, session=session)
        return updates
    from pymongo.errors import DuplicateKeyError
    try:
        return database.transaction(write)
    except DuplicateKeyError:
        raise HTTPException(409, "Email or phone already belongs to another account")


class StaffUpdate(AccountStatus):
    role: Role


@router.patch("/users/{user_id}")
def update_staff(
    user_id: str,
    payload: StaffUpdate,
    request: Request,
    actor=Depends(require_permission("admin:manage")),
):
    if user_id == actor.id:
        raise HTTPException(422, "Ask another super admin to change your access")
    if payload.role == Role.CUSTOMER:
        raise HTTPException(
            422, "Staff accounts cannot be converted into customer accounts"
        )
    database = request.app.state.database

    def write(session):
        db = database.database
        result = db.users.update_one(
            {"_id": user_id, "role": {"$ne": Role.CUSTOMER}},
            {"$set": payload.model_dump()},
            session=session,
        )
        if not result.matched_count:
            raise HTTPException(404, "Staff account not found")
        db.sessions.update_many(
            {"user_id": user_id}, {"$set": {"revoked": True}}, session=session
        )
        return payload.model_dump()

    return database.transaction(write)
