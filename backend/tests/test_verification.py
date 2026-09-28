from datetime import datetime, timezone
import pytest
from fastapi import HTTPException
from app.services.verification import VerificationService

class Collection:
    def __init__(self): self.items={}
    def replace_one(self, key, value, upsert=False): self.items[next(iter(key.values()))]=value
    def find_one_and_delete(self, key):
        for stored_key, value in self.items.items():
            if all(value.get(name) == expected for name, expected in key.items()):
                del self.items[stored_key]
                return value
        return None
class Db:
    def __init__(self): self.otp_challenges=Collection(); self.email_verifications=Collection()

def test_phone_code_is_one_time():
    db=Db(); service=VerificationService(db,"secret"); code=service.issue_phone("+919999999999")
    service.verify_phone("+919999999999",code)
    with pytest.raises(HTTPException): service.verify_phone("+919999999999",code)
def test_email_token_is_one_time():
    db=Db(); service=VerificationService(db,"secret"); token=service.issue_email("u1")
    assert service.verify_email(token)=="u1"
    with pytest.raises(HTTPException): service.verify_email(token)
