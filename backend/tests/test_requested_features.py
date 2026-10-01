import base64
from types import SimpleNamespace

import pytest
from pydantic import ValidationError

from app.models import RegisterRequest, ResetPasswordRequest
from app.routes.operations import _save_banner_image


def test_customer_password_requires_eight_characters_and_all_character_classes():
    valid = RegisterRequest(
        name="Customer",
        email="customer@example.com",
        phone="+919876543210",
        password="Valid123!",
    )
    assert valid.password == "Valid123!"
    for password in ("Short1!", "lettersonly!", "LettersOnly1", "12345678!"):
        with pytest.raises(ValidationError):
            ResetPasswordRequest(token="token", password=password)


def test_customer_phone_is_india_only():
    with pytest.raises(ValidationError):
        RegisterRequest(
            name="Customer",
            email="customer@example.com",
            phone="+14155552671",
            password="Valid123!",
        )


def test_banner_image_is_saved_under_local_uploads(tmp_path):
    request = SimpleNamespace(
        app=SimpleNamespace(
            state=SimpleNamespace(settings=SimpleNamespace(upload_directory=str(tmp_path)))
        )
    )
    image = base64.b64encode(b"\x89PNG\r\n\x1a\nlocal-banner").decode()
    saved_url = _save_banner_image(f"data:image/png;base64,{image}", request)
    saved_file = tmp_path / saved_url.removeprefix("/uploads/")
    assert saved_url.startswith("/uploads/banners/")
    assert saved_file.exists()


def test_banner_rejects_bytes_that_are_not_an_image(tmp_path):
    request = SimpleNamespace(
        app=SimpleNamespace(
            state=SimpleNamespace(settings=SimpleNamespace(upload_directory=str(tmp_path)))
        )
    )
    encoded = base64.b64encode(b"not-an-image").decode()
    with pytest.raises(Exception, match="Banner image data is invalid"):
        _save_banner_image(f"data:image/png;base64,{encoded}", request)