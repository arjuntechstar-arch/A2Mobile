from datetime import datetime, timezone
from copy import deepcopy
import pytest
from bson import BSON
from app.services.lifecycle import qualifying_installments, refresh_enrollment
from app.services.schedules import installment_schedule


def fixture():
    enrollment = {
        "_id": "e1",
        "user_id": "u1",
        "status": "ACTIVE",
        "terms": {
            "monthly_amount_paise": 50000,
            "installment_count": 2,
            "benefit_paise": 50000,
            "policy": {"redemption_valid_days": 365},
        },
    }
    installments = [
        {
            "enrollment_id": "e1",
            "number": i,
            "status": "PAID",
            "amount_paise": 50000,
            "payment_id": f"pay_{i}",
            "reconciled": True,
            "due_date": datetime(2020, i, 1, tzinfo=timezone.utc),
        }
        for i in (1, 2)
    ]
    return enrollment, installments


def test_all_reconciled_installments_complete_enrollment(mongo):
    enrollment, installments = fixture()
    mongo.database.enrollments.insert_one(enrollment)
    mongo.database.installments.insert_many(installments)
    assert mongo.transaction(
        lambda session: refresh_enrollment(mongo.database, "e1", session)
    )
    assert (
        mongo.database.enrollments.find_one({"_id": "e1"})["eligible_value_paise"]
        == 150000
    )
    assert not mongo.transaction(
        lambda session: refresh_enrollment(mongo.database, "e1", session)
    )
    assert mongo.database.notifications.count_documents({}) == 1


@pytest.mark.parametrize(
    "failure", ["missing", "duplicate", "wrong_amount", "unreconciled", "unpaid"]
)
def test_incomplete_or_incorrect_installments_never_qualify(failure):
    enrollment, installments = fixture()
    if failure == "missing":
        installments.pop()
    if failure == "duplicate":
        installments[1]["number"] = 1
    if failure == "wrong_amount":
        installments[0]["amount_paise"] = 1
    if failure == "unreconciled":
        installments[0]["reconciled"] = False
    if failure == "unpaid":
        installments[0]["status"] = "DUE"
    assert not qualifying_installments(enrollment, installments)


def test_schedule_month_end_and_bson_encoding():
    policy = {
        "due_rule": "ANNIVERSARY",
        "grace_days": 7,
        "due_day": 1,
        "timezone": "UTC",
    }
    schedule = installment_schedule(
        datetime(2024, 1, 31, tzinfo=timezone.utc), 3, 50000, policy
    )
    assert [i["due_date"].day for i in schedule] == [31, 29, 31]
    for item in schedule:
        BSON.encode(item)


def test_fixed_day_starts_at_next_upcoming_due_date():
    policy = {"due_rule": "FIXED_DAY", "grace_days": 7, "due_day": 5, "timezone": "UTC"}
    schedule = installment_schedule(
        datetime(2026, 12, 20, tzinfo=timezone.utc), 2, 50000, policy
    )
    assert schedule[0]["due_date"] == datetime(2027, 1, 5, tzinfo=timezone.utc)


def test_india_calendar_handles_utc_previous_day():
    policy = {"due_rule": "ANNIVERSARY", "grace_days": 7, "due_day": 1}
    schedule = installment_schedule(
        datetime(2026, 1, 31, 20, tzinfo=timezone.utc), 2, 50000, policy
    )
    assert schedule[0]["due_date"] == datetime(2026, 1, 31, 18, 30, tzinfo=timezone.utc)
    assert schedule[1]["due_date"] == datetime(2026, 2, 28, 18, 30, tzinfo=timezone.utc)


def test_advance_contributions_do_not_accelerate_maturity(mongo):
    from datetime import timedelta
    from app.timeutils import utcnow

    enrollment, installments = fixture()
    installments[-1]["due_date"] = utcnow() + timedelta(days=30)
    mongo.database.enrollments.insert_one(enrollment)
    mongo.database.installments.insert_many(installments)
    assert not mongo.transaction(
        lambda session: refresh_enrollment(mongo.database, "e1", session)
    )
    assert mongo.database.enrollments.find_one({"_id": "e1"})["status"] == "ACTIVE"
