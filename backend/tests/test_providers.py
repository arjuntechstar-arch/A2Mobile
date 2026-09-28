import httpx
import pytest
from fastapi import HTTPException
from app.config import Settings
from app.services.providers import Providers


def test_missing_provider_configuration_cannot_simulate_success():
    provider = Providers(
        Settings(
            _env_file=None,
            twilio_account_sid="",
            twilio_auth_token="",
            twilio_messaging_service_sid="",
            razorpay_key_id="",
            razorpay_key_secret="",
            cashfree_client_id="",
            cashfree_client_secret="",
        )
    )
    for action in [
        lambda: provider.send_sms("+919999999999", "test"),
        lambda: provider.razorpay("POST", "orders", {}),
        lambda: provider.verify_pan("ABCDE1234F", "Test User"),
    ]:
        with pytest.raises(HTTPException) as exc:
            action()
        assert exc.value.status_code == 503


def test_cashfree_pan_validity_and_name_match_are_required():
    settings = Settings(
        _env_file=None,
        cashfree_client_id="test-id",
        cashfree_client_secret="test-secret",
    )

    def response(request):
        assert request.url.host == "sandbox.cashfree.com"
        assert request.url.path == "/verification/pan"
        return httpx.Response(
            200,
            json={
                "reference_id": 123,
                "valid": True,
                "pan_status": "VALID",
                "name_match_result": "PARTIAL_MATCH",
            },
        )

    provider = Providers(settings, transport=httpx.MockTransport(response))
    result = provider.verify_pan("ABCDE1234F", "Test User")
    assert result["status"] == "REQUIRES_REVIEW"
    assert "pan" not in result


def test_provider_errors_never_echo_sensitive_response():
    settings = Settings(
        _env_file=None,
        cashfree_client_id="test-id",
        cashfree_client_secret="test-secret",
    )
    provider = Providers(
        settings,
        transport=httpx.MockTransport(
            lambda request: httpx.Response(
                400, json={"pan": "ABCDE1234F", "secret": "sensitive"}
            )
        ),
    )
    with pytest.raises(HTTPException) as exc:
        provider.verify_pan("ABCDE1234F", "Test User")
    assert "ABCDE1234F" not in exc.value.detail
    assert "sensitive" not in exc.value.detail
