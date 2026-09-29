import firebase_admin
from firebase_admin import auth, credentials, exceptions
from fastapi import HTTPException


def verify_phone_token(token, settings):
    if not settings.firebase_credentials:
        raise HTTPException(503, "Firebase phone verification is not configured")
    try:
        try:
            app = firebase_admin.get_app('phone-verification')
        except ValueError:
            app = firebase_admin.initialize_app(
                credentials.Certificate(settings.firebase_credentials),
                name='phone-verification',
            )
        return auth.verify_id_token(token, app=app, check_revoked=True)
    except (ValueError, exceptions.FirebaseError):
        raise HTTPException(401, "Firebase verification expired or invalid. Request a new code.")
