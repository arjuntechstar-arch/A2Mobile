import calendar
from datetime import datetime, timedelta, timezone
from app.timeutils import as_utc


def policy_timezone(policy):
    return (
        timezone(timedelta(hours=5, minutes=30))
        if policy.get("timezone", "Asia/Kolkata") == "Asia/Kolkata"
        else timezone.utc
    )


def installment_schedule(start, count, amount, policy):
    zone = policy_timezone(policy)
    start = as_utc(start).astimezone(zone)
    result = []
    for offset in range(count):
        month_index = start.year * 12 + start.month - 1 + offset
        year, month = divmod(month_index, 12)
        month += 1
        desired_day = (
            start.day if policy["due_rule"] == "ANNIVERSARY" else policy["due_day"]
        )
        day = min(desired_day, calendar.monthrange(year, month)[1])
        due = datetime(year, month, day, tzinfo=zone)
        if (
            policy["due_rule"] == "FIXED_DAY"
            and due.date() < start.date()
            and offset == 0
        ):
            # Anchor a fixed-day plan at the first upcoming due date.
            next_month = start.month % 12 + 1
            anchor = datetime(
                start.year + (start.month == 12),
                next_month,
                policy["due_day"],
                tzinfo=zone,
            )
            return installment_schedule(anchor, count, amount, policy)
        result.append(
            {
                "number": offset + 1,
                "amount_paise": amount,
                "due_date": due.astimezone(timezone.utc),
                "overdue_at": (
                    due + timedelta(days=policy["grace_days"] + 1)
                ).astimezone(timezone.utc),
                "status": "DUE",
            }
        )
    return result
