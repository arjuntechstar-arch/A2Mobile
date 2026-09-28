from fastapi import APIRouter, Depends, HTTPException, status

from app.dependencies import as_current_user, get_users, require_permission
from app.models import CreateAdminRequest, CurrentUser, Role, UserRecord
from app.services.users import UserRepository, UserService

router = APIRouter(prefix="/admin", tags=["admin"])


@router.post("/users", response_model=CurrentUser, status_code=status.HTTP_201_CREATED)
def create_admin(payload: CreateAdminRequest, _: UserRecord = Depends(require_permission("admin:manage")),
                 users: UserRepository = Depends(get_users)) -> CurrentUser:
    if payload.role == Role.CUSTOMER:
        raise HTTPException(status_code=422, detail="Customer accounts are created through customer onboarding")
    try:
        return as_current_user(UserService(users).create(str(payload.email), payload.password, payload.role))
    except ValueError as exc:
        raise HTTPException(status_code=409, detail=str(exc))
