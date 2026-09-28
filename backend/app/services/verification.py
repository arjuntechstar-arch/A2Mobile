import hashlib
import secrets
from datetime import timedelta

from fastapi import HTTPException
from pymongo import ReturnDocument
from pymongo.errors import DuplicateKeyError

from app.timeutils import utcnow


class VerificationService:
    """Atomic, expiring, rate-limited challenges; plain values go only to delivery."""

    def __init__(self, db, pepper):
        self.db, self.pepper = db, pepper

    def _digest(self, subject, code):
        return hashlib.sha256(f"{subject}:{code}:{self.pepper}".encode()).hexdigest()

    def _issue(self, collection, identity, digest, lifetime):
        now = utcnow()
        try:
            collection.find_one_and_update(
                {
                    **identity,
                    "$or": [
                        {"resend_after": {"$lte": now}},
                        {"resend_after": {"$exists": False}},
                    ],
                },
                {
                    "$set": {
                        **identity,
                        "digest": digest,
                        "expires": now + lifetime,
                        "resend_after": now + timedelta(seconds=60),
                        "attempts": 0,
                    }
                },
                upsert=True,
                return_document=ReturnDocument.AFTER,
            )
        except DuplicateKeyError:
            raise HTTPException(
                429, "Wait 60 seconds before requesting another verification message"
            )

    def issue_phone(self, phone):
        code = f"{secrets.randbelow(1000000):06d}"
        self._issue(
            self.db.otp_challenges,
            {"phone": phone},
            self._digest(phone, code),
            timedelta(minutes=10),
        )
        return code

    def verify_phone(self, phone, code):
        challenge = self.db.otp_challenges.find_one_and_update(
            {"phone": phone, "expires": {"$gt": utcnow()}, "attempts": {"$lt": 5}},
            {"$inc": {"attempts": 1}},
            return_document=ReturnDocument.AFTER,
        )
        if not challenge or not secrets.compare_digest(
            challenge["digest"], self._digest(phone, code)
        ):
            raise HTTPException(400, "Invalid or expired verification code")
        consumed = self.db.otp_challenges.find_one_and_delete(
            {
                "phone": phone,
                "digest": challenge["digest"],
                "expires": {"$gt": utcnow()},
            }
        )
        if not consumed:
            raise HTTPException(400, "Invalid or expired verification code")

    def issue_email(self, user_id):
        token = secrets.token_urlsafe(32)
        self._issue(
            self.db.email_verifications,
            {"user_id": user_id},
            self._digest("email", token),
            timedelta(hours=24),
        )
        return token

    def verify_email(self, token):
        item = self.db.email_verifications.find_one_and_delete(
            {"digest": self._digest("email", token), "expires": {"$gt": utcnow()}}
        )
        if not item:
            raise HTTPException(400, "Invalid or expired email link")
        return item["user_id"]
