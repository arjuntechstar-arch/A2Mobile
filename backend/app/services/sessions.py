import hashlib
from datetime import timedelta

import jwt
from fastapi import HTTPException
from pymongo import ReturnDocument

from app.security import create_token, decode_token
from app.models import TokenPair
from app.timeutils import utcnow


def throttle(database, scope, subject, limit, seconds):
    now = utcnow()
    bucket = int(now.timestamp()) // seconds
    key = hashlib.sha256(f"{scope}:{subject}:{bucket}".encode()).hexdigest()
    row = database.rate_limits.find_one_and_update(
        {"_id": key},
        {
            "$inc": {"count": 1},
            "$setOnInsert": {"expires": now + timedelta(seconds=seconds * 2)},
        },
        upsert=True,
        return_document=ReturnDocument.AFTER,
    )
    if row["count"] > limit:
        raise HTTPException(
            429,
            "Too many attempts. Please try again later.",
            headers={"Retry-After": str(seconds)},
        )


def issue_tokens(database, user, settings):
    refresh = create_token(
        user, "refresh", timedelta(days=settings.refresh_token_days), settings
    )
    claims = decode_token(refresh, "refresh", settings)
    access = create_token(
        user,
        "access",
        timedelta(minutes=settings.access_token_minutes),
        settings,
        claims["jti"],
    )
    database.sessions.insert_one(
        {
            "_id": claims["jti"],
            "user_id": user.id,
            "expires": utcnow() + timedelta(days=settings.refresh_token_days),
            "revoked": False,
        }
    )
    return TokenPair(access_token=access, refresh_token=refresh)


def consume_refresh(database, token, settings):
    try:
        claims = decode_token(token, "refresh", settings)
    except jwt.PyJWTError:
        raise HTTPException(401, "Invalid or expired refresh token")
    session = database.sessions.find_one_and_update(
        {
            "_id": claims["jti"],
            "user_id": claims["sub"],
            "revoked": False,
            "expires": {"$gt": utcnow()},
        },
        {"$set": {"revoked": True}},
    )
    if not session:
        raise HTTPException(401, "Session was already used or revoked")
    return claims["sub"]
