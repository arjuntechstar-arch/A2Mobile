from uuid import uuid4
from app.backup import backup, restore
from app.timeutils import utcnow
import pytest


def test_backup_restore_roundtrip(mongo, tmp_path):
    mongo.database.users.insert_one(
        {"_id": "backup-user", "email": "backup@example.com", "created_at": utcnow()}
    )
    destination = tmp_path / "archive"
    backup(mongo, destination)
    target = "restore_test_" + uuid4().hex
    try:
        counts = restore(mongo.client, destination, target)
        assert counts["users"] == 1
        assert (
            mongo.client[target].users.find_one({"_id": "backup-user"})["email"]
            == "backup@example.com"
        )
        assert mongo.client[target].users.index_information()["users_email_unique"][
            "unique"
        ]
        with pytest.raises(ValueError):
            restore(mongo.client, destination, target)
        with pytest.raises(ValueError):
            restore(mongo.client, destination, "mobile_shop_scheme")
    finally:
        assert target.startswith("restore_test_")
        mongo.client.drop_database(target)
