"""Repeatable local demo data. Run from backend: python -m app.demo_seed."""
import argparse
from collections import Counter, defaultdict
from datetime import timedelta
from uuid import NAMESPACE_URL, uuid5

from app.config import get_settings
from app.database import MongoDatabase
from app.models import Role, SchemeInput, SchemePolicy, UserRecord
from app.security import hash_password
from app.services.encryption import encrypt_profile
from app.services.schedules import installment_schedule, policy_timezone
from app.timeutils import utcnow

MARKER = "a2-demo-v1"
PASSWORD = "DemoShop123!"
ACCOUNTS = [
    ("customer", "Demo Customer", Role.CUSTOMER),
    ("overdue", "Demo Overdue Customer", Role.CUSTOMER),
    ("completed", "Demo Completed Customer", Role.CUSTOMER),
    ("redemption", "Demo Redemption Customer", Role.CUSTOMER),
    ("refund", "Demo Refund Customer", Role.CUSTOMER),
    ("new", "Demo New Customer", Role.CUSTOMER),
    ("unverified", "Demo Unverified Customer", Role.CUSTOMER),
    ("kyc", "Demo KYC Review Customer", Role.CUSTOMER),
    ("owner", "Demo Owner", Role.SUPER_ADMIN),
    ("admin", "Demo Administrator", Role.ADMIN),
    ("accountant", "Demo Accountant", Role.ACCOUNTANT),
    ("staff", "Demo Store Staff", Role.STORE_STAFF),
]


def demo_id(label):
    return str(uuid5(NAMESPACE_URL, f"{MARKER}:{label}"))


def month_start(now, months_ago):
    local = now.astimezone(policy_timezone({}))
    year, month = divmod(local.year * 12 + local.month - 1 - months_ago, 12)
    return local.replace(year=year, month=month + 1, day=1, hour=0, minute=0,
                         second=0, microsecond=0)


def build_documents(now, password_hash, profile_encoder=None):
    """Build linked documents without database writes or external services."""
    docs = defaultdict(list)

    def add(collection, label, **values):
        item = {"_id": demo_id(label), "demo_seed": MARKER, **values}
        docs[collection].append(item)
        return item

    users = {}
    for index, (key, name, role) in enumerate(ACCOUNTS):
        user = UserRecord(id=demo_id(f"user:{key}"), email=f"demo.{key}@example.com",
            password_hash=password_hash, role=role, name=name,
            phone=f"+91900000{index:04d}" if role == Role.CUSTOMER else None,
            phone_verified=key != "unverified", email_verified=key != "unverified",
            created_at=now - timedelta(days=60))
        values = user.model_dump(exclude={"id"})
        # Phone's unique partial index excludes null values.
        if values["phone"] is None:
            values.pop("phone")
        users[key] = add("users", f"user:{key}", **values)
        if role != Role.CUSTOMER:
            continue
        if profile_encoder:
            add("customer_profiles", f"user:{key}", encrypted=profile_encoder({
                "address": "Demo address, Chennai, Tamil Nadu",
                "nominee_name": "Demo Nominee", "nominee_relationship": "Sibling"}))
        if key == "unverified":
            continue
        status = "REQUIRES_REVIEW" if key == "kyc" else "VERIFIED"
        add("kyc_verifications", f"kyc:{key}", user_id=user.id, status=status,
            pan_last4="000A", provider_reference=f"DEMO-KYC-{key}",
            verified_at=now - timedelta(days=50), consented_at=now - timedelta(days=50),
            review_note="Synthetic local testing record; no identity provider was contacted.")
        if status == "VERIFIED":
            add("identity_verifications", f"user:{key}", status="VERIFIED",
                verification_id=f"DEMO-IDENTITY-{key}", created_at=now - timedelta(days=50))

    schemes = []
    for index, (amount, title) in enumerate([
        (500, "Demo Mobile Upgrade"), (1000, "Demo Smart TV Savings"),
        (1500, "Demo Home Appliances"), (2000, "Demo Kitchen Essentials"),
        (2500, "Demo Draft Plan"),
    ]):
        payload = SchemeInput(code=f"DEMO_{amount}", name=title,
            monthly_amount_paise=amount * 100, installment_count=11,
            benefit_paise=amount * 100, policy=SchemePolicy(terms_text=(
                "Demo scheme for local application testing. Pay 11 monthly installments. "
                "The store benefit applies only after all payments are reconciled and the "
                "final due date is reached. Cancellation excludes the shop benefit. "
                "Redeem at the demo store within 365 days of completion.")))
        scheme = add("schemes", f"scheme:{amount}", **payload.model_dump(), version=1,
                     active=index < 4, created_at=now - timedelta(days=60))
        schemes.append(scheme)
        add("scheme_versions", f"version:{amount}:1", scheme_id=scheme["_id"],
            version=1, terms=payload.model_dump(), created_at=scheme["created_at"])

    store = add("stores", "store", name="Demo A2Mobile Chennai",
        address="Demo showroom, Chennai, Tamil Nadu", phone="+919000009999", active=True)
    # Main account exercises all customer screens; other accounts isolate scenarios.
    scenarios = [
        ("mobile", "customer", 0, "ACTIVE", 3, 3),
        ("appliances", "customer", 2, "ACTIVE", 5, 5),
        ("completed", "customer", 1, "COMPLETED", 11, 10),
        ("redemption", "customer", 2, "REDEMPTION_PENDING", 11, 10),
        ("redeemed", "customer", 3, "REDEEMED", 11, 10),
        ("refund-pending", "customer", 0, "CANCELLATION_PENDING", 2, 2),
        ("refund-processed", "customer", 1, "CANCELLED", 3, 3),
        ("overdue", "overdue", 1, "ACTIVE", 2, 3),
        ("completed-only", "completed", 3, "COMPLETED", 11, 10),
        ("redemption-only", "redemption", 0, "REDEMPTION_PENDING", 11, 10),
        ("refund-approved", "refund", 2, "CANCELLED", 4, 4),
    ]
    for key, account, scheme_index, status, paid_count, age in scenarios:
        scheme = schemes[scheme_index]
        uid = users[account]["_id"]
        terms = {k: v for k, v in scheme.items()
                 if k not in {"_id", "demo_seed", "active", "created_at"}}
        start = month_start(now, age)
        enrollment = add("enrollments", f"enrollment:{key}", number=f"DEMO-{key.upper()}",
            user_id=uid, scheme_id=scheme["_id"], terms=terms, status=status,
            accepted_at=start, idempotency_key=f"{MARKER}:{key}",
            kyc_reference=f"DEMO-KYC-{account}")
        eid = enrollment["_id"]
        amount = terms["monthly_amount_paise"]
        total = amount * paid_count
        if status in {"COMPLETED", "REDEMPTION_PENDING", "REDEEMED"}:
            enrollment.update(completed_at=now, eligible_value_paise=total + terms["benefit_paise"],
                              redeem_by=now + timedelta(days=365))
        schedule = installment_schedule(start, 11, amount, terms["policy"])
        for row in schedule:
            number = row["number"]
            if number <= paid_count:
                payment_id = "pay_demo" + demo_id(f"payment:{key}:{number}").replace("-", "")
                gateway_order = "order_demo" + demo_id(f"order:{key}:{number}").replace("-", "")
                paid_at = row["due_date"] + timedelta(hours=9)
                if paid_at > now:
                    paid_at = now
                row.update(status="PAID", payment_id=payment_id, reconciled=True, paid_at=paid_at)
                add("payment_orders", f"order:{key}:{number}", user_id=uid,
                    enrollment_id=eid, installment_number=number, amount_paise=amount,
                    currency="INR", status="PAID", gateway_order_id=gateway_order,
                    payment_id=payment_id, created_at=paid_at, reconciled_at=paid_at)
                payment = add("payments", f"payment:{key}:{number}", user_id=uid,
                    enrollment_id=eid, installment_number=number, amount_paise=amount,
                    currency="INR", status="CAPTURED", gateway_payment_id=payment_id,
                    order_id=gateway_order, gateway_fee_paise=0, gateway_tax_paise=0,
                    created_at=paid_at, reconciled_at=paid_at)
                payment["_id"] = payment_id
                add("receipts", f"receipt:{key}:{number}", user_id=uid, enrollment_id=eid,
                    payment_id=payment_id, installment_number=number, amount_paise=amount,
                    currency="INR", issued_at=paid_at, is_tax_invoice=False,
                    description="Demo scheme contribution receipt")
            elif status in {"CANCELLED", "CANCELLATION_PENDING"}:
                row["status"] = "CANCELLED"
            elif row["overdue_at"] < now:
                row["status"] = "OVERDUE"
            add("installments", f"installment:{key}:{number}", enrollment_id=eid, **row)
        if status in {"REDEMPTION_PENDING", "REDEEMED"}:
            redemption = add("redemptions", f"redemption:{key}", enrollment_id=eid,
                customer_id=uid, eligible_value_paise=enrollment["eligible_value_paise"],
                status="COMPLETED" if status == "REDEEMED" else "PENDING", requested_at=now)
            if status == "REDEEMED":
                redemption.update(store_id=store["_id"], invoice_reference="DEMO-INVOICE-001",
                    product_reference="Demo appliance bundle", invoice_value_paise=total + terms["benefit_paise"],
                    redeemed_value_paise=total + terms["benefit_paise"], completed_at=now,
                    processed_by=users["staff"]["_id"])
        if key.startswith("refund-"):
            state = {"refund-pending": "PENDING_APPROVAL", "refund-processed": "PROCESSED",
                     "refund-approved": "APPROVED"}[key]
            add("refunds", f"refund:{key}", enrollment_id=eid, user_id=uid,
                reason="Demo cancellation scenario", contributions_paise=total,
                deduction_paise=0, amount_paise=total, status=state, created_at=now,
                gateway_refunds=[])
        add("notifications", f"notification:{key}", user_id=uid, title=f"Demo: {key.replace('-', ' ')}",
            body=f"Your {terms['name']} scenario is ready for testing.", created_at=now,
            read=False, push_sent=True, route=f"/enrollments/{eid}")

    # Failed order exercises reconciliation listing without scheduled gateway calls.
    main = docs["enrollments"][0]
    add("payment_orders", "order:failed", enrollment_id=main["_id"],
        user_id=main["user_id"], installment_number=4, amount_paise=50000,
        currency="INR", status="FAILED", created_at=now,
        error="Demo failed checkout; no real gateway request was made.")
    for index, status in enumerate(["OPEN", "IN_PROGRESS", "RESOLVED", "CLOSED"]):
        add("support_tickets", f"ticket:{status}", user_id=users["customer"]["_id"],
            subject=f"Demo {status.lower().replace('_', ' ')} support request",
            message="Please help me understand the installment and redemption process.",
            status=status, created_at=now - timedelta(days=index),
            replies=[] if status == "OPEN" else [{"message": "Demo support reply: we have reviewed your request.",
                "actor_id": users["staff"]["_id"], "created_at": now}])
    add("notifications", "notification:read", user_id=users["customer"]["_id"],
        title="Welcome to the demo store", body="Browse schemes, receipts and support using this account.",
        created_at=now - timedelta(days=2), read=True, push_sent=True, route="/notifications")
    add("audit_logs", "audit", method="SEED", path="demo-data",
        status=200, actor_id=users["owner"]["_id"], created_at=now)
    for key, title, body in [
        ("faq", "Demo FAQ", "Demo plans have 11 installments. View installments from the active scheme card."),
        ("terms", "Demo Terms", "Synthetic local test data. Store benefit is earned after completion and reconciliation."),
        ("privacy", "Demo Privacy", "These demo identities and financial records are fictitious."),
        ("contact", "Demo Contact", "Demo A2Mobile Chennai. Use Support to open a test ticket."),
    ]:
        item = add("settings", f"content:{key}", title=title, body=body, active=True, updated_at=now)
        item["_id"] = key
    return dict(docs)


def seed_demo(database, settings):
    if settings.app_environment not in {"development", "test"}:
        raise ValueError("Demo data is only supported in development or test environments")
    encoder = encrypt_profile if settings.data_encryption_keys else None
    docs = build_documents(utcnow(), hash_password(PASSWORD), encoder)

    def write(session):
        inserted = Counter()
        for collection, items in docs.items():
            for item in items:
                existing = database.database[collection].find_one({"_id": item["_id"]}, session=session)
                if existing:
                    if collection != "settings" and existing.get("demo_seed") != MARKER:
                        raise ValueError(f"Demo ID collision in {collection}; no data was written")
                    continue
                result = database.database[collection].update_one({"_id": item["_id"]},
                    {"$setOnInsert": item}, upsert=True, session=session)
                if result.upserted_id is not None:
                    inserted[collection] += 1
        return dict(inserted)

    return database.transaction(write)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--preview", action="store_true", help="Show planned counts without database writes")
    args = parser.parse_args()
    settings = get_settings()
    if settings.app_environment not in {"development", "test"}:
        parser.error("Demo seeding is restricted to development and test")
    if args.preview:
        docs = build_documents(utcnow(), "preview-only",
            (lambda value: "preview-only") if settings.data_encryption_keys else None)
        print("Planned demo records:", {key: len(items) for key, items in docs.items()})
        return
    database = MongoDatabase(settings)
    try:
        counts = seed_demo(database, settings)
        print("Inserted demo records:", counts or "Already seeded; existing records preserved.")
        print("Customer: demo.customer@example.com | Staff owner: demo.owner@example.com")
        print("All demo accounts use password:", PASSWORD)
    finally:
        database.close()


if __name__ == "__main__":
    main()
