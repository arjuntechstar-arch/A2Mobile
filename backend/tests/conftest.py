import os
from uuid import uuid4

import pytest

from app.config import Settings
from app.database import MongoDatabase


@pytest.fixture
def mongo():
    uri = os.environ.get("TEST_MONGODB_URI")
    if not uri:
        pytest.skip("Set TEST_MONGODB_URI to run database integration tests")
    name = "a2_test_" + uuid4().hex
    database = MongoDatabase(Settings(mongodb_uri=uri, mongodb_database=name))
    database.ensure_indexes()
    try:
        yield database
    finally:
        # Only this fixture-created random test database can be removed.
        assert database.database.name == name and name.startswith("a2_test_")
        database.client.drop_database(name)
        database.close()
