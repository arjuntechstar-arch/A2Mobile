from fastapi import APIRouter, Depends, HTTPException, status

from app.dependencies import as_current_user, get_users, require_permission
from app.models import CreateAdminRequest, CurrentUser, Role, UserRecord
from app.services.users import UserRepository, UserService
from pydantic import BaseModel
from fastapi import Request

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


@router.patch("/customers/{user_id}")
def customer_status(
    user_id: str,
    payload: AccountStatus,
    request: Request,
    actor=Depends(require_permission("customer:manage")),
):
    db = request.app.state.database.database
    result = db.users.update_one(
        {"_id": user_id, "role": Role.CUSTOMER}, {"$set": payload.model_dump()}
    )
    if not result.matched_count:
        raise HTTPException(404, "Customer not found")
    if not payload.is_active:
        db.sessions.update_many({"user_id": user_id}, {"$set": {"revoked": True}})
    return payload.model_dump()


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
