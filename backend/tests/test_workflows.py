import hashlib
import hmac
from concurrent.futures import ThreadPoolExecutor
from fastapi import FastAPI
from fastapi.testclient import TestClient
import pytest
from app.config import Settings
from app.routes import (
    auth,
    admin,
    schemes,
    enrollments,
    payments,
    redemptions,
    operations,
    lifecycle,
)
from app.services.users import MongoUserRepository, UserService
from app.services.providers import Providers
from app.models import Role
from app.timeutils import utcnow


@pytest.fixture
def system(mongo, monkeypatch):
    settings = Settings(
        jwt_secret="test-secret-for-integration-tests-only",
        razorpay_key_id="rzp_test_local",
        razorpay_key_secret="gateway-test-secret",
        razorpay_webhook_secret="webhook-test-secret",
    )
    for module in [auth, payments, enrollments, redemptions]:
        monkeypatch.setattr(module, "get_settings", lambda: settings)
    from app import dependencies

    app = FastAPI()
    app.state.database = mongo
    app.state.settings = settings
    app.dependency_overrides[dependencies.get_settings] = lambda: settings
    for module in [
        auth,
        admin,
        schemes,
        enrollments,
        payments,
        redemptions,
        operations,
        lifecycle,
    ]:
        app.include_router(module.router, prefix="/api")
    repo = MongoUserRepository(mongo)
    root = UserService(repo).create(
        "owner@example.com", "test-password-123", Role.SUPER_ADMIN
    )
    customer = UserService(repo).create(
        "customer@example.com", "test-password-123", Role.CUSTOMER
    )
    customer.phone = "+919999999999"
    customer.phone_verified = True
    customer.email_verified = True
    repo.save(customer)
    mongo.database.kyc_verifications.insert_one(
        {
            "user_id": customer.id,
            "status": "VERIFIED",
            "provider_reference": "test-kyc-123",
        }
    )
    client = TestClient(app)

    def header(email):
        r = client.post(
            "/api/auth/login", json={"email": email, "password": "test-password-123"}
        )
        assert r.status_code == 200, r.text
        return {"Authorization": "Bearer " + r.json()["access_token"]}

    return client, mongo, header(root.email), header(customer.email), customer, settings


def enroll_customer(system):
    client, mongo, root, customer, user, settings = system
    payload = {
        "code": "TEST500",
        "name": "Test scheme",
        "monthly_amount_paise": 50000,
        "installment_count": 2,
        "benefit_paise": 50000,
        "policy": {
            "terms_text": "Two installments. Benefit after all captured payments are reconciled."
        },
    }
    created = client.post("/api/schemes", headers=root, json=payload)
    assert created.status_code == 201, created.text
    scheme = created.json()
    assert client.get("/api/schemes").json() == []
    assert (
        client.patch(
            f"/api/schemes/{scheme['id']}/publication",
            headers=root,
            json={"active": True, "reviewed_version": 1},
        ).status_code
        == 200
    )
    result = client.post(
        "/api/enrollments",
        headers={**customer, "Idempotency-Key": "enrollment-1"},
        json={"scheme_id": scheme["id"], "scheme_version": 1, "accepted_terms": True},
    )
    assert result.status_code == 201, result.text
    duplicate = client.post(
        "/api/enrollments",
        headers={**customer, "Idempotency-Key": "enrollment-1"},
        json={"scheme_id": scheme["id"], "scheme_version": 1, "accepted_terms": True},
    )
    assert duplicate.json()["id"] == result.json()["id"]
    assert mongo.database.installments.count_documents({}) == 2
    return result.json(), scheme, payload


def test_local_enrollment_without_kyc(system):
    client, mongo, root, customer, user, settings = system
    settings.local_skip_kyc = True
    settings.app_environment = "development"
    mongo.database.kyc_verifications.delete_many({})
    enrollment, _, _ = enroll_customer(system)
    assert enrollment["kyc_reference"] is None
    assert enrollment["kyc_skipped_for_local_testing"] is True
    assert mongo.database.kyc_verifications.count_documents({}) == 0


def test_local_email_only_enrollment(system):
    client, mongo, root, customer, user, settings = system
    settings.local_email_only = True
    settings.local_skip_kyc = True
    mongo.database.users.update_one({'_id': user.id}, {'$set': {'phone_verified': False}})
    mongo.database.kyc_verifications.delete_many({})
    enrollment, _, _ = enroll_customer(system)
    assert enrollment['phone_verification_skipped_for_local_testing'] is True
    mongo.database.users.update_one({'_id': user.id}, {'$set': {'email_verified': False}})
    response = client.post('/api/enrollments', headers={**customer, 'Idempotency-Key': 'email-required'},
        json={'scheme_id': 'unused', 'scheme_version': 1, 'accepted_terms': True})
    assert response.status_code == 422


def test_email_only_rejected_in_production():
    with pytest.raises(ValueError, match='only allowed in development'):
        Settings(_env_file=None, app_environment='production', local_email_only=True)


@pytest.mark.parametrize('phone,provider,age,status', [
    ('+919999999999', 'phone', 0, 200),
    ('+918888888888', 'phone', 0, 403),
    ('+919999999999', 'password', 0, 403),
    ('+919999999999', 'phone', 700, 401),
])
def test_firebase_phone_proof(system, monkeypatch, phone, provider, age, status):
    import time
    client, mongo, root, customer, user, settings = system
    settings.phone_verification_provider = 'firebase'
    mongo.database.users.update_one({'_id': user.id}, {'$set': {'phone_verified': False}})
    monkeypatch.setattr(auth, 'verify_phone_token', lambda *args: {
        'phone_number': phone, 'auth_time': time.time() - age,
        'firebase': {'sign_in_provider': provider}})
    response = client.post('/api/auth/verify-phone-firebase', headers=customer,
                           json={'id_token': 'test-token-with-enough-length'})
    assert response.status_code == status
    assert mongo.database.users.find_one({'_id': user.id})['phone_verified'] == (status == 200)


@pytest.mark.parametrize("field", ["phone_verified", "email_verified"])
def test_local_enrollment_still_requires_verified_contacts(system, field):
    client, mongo, root, customer, user, settings = system
    settings.local_skip_kyc = True
    mongo.database.users.update_one({"_id": user.id}, {"$set": {field: False}})
    response = client.post('/api/enrollments', headers={**customer, 'Idempotency-Key': 'local-contact-check'},
        json={'scheme_id': 'unused', 'scheme_version': 1, 'accepted_terms': True})
    assert response.status_code == 422
    assert 'Verified contact' in response.json()['detail']


def test_enrollment_requires_kyc_by_default(system):
    client, mongo, root, customer, user, settings = system
    settings.local_skip_kyc = False
    mongo.database.kyc_verifications.delete_many({})
    response = client.post('/api/enrollments', headers={**customer, 'Idempotency-Key': 'required-kyc-check'},
        json={'scheme_id': 'unused', 'scheme_version': 1, 'accepted_terms': True})
    assert response.status_code == 422
    assert 'Provider-verified KYC' in response.json()['detail']


@pytest.mark.parametrize('environment', ['test', 'production'])
def test_kyc_skip_rejected_outside_development(environment):
    with pytest.raises(ValueError, match='only allowed in development'):
        Settings(_env_file=None, app_environment=environment, local_skip_kyc=True)


def test_enrollment_snapshot_survives_scheme_revision(system):
    enrollment, scheme, payload = enroll_customer(system)
    client, mongo, root, *_ = system
    payload["monthly_amount_paise"] = 100000
    revised = client.put(f"/api/schemes/{scheme['id']}", headers=root, json=payload)
    assert revised.status_code == 200, revised.text
    assert revised.json()["version"] == 2
    saved = mongo.database.enrollments.find_one({"_id": enrollment["id"]})
    assert saved["terms"]["monthly_amount_paise"] == 50000
    assert client.get("/api/schemes").json() == []


def test_payment_webhook_callback_and_completion(system, monkeypatch):
    enrollment, scheme, payload = enroll_customer(system)
    from datetime import timedelta
    from app.services import lifecycle as lifecycle_service

    future = utcnow() + timedelta(days=90)
    monkeypatch.setattr(payments, "utcnow", lambda: future)
    monkeypatch.setattr(lifecycle_service, "utcnow", lambda: future)
    client, mongo, root, customer, user, settings = system
    gateway = {}

    def fake_request(self, method, path, payload=None, headers=None):
        if method == "POST" and path == "orders":
            oid = "order_" + str(len(gateway) + 1)
            gateway[oid] = {"id": oid, **payload}
            return gateway[oid]
        if method == "GET" and path.startswith("payments/"):
            pid = path.split("/")[1]
            return {
                "id": pid,
                "order_id": gateway[pid],
                "amount": 50000,
                "currency": "INR",
                "status": "captured",
            }
        raise AssertionError((method, path))

    monkeypatch.setattr(Providers, "razorpay", fake_request)
    for number in [1, 2]:
        body = {"enrollment_id": enrollment["id"], "installment_number": number}
        order = client.post("/api/payments/orders", headers=customer, json=body)
        assert order.status_code == 200, order.text
        oid = order.json()["order_id"]
        pid = "pay_" + str(number)
        gateway[pid] = oid
        assert (
            client.post("/api/payments/orders", headers=customer, json=body).json()[
                "order_id"
            ]
            == oid
        )
        import json

        event_body = json.dumps(
            {
                "event": "payment.captured",
                "payload": {"payment": {"entity": {"id": pid}}},
            }
        ).encode()
        webhook_headers = {
            "x-razorpay-event-id": "event_" + pid,
            "x-razorpay-signature": hmac.new(
                settings.razorpay_webhook_secret.encode(), event_body, hashlib.sha256
            ).hexdigest(),
        }
        hook = client.post(
            "/api/webhooks/razorpay", content=event_body, headers=webhook_headers
        )
        assert hook.status_code == 200, hook.text
        assert (
            client.post(
                "/api/webhooks/razorpay", content=event_body, headers=webhook_headers
            ).json()["status"]
            == "duplicate"
        )
        signature = hmac.new(
            settings.razorpay_key_secret.encode(),
            f"{oid}|{pid}".encode(),
            hashlib.sha256,
        ).hexdigest()
        # Callback can run repeatedly without a second receipt/credit.
        for _ in range(2):
            result = client.post(
                f"/api/payments/{oid}/verify",
                headers=customer,
                json={"razorpay_payment_id": pid, "razorpay_signature": signature},
            )
            assert result.status_code == 200, result.text
        assert (
            client.get(f"/api/payments/{pid}/receipt", headers=customer).status_code
            == 200
        )
    assert mongo.database.payments.count_documents({}) == 2
    assert mongo.database.receipts.count_documents({}) == 2
    saved = mongo.database.enrollments.find_one({"_id": enrollment["id"]})
    assert saved["status"] == "COMPLETED"
    assert saved["eligible_value_paise"] == 150000
    requested = client.post(
        "/api/redemptions", headers=customer, json={"enrollment_id": enrollment["id"]}
    )
    assert requested.status_code == 201, requested.text
    repeated = client.post(
        "/api/redemptions", headers=customer, json={"enrollment_id": enrollment["id"]}
    )
    assert repeated.json()["id"] == requested.json()["id"]
    assert mongo.database.redemptions.count_documents({}) == 1
    from app.services.verification import VerificationService

    redemption_id = requested.json()["id"]
    code = VerificationService(mongo.database, settings.jwt_secret).issue_phone(
        "redemption:" + redemption_id
    )
    store = client.post(
        "/api/admin/stores",
        headers=root,
        json={
            "name": "Main store",
            "address": "Store test address",
            "phone": "+919777777777",
        },
    ).json()
    completion = {
        "otp": code,
        "store_id": store["id"],
        "invoice_reference": "INV-123",
        "product_reference": "PHONE-123",
        "invoice_value_paise": 150000,
    }
    path = "/api/admin/redemptions/" + redemption_id + "/complete"
    assert client.post(path, headers=customer, json=completion).status_code == 403
    invalid = client.post(
        path, headers=root, json={**completion, "invoice_value_paise": 1}
    )
    assert invalid.status_code == 422
    redeemed = client.post(path, headers=root, json=completion)
    assert redeemed.status_code == 200, redeemed.text
    assert client.post(path, headers=root, json=completion).status_code == 200
    assert (
        mongo.database.enrollments.find_one({"_id": enrollment["id"]})["status"]
        == "REDEEMED"
    )
    assert (
        mongo.database.otp_challenges.count_documents(
            {"phone": "redemption:" + redemption_id}
        )
        == 0
    )


def test_gateway_refund_retry_does_not_repeat_transfer(system, monkeypatch):
    enrollment, _, _ = enroll_customer(system)
    client, mongo, root, customer, user, settings = system
    refunds_sent = []

    def gateway(self, method, path, payload=None, headers=None):
        if path == "orders":
            return {"id": "order_refund", "amount": 50000, "currency": "INR"}
        if path == "payments/pay_refund/refund":
            refunds_sent.append(headers["X-Refund-Idempotency"])
            return {
                "id": "rfnd_123",
                "payment_id": "pay_refund",
                "amount": payload["amount"],
                "status": "pending",
            }
        if path == "refunds/rfnd_123":
            return {
                "id": "rfnd_123",
                "payment_id": "pay_refund",
                "amount": 50000,
                "status": "processed",
            }
        return {
            "id": "pay_refund",
            "order_id": "order_refund",
            "amount": 50000,
            "currency": "INR",
            "status": "captured",
        }

    monkeypatch.setattr(Providers, "razorpay", gateway)
    assert (
        client.post(
            "/api/payments/orders",
            headers=customer,
            json={"enrollment_id": enrollment["id"], "installment_number": 1},
        ).status_code
        == 200
    )
    signature = hmac.new(
        settings.razorpay_key_secret.encode(),
        b"order_refund|pay_refund",
        hashlib.sha256,
    ).hexdigest()
    assert (
        client.post(
            "/api/payments/order_refund/verify",
            headers=customer,
            json={"razorpay_payment_id": "pay_refund", "razorpay_signature": signature},
        ).status_code
        == 200
    )
    refund = client.post(
        "/api/enrollments/" + enrollment["id"] + "/cancel",
        headers=customer,
        json={"reason": "Cancellation requested by customer"},
    ).json()
    base = "/api/admin/refunds/" + refund["id"]
    assert (
        client.post(
            base + "/decision",
            headers=root,
            json={"approved": True, "reason": "Approved under accepted terms"},
        ).status_code
        == 200
    )
    assert client.post(base + "/execute", headers=root).json()["status"] == "PROCESSING"
    assert client.post(base + "/execute", headers=root).json()["status"] == "PROCESSED"
    assert client.post(base + "/execute", headers=root).json()["status"] == "PROCESSED"
    assert len(refunds_sent) == 1


def test_future_installment_is_not_payable(system):
    enrollment, _, _ = enroll_customer(system)
    client, mongo, root, customer, *_ = system
    result = client.post(
        "/api/payments/orders",
        headers=customer,
        json={"enrollment_id": enrollment["id"], "installment_number": 2},
    )
    assert result.status_code == 422
    assert mongo.database.payment_orders.count_documents({}) == 0


def test_staff_access_and_customer_deactivation_revoke_sessions(system):
    client, mongo, root, customer, user, _ = system
    staff = client.post(
        "/api/admin/users",
        headers=root,
        json={
            "email": "staff@example.com",
            "password": "new-staff-password",
            "role": "store_staff",
        },
    ).json()
    listed = client.get("/api/admin/resources/users", headers=root).json()["items"]
    assert len(listed) == 2 and all("password_hash" not in row for row in listed)
    tokens = client.post(
        "/api/auth/login",
        json={"email": "staff@example.com", "password": "new-staff-password"},
    ).json()
    assert (
        client.patch(
            "/api/admin/users/" + staff["id"],
            headers=root,
            json={"role": "accountant", "is_active": True},
        ).status_code
        == 200
    )
    assert (
        client.get(
            "/api/auth/me",
            headers={"Authorization": "Bearer " + tokens["access_token"]},
        ).status_code
        == 401
    )
    assert (
        client.patch(
            "/api/admin/customers/" + user.id, headers=root, json={"is_active": False}
        ).status_code
        == 200
    )
    assert client.get("/api/auth/me", headers=customer).status_code == 401


def test_refresh_rotation_and_logout_revocation(system):
    client, *_ = system
    login = client.post(
        "/api/auth/login",
        json={"email": "customer@example.com", "password": "test-password-123"},
    ).json()
    fresh = client.post(
        "/api/auth/refresh", json={"refresh_token": login["refresh_token"]}
    )
    assert fresh.status_code == 200
    assert (
        client.post(
            "/api/auth/refresh", json={"refresh_token": login["refresh_token"]}
        ).status_code
        == 401
    )
    tokens = fresh.json()
    assert (
        client.post(
            "/api/auth/logout", json={"refresh_token": tokens["refresh_token"]}
        ).status_code
        == 200
    )
    assert (
        client.get(
            "/api/auth/me",
            headers={"Authorization": "Bearer " + tokens["access_token"]},
        ).status_code
        == 401
    )


def test_customer_cannot_access_admin_resources(system):
    client, mongo, root, customer, *_ = system
    for resource in ["customers", "orders", "refunds", "audit", "settings"]:
        assert (
            client.get("/api/admin/resources/" + resource, headers=customer).status_code
            == 403
        )


def test_enrollment_rolls_back_on_schedule_failure(system, monkeypatch):
    client, mongo, root, customer, user, settings = system
    # A failure inside the transaction must leave no enrollment or installment.
    payload = {
        "code": "FAIL500",
        "name": "Rollback scheme",
        "monthly_amount_paise": 50000,
        "installment_count": 2,
        "benefit_paise": 50000,
        "policy": {"terms_text": "A sufficiently long set of terms for testing."},
    }
    scheme = client.post("/api/schemes", headers=root, json=payload).json()
    client.patch(
        "/api/schemes/" + scheme["id"] + "/publication",
        headers=root,
        json={"active": True, "reviewed_version": 1},
    )
    monkeypatch.setattr(
        enrollments,
        "installment_schedule",
        lambda *a: (_ for _ in ()).throw(RuntimeError("injected failure")),
    )
    with pytest.raises(RuntimeError):
        client.post(
            "/api/enrollments",
            headers={**customer, "Idempotency-Key": "rollback-test"},
            json={
                "scheme_id": scheme["id"],
                "scheme_version": 1,
                "accepted_terms": True,
            },
        )
    assert mongo.database.enrollments.count_documents({}) == 0
    assert mongo.database.installments.count_documents({}) == 0


def test_invalid_signature_and_wrong_amount_do_not_credit(system, monkeypatch):
    enrollment, _, _ = enroll_customer(system)
    client, mongo, root, customer, user, settings = system

    def gateway(self, method, path, payload=None, headers=None):
        if path == "orders":
            return {"id": "order_bad", "amount": 50000, "currency": "INR"}
        return {
            "id": "pay_bad",
            "order_id": "order_bad",
            "amount": 1,
            "currency": "INR",
            "status": "captured",
        }

    monkeypatch.setattr(Providers, "razorpay", gateway)
    assert (
        client.post(
            "/api/payments/orders",
            headers=customer,
            json={"enrollment_id": enrollment["id"], "installment_number": 1},
        ).status_code
        == 200
    )
    wrong = client.post(
        "/api/payments/order_bad/verify",
        headers=customer,
        json={"razorpay_payment_id": "pay_bad", "razorpay_signature": "0" * 64},
    )
    assert wrong.status_code == 400
    signature = hmac.new(
        settings.razorpay_key_secret.encode(), b"order_bad|pay_bad", hashlib.sha256
    ).hexdigest()
    wrong = client.post(
        "/api/payments/order_bad/verify",
        headers=customer,
        json={"razorpay_payment_id": "pay_bad", "razorpay_signature": signature},
    )
    assert wrong.status_code == 409
    assert mongo.database.payments.count_documents({}) == 0
    assert mongo.database.installments.count_documents({"status": "PAID"}) == 0


def test_profile_encrypts_sensitive_fields(system, monkeypatch):
    client, mongo, root, customer, user, settings = system
    from cryptography.fernet import Fernet
    from app.services import encryption

    settings.data_encryption_keys = Fernet.generate_key().decode()
    monkeypatch.setattr(encryption, "get_settings", lambda: settings)
    values = {
        "name": "Customer Name",
        "address": "Private address",
        "nominee_name": "Private nominee",
        "nominee_relationship": "Sibling",
    }
    assert client.patch("/api/me", headers=customer, json=values).status_code == 200
    stored = mongo.database.customer_profiles.find_one({"_id": user.id})
    assert "Private address" not in str(stored)
    assert (
        client.get("/api/me", headers=customer).json()["profile"]["address"]
        == "Private address"
    )


def test_support_notifications_and_admin_pagination(system):
    client, mongo, root, customer, user, settings = system
    created = client.post(
        "/api/support/tickets",
        headers=customer,
        json={
            "subject": "Payment question",
            "message": "Please check my payment status.",
        },
    )
    assert created.status_code == 201
    ticket = created.json()
    assert (
        client.patch(
            "/api/admin/support/" + ticket["id"],
            headers=root,
            json={"message": "We are checking.", "status": "IN_PROGRESS"},
        ).status_code
        == 200
    )
    assert (
        client.get("/api/support/tickets", headers=customer).json()[0]["replies"][0][
            "message"
        ]
        == "We are checking."
    )
    notification = client.post(
        "/api/admin/notifications",
        headers=root,
        json={
            "user_id": user.id,
            "title": "Store update",
            "body": "Your request was received.",
        },
    ).json()
    assert (
        client.patch(
            "/api/notifications/" + notification["id"] + "/read", headers=customer
        ).status_code
        == 200
    )
    assert client.get("/api/notifications", headers=customer).json()[0]["read"] is True
    assert (
        client.get("/api/admin/resources/customers?limit=1", headers=root).json()[
            "total"
        ]
        == 1
    )
    assert (
        client.get("/api/admin/resources/customers?limit=101", headers=root).status_code
        == 422
    )


def test_cancellation_no_payments_and_approval(system):
    enrollment, _, _ = enroll_customer(system)
    client, mongo, root, customer, user, settings = system
    result = client.post(
        "/api/enrollments/" + enrollment["id"] + "/cancel",
        headers=customer,
        json={"reason": "I no longer need this plan."},
    )
    assert result.status_code == 200, result.text
    refund = result.json()
    assert refund["amount_paise"] == 0
    assert (
        client.post(
            "/api/admin/refunds/" + refund["id"] + "/decision",
            headers=customer,
            json={"approved": True, "reason": "Customer approval"},
        ).status_code
        == 403
    )
    assert (
        client.post(
            "/api/admin/refunds/" + refund["id"] + "/decision",
            headers=root,
            json={"approved": True, "reason": "Approved per accepted terms"},
        ).status_code
        == 200
    )
    assert (
        mongo.database.enrollments.find_one({"_id": enrollment["id"]})["status"]
        == "CANCELLED"
    )


def test_webhook_bad_signature_is_rejected(system):
    client, *_ = system
    assert (
        client.post(
            "/api/webhooks/razorpay",
            json={"event": "payment.captured"},
            headers={"x-razorpay-signature": "incorrect"},
        ).status_code
        == 401
    )
