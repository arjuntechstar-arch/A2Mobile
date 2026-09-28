from typing import Protocol
from uuid import uuid4

from pymongo.errors import DuplicateKeyError

from app.models import Role, UserRecord
from app.security import hash_password


class UserRepository(Protocol):
    def by_id(self, user_id: str) -> UserRecord | None: ...
    def by_email(self, email: str) -> UserRecord | None: ...
    def insert(self, user: UserRecord) -> UserRecord: ...
    def save(self, user: UserRecord) -> UserRecord: ...


class MongoUserRepository:
    def __init__(self, database):
        self.database = database

    def by_id(self, user_id: str) -> UserRecord | None:
        doc = self.database.users.find_one({"_id": user_id})
        return self._model(doc)

    def by_email(self, email: str) -> UserRecord | None:
        doc = self.database.users.find_one({"email": email.lower()})
        return self._model(doc)

    def insert(self, user: UserRecord) -> UserRecord:
        try:
            document = user.model_dump(by_alias=True)
            document["_id"] = document.pop("id")
            document["email"] = str(user.email).lower()
            self.database.users.insert_one(document)
            return user
        except DuplicateKeyError as exc:
            raise ValueError("An account with that email already exists") from exc

    def save(self, user: UserRecord) -> UserRecord:
        document = user.model_dump()
        document["_id"] = document.pop("id")
        document["email"] = str(user.email).lower()
        self.database.users.replace_one({"_id": user.id}, document)
        return user

    @staticmethod
    def _model(doc: dict | None) -> UserRecord | None:
        if not doc:
            return None
        doc["id"] = str(doc.pop("_id"))
        return UserRecord.model_validate(doc)


class UserService:
    def __init__(self, users: UserRepository):
        self.users = users

    def create(self, email: str, password: str, role: Role, **profile) -> UserRecord:
        user = UserRecord(
            id=str(uuid4()),
            email=email.lower(),
            password_hash=hash_password(password),
            role=role,
            **profile
        )
        return self.users.insert(user)
