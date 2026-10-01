from types import SimpleNamespace

import pytest
from fastapi import HTTPException

from app.routes.operations import resources


def test_resource_page_resolves_customer_names_in_one_batch():
    class Cursor(list):
        def sort(self, *_):
            return self

        def skip(self, *_):
            return self

        def limit(self, *_):
            return self

    class Enrollments:
        def find(self, query, projection):
            return Cursor(
                [
                    {"_id": "e1", "user_id": "c1", "terms": {"name": "Mobile plan"}},
                    {"_id": "e2", "user_id": "c1"},
                    {"_id": "e3", "user_id": "c2"},
                    {"_id": "e4", "user_id": "deleted"},
                ]
            )

        def count_documents(self, query):
            return 4

    class Users:
        calls = 0

        def find(self, query, projection):
            self.calls += 1
            assert set(query["_id"]["$in"]) == {"c1", "c2", "deleted"}
            assert projection == {"name": 1, "email": 1}
            return [
                {"_id": "c1", "name": "Asha Rao", "email": "asha@example.com"},
                {"_id": "c2", "email": "customer@example.com"},
            ]

    users = Users()
    database = {"enrollments": Enrollments()}

    class Database(dict):
        pass

    database = Database(database)
    database.users = users
    request = SimpleNamespace(
        app=SimpleNamespace(
            state=SimpleNamespace(database=SimpleNamespace(database=database))
        )
    )
    result = resources(
        "enrollments", request, SimpleNamespace(role="super_admin"), skip=0, limit=25
    )
    assert users.calls == 1
    assert result["total"] == 4
    assert [item["customer_name"] for item in result["items"]] == [
        "Asha Rao",
        "Asha Rao",
        "customer@example.com",
        "Unavailable customer",
    ]
    assert result["items"][0]["scheme_name"] == "Mobile plan"
    assert result["items"][0]["user_id"] == "c1"


def test_resource_display_enrichment_preserves_permission_checks():
    with pytest.raises(HTTPException) as error:
        resources(
            "enrollments", None, SimpleNamespace(role="customer"), skip=0, limit=25
        )
    assert error.value.status_code == 403
