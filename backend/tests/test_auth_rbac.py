from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.config import Settings
from app.dependencies import get_users
from app.models import Role, UserRecord
from app.routes import admin, auth
from app.security import hash_password


class InMemoryUsers:
    def __init__(self, values):
        self.values = {user.id: user for user in values}

    def by_id(self, user_id):
        return self.values.get(user_id)

    def by_email(self, email):
        return next(
            (user for user in self.values.values() if str(user.email) == email.lower()),
            None,
        )

    def insert(self, user):
        if self.by_email(str(user.email)):
            raise ValueError("An account with that email already exists")
        self.values[user.id] = user
        return user


def make_client(mongo):
    app = FastAPI()
    app.state.database = mongo
    app.include_router(auth.router, prefix="/api")
    app.include_router(admin.router, prefix="/api")
    repo = InMemoryUsers(
        [
            UserRecord(
                id="root",
                email="root@example.com",
                password_hash=hash_password("secure-password"),
                role=Role.SUPER_ADMIN,
            ),
            UserRecord(
                id="staff",
                email="staff@example.com",
                password_hash=hash_password("secure-password"),
                role=Role.STORE_STAFF,
            ),
        ]
    )
    app.dependency_overrides[get_users] = lambda: repo
    return TestClient(app), repo


def login(client, email="root@example.com"):
    return client.post(
        "/api/auth/login", json={"email": email, "password": "secure-password"}
    )


def test_login_refresh_and_identity(mongo):
    client, _ = make_client(mongo)
    response = login(client)
    assert response.status_code == 200
    tokens = response.json()
    me = client.get(
        "/api/auth/me", headers={"Authorization": f"Bearer {tokens['access_token']}"}
    )
    assert me.status_code == 200
    assert me.json()["role"] == "super_admin"
    assert (
        client.post(
            "/api/auth/refresh", json={"refresh_token": tokens["refresh_token"]}
        ).status_code
        == 200
    )


def test_invalid_login_is_rejected(mongo):
    client, _ = make_client(mongo)
    response = client.post(
        "/api/auth/login",
        json={"email": "root@example.com", "password": "wrong-password"},
    )
    assert response.status_code == 401


def test_rbac_blocks_staff_from_creating_admins(mongo):
    client, _ = make_client(mongo)
    staff_token = login(client, "staff@example.com").json()["access_token"]
    response = client.post(
        "/api/admin/users",
        headers={"Authorization": f"Bearer {staff_token}"},
        json={
            "email": "admin@example.com",
            "password": "long-enough-password",
            "role": "admin",
        },
    )
    assert response.status_code == 403


def test_super_admin_can_create_admin(mongo):
    client, repo = make_client(mongo)
    token = login(client).json()["access_token"]
    response = client.post(
        "/api/admin/users",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "email": "admin@example.com",
            "password": "long-enough-password",
            "role": "admin",
        },
    )
    assert response.status_code == 201
    assert repo.by_email("admin@example.com").role == Role.ADMIN
