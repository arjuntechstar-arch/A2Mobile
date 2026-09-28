from datetime import datetime, timedelta, timezone
from uuid import uuid4

import bcrypt
import jwt

from app.config import Settings
from app.models import Role, UserRecord


def hash_password(password: str) -> str:
    return bcrypt.hashpw(password.encode(), bcrypt.gensalt()).decode()


def verify_password(password: str, hashed: str) -> bool:
    return bcrypt.checkpw(password.encode(), hashed.encode())


def create_token(user: UserRecord, token_type: str, expires: timedelta, settings: Settings) -> str:
    now = datetime.now(timezone.utc)
    return jwt.encode({"sub": user.id, "role": user.role.value, "type": token_type,
                       "iat": now, "exp": now + expires, "jti": str(uuid4())},
                      settings.jwt_secret, algorithm=settings.jwt_algorithm)


def decode_token(token: str, expected_type: str, settings: Settings) -> dict:
    payload = jwt.decode(token, settings.jwt_secret, algorithms=[settings.jwt_algorithm])
    if payload.get("type") != expected_type or not payload.get("sub"):
        raise jwt.InvalidTokenError("Invalid token type")
    return payload
