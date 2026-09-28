import hashlib
import secrets
from datetime import datetime, timedelta, timezone
from fastapi import HTTPException

class VerificationService:
    """Persists verification challenges; actual SMS/email transport is configured at deployment."""
    def __init__(self, db, pepper): self.db, self.pepper = db, pepper
    def issue_phone(self, phone):
        code=f"{secrets.randbelow(1000000):06d}"
        self.db.otp_challenges.replace_one({"phone":phone},{"phone":phone,"digest":self._digest(phone,code),"expires":datetime.now(timezone.utc)+timedelta(minutes=10)},upsert=True)
        return code
    def verify_phone(self, phone, code):
        item=self.db.otp_challenges.find_one_and_delete({"phone":phone})
        if not item or item["expires"]<datetime.now(timezone.utc) or not secrets.compare_digest(item["digest"],self._digest(phone,code)): raise HTTPException(400,"Invalid or expired verification code")
    def issue_email(self,user_id):
        token=secrets.token_urlsafe(32); self.db.email_verifications.replace_one({"user_id":user_id},{"user_id":user_id,"token":token,"expires":datetime.now(timezone.utc)+timedelta(hours=24)},upsert=True); return token
    def verify_email(self,token):
        item=self.db.email_verifications.find_one_and_delete({"token":token})
        if not item or item["expires"]<datetime.now(timezone.utc): raise HTTPException(400,"Invalid or expired email link")
        return item["user_id"]
    def _digest(self,phone,code): return hashlib.sha256(f"{phone}:{code}:{self.pepper}".encode()).hexdigest()
