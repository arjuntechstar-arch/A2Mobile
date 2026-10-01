from datetime import datetime, timezone

from bson import BSON
import pytest

from app.config import Settings
from app.demo_seed import ACCOUNTS, MARKER, build_documents, demo_id, seed_demo
from app.models import UserRecord, SchemeView


def test_demo_data_has_valid_models_and_consistent_payment_histories():
    docs = build_documents(datetime(2026, 10, 1, 11, tzinfo=timezone.utc), "test-hash", lambda p: "encrypted")
    for collection, items in docs.items():
        assert len({item["_id"] for item in items}) == len(items), collection
        for item in items:
            BSON.encode(item)
    for item in docs["users"]:
        UserRecord.model_validate({**item, "id": item["_id"]})
    for item in docs["schemes"]:
        SchemeView.model_validate({**{key: value for key, value in item.items()
            if key not in {"_id", "demo_seed", "created_at"}}, "id": item["_id"]})
    payments = {item["_id"]: item for item in docs["payments"]}
    receipts = {item["payment_id"]: item for item in docs["receipts"]}
    users = {item["_id"] for item in docs["users"]}
    for enrollment in docs["enrollments"]:
        assert enrollment["user_id"] in users
        rows = [item for item in docs["installments"] if item["enrollment_id"] == enrollment["_id"]]
        assert sorted(row["number"] for row in rows) == list(range(1, 12))
        paid = [row for row in rows if row["status"] == "PAID"]
        for row in paid:
            payment = payments[row["payment_id"]]
            assert row["reconciled"] is True
            assert payment["enrollment_id"] == enrollment["_id"]
            assert payment["amount_paise"] == row["amount_paise"]
            assert receipts[payment["_id"]]["amount_paise"] == payment["amount_paise"]
        if "eligible_value_paise" in enrollment:
            assert len(paid) == 11
            assert enrollment["eligible_value_paise"] == sum(row["amount_paise"] for row in paid) + enrollment["terms"]["benefit_paise"]
        for refund in docs["refunds"]:
            if refund["enrollment_id"] == enrollment["_id"]:
                assert refund["contributions_paise"] == sum(row["amount_paise"] for row in paid)
    assert any(item["status"] == "OVERDUE" for item in docs["installments"])
    assert len(docs["users"]) == len(ACCOUNTS)
    assert all(item["push_sent"] for item in docs["notifications"])
    assert not any(item["status"] in {"CREATED", "PROCESSING"} for item in docs["payment_orders"] + docs["refunds"])


def test_seed_is_idempotent_and_preserves_existing_content_and_demo_edits(mongo):
    settings = Settings(_env_file=None, app_environment="test", data_encryption_keys="",
                        local_skip_kyc=False, local_email_only=False)
    mongo.database.settings.insert_one({"_id": "faq", "title": "Existing FAQ"})
    mongo.database.settings.insert_one({"_id": "banner", "slides": ["Existing upload"]})
    first = seed_demo(mongo, settings)
    assert first["users"] == 12
    mongo.users.update_one({"_id": demo_id("user:customer")}, {"$set": {"name": "Edited demo customer"}})
    second = seed_demo(mongo, settings)
    assert second == {}
    assert mongo.users.find_one({"_id": demo_id("user:customer")})["name"] == "Edited demo customer"
    assert mongo.database.settings.find_one({"_id": "faq"})["title"] == "Existing FAQ"
    assert mongo.database.settings.find_one({"_id": "banner"})["slides"] == ["Existing upload"]
    assert mongo.users.count_documents({"demo_seed": MARKER}) == 12


def test_seed_refuses_production_before_database_access():
    from types import SimpleNamespace
    with pytest.raises(ValueError, match="development or test"):
        seed_demo(None, SimpleNamespace(app_environment="production"))
