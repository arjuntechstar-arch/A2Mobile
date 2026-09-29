from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict
from pydantic import model_validator
from typing import Literal


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file="../.env", extra="ignore")

    mongodb_uri: str = "mongodb://localhost:27017/"
    mongodb_database: str = "mobile_shop_scheme"
    jwt_secret: str = "development-secret-change-me"
    jwt_algorithm: str = "HS256"
    access_token_minutes: int = 15
    refresh_token_days: int = 7
    cors_origins: str = "http://localhost:5173"
    bootstrap_super_admin_email: str | None = None
    bootstrap_super_admin_password: str | None = None
    razorpay_webhook_secret: str = ""
    razorpay_key_secret: str = ""
    razorpay_key_id: str = ""
    twilio_account_sid: str = ""
    twilio_auth_token: str = ""
    twilio_messaging_service_sid: str = ""
    email_smtp_host: str = ""
    email_smtp_port: int = 587
    email_smtp_username: str = ""
    email_smtp_password: str = ""
    email_from: str = ""
    public_app_url: str = "http://localhost:5174"
    cashfree_client_id: str = ""
    cashfree_client_secret: str = ""
    cashfree_environment: str = "sandbox"
    firebase_credentials: str = ""
    firebase_client_options: dict[str, dict[str, str]] = {}
    firebase_web_vapid_key: str = ""
    data_encryption_keys: str = ""
    app_environment: Literal["development", "test", "production"] = "development"
    local_skip_kyc: bool = False

    @model_validator(mode="after")
    def production_configuration(self):
        if self.local_skip_kyc and self.app_environment != "development":
            raise ValueError("LOCAL_SKIP_KYC is only allowed in development")
        if not self.jwt_secret:
            raise ValueError("JWT_SECRET must be configured")
        if self.app_environment == "production":
            if (
                len(self.jwt_secret) < 32
                or self.jwt_secret == "development-secret-change-me"
            ):
                raise ValueError("A strong production JWT_SECRET is required")
            if not self.data_encryption_keys or not self.public_app_url.startswith(
                "https://"
            ):
                raise ValueError(
                    "Production requires encryption keys and an HTTPS application URL"
                )
            if "*" in self.cors_origins or any(
                not origin.startswith("https://")
                for origin in self.cors_origins.split(",")
            ):
                raise ValueError(
                    "Production CORS origins must be explicit HTTPS origins"
                )
            if (
                self.cashfree_environment != "production"
                or not self.razorpay_key_id.startswith("rzp_live_")
            ):
                raise ValueError(
                    "Production requires live Razorpay and production Cashfree configuration"
                )
        return self


@lru_cache
def get_settings() -> Settings:
    return Settings()
