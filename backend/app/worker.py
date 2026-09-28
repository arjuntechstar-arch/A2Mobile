"""Run as python -m app.worker. All scheduled tasks are repeatable after restart."""

import logging
import time
from datetime import timedelta
from app.config import get_settings
from app.database import MongoDatabase
from app.timeutils import utcnow
from app.services.lifecycle import refresh_enrollment
from app.services.schedules import policy_timezone

log = logging.getLogger(__name__)


def run_once(database):
    db = database.database
    now = utcnow()
    db.installments.update_many(
        {"status": "DUE", "overdue_at": {"$lt": now}}, {"$set": {"status": "OVERDUE"}}
    )
    for enrollment in db.enrollments.find({"status": "ACTIVE"}):
        database.transaction(
            lambda session: refresh_enrollment(db, enrollment["_id"], session)
        )
        days = enrollment["terms"]["policy"]["reminder_days"]
        zone = policy_timezone(enrollment["terms"]["policy"])
        today = now.astimezone(zone).date()
        for installment in db.installments.find(
            {"enrollment_id": enrollment["_id"], "status": {"$in": ["DUE", "OVERDUE"]}}
        ):
            due_day = installment["due_date"].astimezone(zone).date()
            remaining = (due_day - today).days
            if remaining not in days and installment["status"] != "OVERDUE":
                continue
            # Overdue notifications are weekly, not on every worker tick.
            if (
                installment["status"] == "OVERDUE"
                and (today - installment["overdue_at"].astimezone(zone).date()).days % 7
            ):
                continue
            key = f"reminder:{enrollment['_id']}:{installment['number']}:{today}"
            db.notifications.update_one(
                {"_id": key},
                {
                    "$setOnInsert": {
                        "user_id": enrollment["user_id"],
                        "title": (
                            "Installment overdue"
                            if installment["status"] == "OVERDUE"
                            else "Upcoming installment"
                        ),
                        "body": f"Installment {installment['number']} is due on {due_day}.",
                        "created_at": now,
                        "read": False,
                        "route": "/enrollments/" + enrollment["_id"],
                    }
                },
                upsert=True,
            )
    deliver_push(db)
    reconcile_gateway(database)


def reconcile_gateway(database):
    from app.services.providers import Providers
    from app.routes.payments import reconcile_payment

    settings = get_settings()
    if not settings.razorpay_key_id or not settings.razorpay_key_secret:
        return
    db = database.database
    providers = Providers(settings)
    for order in db.payment_orders.find(
        {"status": "CREATED", "gateway_order_id": {"$exists": True}}
    ).limit(100):
        try:
            results = providers.razorpay(
                "GET", "orders/" + order["gateway_order_id"] + "/payments"
            )
            for payment in results.get("items", []):
                reconcile_payment(database, payment)
        except Exception:
            log.warning(
                "Order reconciliation deferred for local order %s", order["_id"]
            )
    for refund in db.refunds.find({"status": "PROCESSING"}).limit(100):
        results = []
        try:
            for part in refund.get("gateway_refunds", []):
                response = providers.razorpay(
                    "GET", "refunds/" + part["gateway_refund_id"]
                )
                results.append({**part, "status": response["status"]})
            if results:
                state = (
                    "PROCESSED"
                    if all(p["status"] == "processed" for p in results)
                    else "PROCESSING"
                )
                db.refunds.update_one(
                    {"_id": refund["_id"]},
                    {
                        "$set": {
                            "status": state,
                            "gateway_refunds": results,
                            "updated_at": utcnow(),
                        }
                    },
                )
        except Exception:
            log.warning(
                "Refund reconciliation deferred for local refund %s", refund["_id"]
            )


def deliver_push(db):
    settings = get_settings()
    if not settings.firebase_credentials:
        return  # In-app notifications persist independently of configured push delivery.
    import firebase_admin
    from firebase_admin import credentials, messaging

    if not firebase_admin._apps:
        firebase_admin.initialize_app(
            credentials.Certificate(settings.firebase_credentials)
        )
    for item in db.notifications.find({"push_sent": {"$ne": True}}).limit(100):
        tokens = [
            d["token"]
            for d in db.notification_devices.find({"user_id": item["user_id"]})
        ]
        if not tokens:
            continue
        failures = False
        for token in tokens:
            try:
                # Lock screens receive no financial or identity details.
                messaging.send(
                    messaging.Message(
                        token=token,
                        notification=messaging.Notification(
                            title="Mobile Shop Scheme",
                            body="You have a new notification.",
                        ),
                        data={
                            "route": item.get("route", "/notifications"),
                            "notification_id": str(item["_id"]),
                        },
                    )
                )
            except messaging.UnregisteredError:
                db.notification_devices.delete_one({"token": token})
            except Exception:
                failures = True
                log.warning("Push delivery failed; it will be retried")
        if not failures:
            db.notifications.update_one(
                {"_id": item["_id"]},
                {"$set": {"push_sent": True, "push_sent_at": utcnow()}},
            )


def main():
    logging.basicConfig(level=logging.INFO)
    database = MongoDatabase(get_settings())
    database.ensure_indexes()
    try:
        while True:
            try:
                run_once(database)
            except Exception:
                log.exception("Scheduled task failed")
            time.sleep(60)
    finally:
        database.close()


if __name__ == "__main__":
    main()
