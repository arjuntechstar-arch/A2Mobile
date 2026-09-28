from pymongo import ASCENDING, MongoClient
from pymongo.collection import Collection

from app.config import Settings


class MongoDatabase:
    def __init__(self, settings: Settings):
        self.client = MongoClient(settings.mongodb_uri, serverSelectionTimeoutMS=5000)
        self.database = self.client[settings.mongodb_database]

    @property
    def users(self) -> Collection:
        return self.database.users

    def ensure_indexes(self) -> None:
        self.users.create_index([("email", ASCENDING)], unique=True, name="users_email_unique")
        self.database.roles.create_index([("name", ASCENDING)], unique=True, name="roles_name_unique")
        self.database.otp_challenges.create_index([("phone", ASCENDING)], unique=True, name="otp_phone_unique")
        self.database.email_verifications.create_index([("token", ASCENDING)], unique=True, name="email_token_unique")
        self.database.schemes.create_index([("code", ASCENDING)], unique=True, name="scheme_code_unique")
        self.database.scheme_versions.create_index([("scheme_id", ASCENDING), ("version", ASCENDING)], unique=True, name="scheme_version_unique")

    def close(self) -> None:
        self.client.close()
