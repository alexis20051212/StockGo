"""Pruebas de la compresión gzip de la API (mejora de rendimiento)."""
import os, sys, gzip, json
os.environ.setdefault("SECRET_KEY", "test")
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "backend"))
import app as backend
from app import app, make_token


def _auth():
    return {"Authorization": "Bearer " + make_token({"id": 1, "rol": "admin"})}


def _query(n):
    productos = [{"id": i, "nombre": f"Producto {i}", "stock": i} for i in range(n)]

    def q(sql, params=(), one=False, write=False):
        if sql.startswith("SELECT id,rol,activo"):
            return {"id": 1, "rol": "admin", "activo": 1}
        return productos
    return q


def test_respuesta_grande_se_comprime(monkeypatch):
    monkeypatch.setattr(backend, "query", _query(200))
    h = {**_auth(), "Accept-Encoding": "gzip"}
    r = app.test_client().get("/products", headers=h)
    assert r.status_code == 200
    assert r.headers.get("Content-Encoding") == "gzip"
    assert len(json.loads(gzip.decompress(r.data))) == 200


def test_respuesta_pequena_no_se_comprime(monkeypatch):
    monkeypatch.setattr(backend, "query", _query(1))
    h = {**_auth(), "Accept-Encoding": "gzip"}
    r = app.test_client().get("/products", headers=h)
    assert r.status_code == 200
    assert r.headers.get("Content-Encoding") is None


def test_sin_gzip_en_la_peticion_no_comprime(monkeypatch):
    monkeypatch.setattr(backend, "query", _query(200))
    r = app.test_client().get("/products", headers=_auth())
    assert r.headers.get("Content-Encoding") is None
