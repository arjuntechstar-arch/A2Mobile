from datetime import timedelta
from concurrent.futures import ThreadPoolExecutor
import pytest
from fastapi import HTTPException
from app.services.verification import VerificationService
from app.timeutils import utcnow


def test_phone_code_is_one_time(mongo):
    service = VerificationService(mongo.database, "test-secret")
    code = service.issue_phone("+919999999999")
    service.verify_phone("+919999999999", code)
    with pytest.raises(HTTPException):
        service.verify_phone("+919999999999", code)


def test_email_token_is_one_time(mongo):
    service = VerificationService(mongo.database, "test-secret")
    token = service.issue_email("u1")
    assert service.verify_email(token) == "u1"
    with pytest.raises(HTTPException):
        service.verify_email(token)


def test_incorrect_code_preserves_valid_challenge(mongo):
    service = VerificationService(mongo.database, "test-secret")
    code = service.issue_phone("+919999999999")
    with pytest.raises(HTTPException):
        service.verify_phone("+919999999999", "wrong")
    service.verify_phone("+919999999999", code)


def test_attempt_limit_and_resend_limit(mongo):
    service = VerificationService(mongo.database, "test-secret")
    code = service.issue_phone("+919999999999")
    with pytest.raises(HTTPException) as exc:
        service.issue_phone("+919999999999")
    assert exc.value.status_code == 429
    for _ in range(5):
        with pytest.raises(HTTPException):
            service.verify_phone("+919999999999", "wrong")
    with pytest.raises(HTTPException):
        service.verify_phone("+919999999999", code)


def test_expired_challenges_fail(mongo):
    service = VerificationService(mongo.database, "test-secret")
    code = service.issue_phone("+919999999999")
    mongo.database.otp_challenges.update_many(
        {}, {"$set": {"expires": utcnow() - timedelta(minutes=1)}}
    )
    with pytest.raises(HTTPException):
        service.verify_phone("+919999999999", code)


def test_concurrent_code_consumption_has_one_winner(mongo):
    service = VerificationService(mongo.database, "test-secret")
    code = service.issue_phone("+919999999999")

    def verify(_):
        try:
            service.verify_phone("+919999999999", code)
            return True
        except HTTPException:
            return False

    with ThreadPoolExecutor(max_workers=4) as executor:
        assert sum(executor.map(verify, range(4))) == 1
