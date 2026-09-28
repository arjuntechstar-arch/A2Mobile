import json
from cryptography.fernet import Fernet, InvalidToken, MultiFernet
from fastapi import HTTPException
from app.config import get_settings


def cipher():
    keys = [
        key.strip()
        for key in get_settings().data_encryption_keys.split(",")
        if key.strip()
    ]
    if not keys:
        raise HTTPException(503, "Secure profile storage has not been configured")
    try:
        return MultiFernet([Fernet(key.encode()) for key in keys])
    except ValueError:
        raise HTTPException(503, "Secure profile storage configuration is invalid")


def encrypt_profile(value):
    return cipher().encrypt(json.dumps(value).encode()).decode()


def decrypt_profile(value):
    try:
        return json.loads(cipher().decrypt(value.encode()))
    except InvalidToken:
        raise HTTPException(503, "Profile could not be decrypted. Contact the store.")
