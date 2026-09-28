from typing import Callable

import jwt
from fastapi import Depends, HTTPException, Request, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from app.config import Settings, get_settings
from app.models import ROLE_PERMISSIONS, CurrentUser, UserRecord
from app.security import decode_token
from app.services.users import MongoUserRepository, UserRepository

bearer = HTTPBearer(auto_error=False)


def get_users(request: Request) -> UserRepository:
    return MongoUserRepository(request.app.state.database)


def get_current_user(
    request: Request,
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer),
    settings: Settings = Depends(get_settings),
    users: UserRepository = Depends(get_users),
) -> UserRecord:
    if credentials is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="Authentication required"
        )
    try:
        claims = decode_token(credentials.credentials, "access", settings)
        user_id = claims["sub"]
    except jwt.PyJWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired access token",
        )
    user = users.by_id(user_id)
    if user is None or not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="Account is unavailable"
        )
    session = request.app.state.database.database.sessions.find_one(
        {"_id": claims.get("sid"), "user_id": user_id, "revoked": False}
    )
    if not session:
        raise HTTPException(401, "Session expired. Sign in again.")
    request.state.actor_id = user_id
    return user


def as_current_user(user: UserRecord) -> CurrentUser:
    permissions = ROLE_PERMISSIONS[user.role]
    return CurrentUser(
        id=user.id,
        email=user.email,
        role=user.role,
        permissions=sorted(permissions),
        name=user.name,
        phone=user.phone,
        phone_verified=user.phone_verified,
        email_verified=user.email_verified,
    )


def require_permission(permission: str) -> Callable:
    def guard(user: UserRecord = Depends(get_current_user)) -> UserRecord:
        allowed = ROLE_PERMISSIONS[user.role]
        if "*" not in allowed and permission not in allowed:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN, detail="Insufficient permission"
            )
        return user

    return guard
