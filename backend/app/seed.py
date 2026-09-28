from app.config import get_settings
from app.database import MongoDatabase
from app.models import SchemeInput, SchemePolicy
from app.timeutils import utcnow
from uuid import uuid4

TERMS = (
    "Proposed terms for store review: join on any day. Pay 11 monthly installments on the joining-day anniversary; "
    "short months use their final day, in India Standard Time. A seven-day grace period applies. Late payments are accepted. "
    "Each payment opens on its due date; the benefit cannot be earned before the final scheduled due date. "
    "The shop benefit is earned only after all 11 payments are captured and reconciled. "
    "Cancellation requires store approval; the initial policy has no contribution deduction and excludes the shop benefit. "
    "Redeem within 365 days of completion using a fresh phone code at the store, with an invoice covering the eligible value."
)


def seed(database):
    for rupees in [500, 1000, 1500, 2000]:
        payload = SchemeInput(
            code=f"MONTHLY_{rupees}",
            name=f"Monthly {rupees}",
            monthly_amount_paise=rupees * 100,
            installment_count=11,
            benefit_paise=rupees * 100,
            policy=SchemePolicy(terms_text=TERMS),
        )

        def write(session):
            db = database.database
            if db.schemes.find_one({"code": payload.code}, session=session):
                return
            item = {
                "_id": str(uuid4()),
                **payload.model_dump(),
                "version": 1,
                "active": False,
                "created_at": utcnow(),
            }
            db.schemes.insert_one(item, session=session)
            db.scheme_versions.insert_one(
                {
                    "scheme_id": item["_id"],
                    "version": 1,
                    "terms": payload.model_dump(),
                    "created_at": utcnow(),
                },
                session=session,
            )

        database.transaction(write)


if __name__ == "__main__":
    database = MongoDatabase(get_settings())
    try:
        database.ensure_indexes()
        seed(database)
        print(
            "Initial schemes are available as drafts. Review and publish them in the admin portal."
        )
    finally:
        database.close()
