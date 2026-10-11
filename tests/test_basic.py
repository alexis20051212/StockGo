import os, sys
os.environ.setdefault("SECRET_KEY", "test")
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "backend"))
from app import app, make_token, need


def test_need_detecta_campos_vacios():
    assert need({"a": "x", "b": " "}, "a", "b") == ["b"]


def test_endpoint_protegido_sin_token():
    assert app.test_client().get("/products").status_code == 401


def test_empleado_no_puede_crear_producto():
    t = make_token({"id": 1, "rol": "empleado"})
    r = app.test_client().post("/products", json={"nombre": "x"}, headers={"Authorization": f"Bearer {t}"})
    assert r.status_code == 403
