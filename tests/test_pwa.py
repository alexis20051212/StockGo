import os, sys
os.environ.setdefault("SECRET_KEY", "test")
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "backend"))
from app import app


def test_cors_preflight_permite_la_pwa():
    r = app.test_client().options("/products", headers={
        "Origin": "https://stockgo.web.app",
        "Access-Control-Request-Method": "GET",
        "Access-Control-Request-Headers": "authorization,content-type"})
    assert r.status_code in (200, 204)
    assert r.headers.get("Access-Control-Allow-Origin")
    assert "authorization" in r.headers.get("Access-Control-Allow-Headers", "").lower()


def test_cors_en_respuestas_normales():
    r = app.test_client().get("/products", headers={"Origin": "https://stockgo.web.app"})
    assert r.status_code == 401
    assert r.headers.get("Access-Control-Allow-Origin")
