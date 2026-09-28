from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


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


@lru_cache
def get_settings() -> Settings:
    return Settings()
