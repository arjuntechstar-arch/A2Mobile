from pymongo import ASCENDING, MongoClient
from pymongo.collection import Collection
from fastapi import HTTPException

from app.config import Settings


class MongoDatabase:
    def __init__(self, settings: Settings):
        self.client = MongoClient(
            settings.mongodb_uri, serverSelectionTimeoutMS=5000, tz_aware=True
        )
        self.database = self.client[settings.mongodb_database]

    @property
    def users(self) -> Collection:
        return self.database.users

    def ensure_indexes(self) -> None:
        self.users.create_index(
            [("email", ASCENDING)], unique=True, name="users_email_unique"
        )
        self.users.create_index(
            "phone", unique=True, partialFilterExpression={"phone": {"$type": "string"}}
        )
        self.database.roles.create_index(
            [("name", ASCENDING)], unique=True, name="roles_name_unique"
        )
        self.database.otp_challenges.create_index(
            [("phone", ASCENDING)], unique=True, name="otp_phone_unique"
        )
        # Old tokens are deliberately invalidated by the verification migration.
        if (
            "email_token_unique"
            in self.database.email_verifications.index_information()
        ):
            self.database.email_verifications.drop_index("email_token_unique")
        self.database.email_verifications.create_index("user_id", unique=True)
        self.database.email_verifications.create_index(
            "digest", unique=True, sparse=True
        )
        self.database.otp_challenges.create_index("expires", expireAfterSeconds=0)
        self.database.email_verifications.create_index("expires", expireAfterSeconds=0)
        self.database.schemes.create_index(
            [("code", ASCENDING)], unique=True, name="scheme_code_unique"
        )
        self.database.scheme_versions.create_index(
            [("scheme_id", ASCENDING), ("version", ASCENDING)],
            unique=True,
            name="scheme_version_unique",
        )
        self.database.installments.create_index(
            [("enrollment_id", 1), ("number", 1)], unique=True
        )
        self.database.installments.create_index([("status", 1), ("due_date", 1)])
        self.database.enrollments.create_index([("user_id", 1), ("status", 1)])
        self.database.enrollments.create_index(
            [("user_id", 1), ("idempotency_key", 1)],
            unique=True,
            partialFilterExpression={"idempotency_key": {"$type": "string"}},
        )
        self.database.payments.create_index("gateway_payment_id", unique=True)
        self.database.payment_orders.create_index(
            [("enrollment_id", 1), ("installment_number", 1)], unique=True
        )
        self.database.kyc_verifications.create_index("user_id", unique=True)
        self.database.redemptions.create_index("enrollment_id", unique=True)
        self.database.receipts.create_index("payment_id", unique=True)
        self.database.notifications.create_index([("user_id", 1), ("created_at", -1)])
        self.database.notification_devices.create_index("token", unique=True)
        self.database.sessions.create_index("expires", expireAfterSeconds=0)
        self.database.rate_limits.create_index("expires", expireAfterSeconds=0)
        self.database.password_resets.create_index("expires", expireAfterSeconds=0)
        self.database.refunds.create_index("enrollment_id", unique=True)
        self.database.audit_logs.create_index("created_at")
        self.database.payment_orders.create_index(
            "gateway_order_id", unique=True, sparse=True
        )

    def transaction(self, callback):
        """Financial writes require replica-set transactions; never silently degrade."""
        hello = self.client.admin.command("hello")
        if not hello.get("setName") and hello.get("msg") != "isdbgrid":
            raise HTTPException(
                503, "MongoDB replica set is required for this operation"
            )
        with self.client.start_session() as session:
            return session.with_transaction(callback)

    def close(self) -> None:
        self.client.close()
