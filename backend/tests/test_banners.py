import base64
import importlib.util
import threading
from pathlib import Path
from types import SimpleNamespace
from urllib.error import HTTPError
from urllib.request import urlopen

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient
from fastapi.staticfiles import StaticFiles
import httpx

from app.routes import operations


@pytest.fixture
def banner_client(tmp_path):
    class SettingsStore:
        item = None

        def replace_one(self, query, item, upsert=False):
            assert query == {"_id": "banner"} and upsert
            self.item = item.copy()

        def find_one(self, query):
            return self.item.copy() if self.item and self.item["active"] else None

    app = FastAPI()
    app.state.settings = SimpleNamespace(upload_directory=str(tmp_path))
    app.state.database = SimpleNamespace(database=SimpleNamespace(settings=SettingsStore()))
    app.include_router(operations.router, prefix="/api")
    app.mount("/uploads", StaticFiles(directory=str(tmp_path)))
    route = next(route for route in operations.router.routes if route.path == "/admin/banner")
    app.dependency_overrides[route.dependant.dependencies[0].call] = lambda: SimpleNamespace(id="staff")
    with TestClient(app) as client:
        yield client


def test_image_banner_upload_publish_edit_and_unpublish(banner_client):
    binary = b"\x89PNG\r\n\x1a\n" + b"image-content" * 100
    image = "data:image/png;base64," + base64.b64encode(binary).decode()
    assert len(image) > 300  # Previously rejected before the upload handler ran.
    payload = {"mode": "images", "slides": [{"image": image, "title": "Offer"}], "active": True}
    response = banner_client.put("/api/admin/banner", json=payload)
    assert response.status_code == 200, response.text
    saved = response.json()
    assert saved["slides"][0]["image"].startswith("/uploads/banners/")
    assert banner_client.get(saved["slides"][0]["image"]).content == binary
    assert banner_client.get("/api/banner").json()["slides"] == saved["slides"]
    payload["slides"] = saved["slides"]
    payload["slides"][0]["title"] = "Updated offer"
    assert banner_client.put("/api/admin/banner", json=payload).status_code == 200
    assert banner_client.get("/api/banner").json()["slides"][0]["title"] == "Updated offer"
    payload["active"] = False
    assert banner_client.put("/api/admin/banner", json=payload).status_code == 200
    assert banner_client.get("/api/banner").json()["slides"] == []


def test_text_banner_and_invalid_image_inputs(banner_client):
    response = banner_client.put("/api/admin/banner", json={"title": " New promotion ", "body": "Details"})
    assert response.status_code == 200
    assert banner_client.get("/api/banner").json()["title"] == "New promotion"
    assert banner_client.put("/api/admin/banner", json={"title": " "}).status_code == 422
    assert banner_client.put("/api/admin/banner", json={"mode": "images", "slides": []}).status_code == 422
    assert banner_client.put("/api/admin/banner", json={"mode": "images", "slides": [{"image": "https://example.com/image.png"}]}).status_code == 400


def test_customer_web_proxies_banners_and_images_only(monkeypatch):
    path = Path(__file__).resolve().parents[2] / "scripts" / "customer-web-server.py"
    spec = importlib.util.spec_from_file_location("customer_web", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    calls = []

    def upstream(method, url, **kwargs):
        calls.append((method, url))
        if "/uploads/" in url:
            return httpx.Response(200, content=b"image-bytes", headers={"Content-Type": "image/png"})
        return httpx.Response(200, json={"title": "Published promotion"})

    monkeypatch.setattr(module.httpx, "request", upstream)
    server = module.ThreadingHTTPServer(("127.0.0.1", 0), module.Handler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    origin = f"http://127.0.0.1:{server.server_port}"
    try:
        with urlopen(origin + "/api/banner", timeout=5) as response:
            assert b"Published promotion" in response.read()
        with urlopen(origin + "/uploads/banners/1234-abcd.png", timeout=5) as response:
            assert response.headers["Content-Type"] == "image/png"
            assert response.read() == b"image-bytes"
        for route in ("/api/admin/banner", "/uploads/private.txt"):
            with pytest.raises(HTTPError) as error:
                urlopen(origin + route, timeout=5)
            assert error.value.code == 404
        assert len(calls) == 2
    finally:
        server.shutdown()
        server.server_close()
        thread.join(timeout=5)
