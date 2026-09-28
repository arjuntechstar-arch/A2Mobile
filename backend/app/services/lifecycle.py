from datetime import timedelta
from app.timeutils import utcnow, as_utc


def qualifying_installments(enrollment, installments):
    terms = enrollment["terms"]
    if len(installments) != terms["installment_count"]:
        return False
    if {i["number"] for i in installments} != set(
        range(1, terms["installment_count"] + 1)
    ):
        return False
    return all(
        i["status"] == "PAID"
        and i.get("reconciled") is True
        and i.get("amount_paise") == terms["monthly_amount_paise"]
        and i.get("payment_id")
        for i in installments
    )


def refresh_enrollment(database, enrollment_id, session=None):
    options = {"session": session} if session else {}
    enrollment = database.enrollments.find_one({"_id": enrollment_id}, **options)
    if not enrollment or enrollment["status"] != "ACTIVE":
        return False
    installments = list(
        database.installments.find({"enrollment_id": enrollment_id}, **options)
    )
    if not qualifying_installments(enrollment, installments):
        return False
    # Paying in advance never accelerates the monthly scheme's maturity.
    if any(
        not i.get("due_date") or as_utc(i["due_date"]) > utcnow() for i in installments
    ):
        return False
    terms = enrollment["terms"]
    now = utcnow()
    result = database.enrollments.update_one(
        {"_id": enrollment_id, "status": "ACTIVE"},
        {
            "$set": {
                "status": "COMPLETED",
                "completed_at": now,
                "eligible_value_paise": sum(i["amount_paise"] for i in installments)
                + terms["benefit_paise"],
                "redeem_by": now
                + timedelta(days=terms["policy"]["redemption_valid_days"]),
            }
        },
        **options
    )
    if result.modified_count:
        database.notifications.insert_one(
            {
                "user_id": enrollment["user_id"],
                "title": "Scheme completed",
                "body": "All installments are reconciled. Your redemption benefit is available.",
                "created_at": now,
                "read": False,
                "route": "/enrollments/" + enrollment_id,
            },
            **options
        )
    return bool(result.modified_count)
