import os, sys
os.environ.setdefault("SECRET_KEY", "test")
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "backend"))
from app import app, make_token, need, validar_password


def test_need_detecta_campos_vacios():
    assert need({"a": "x", "b": " "}, "a", "b") == ["b"]


def test_endpoint_protegido_sin_token():
    assert app.test_client().get("/products").status_code == 401


def test_empleado_no_puede_crear_producto():
    t = make_token({"id": 1, "rol": "empleado"})
    r = app.test_client().post("/products", json={"nombre": "x"}, headers={"Authorization": f"Bearer {t}"})
    assert r.status_code == 403


def test_empleado_no_puede_administrar_usuarios():
    t = make_token({"id": 2, "rol": "empleado"})
    h = {"Authorization": f"Bearer {t}"}
    assert app.test_client().get("/users", headers=h).status_code == 403
    assert app.test_client().post("/users", json={}, headers=h).status_code == 403


def test_empleado_no_puede_eliminar_productos():
    t = make_token({"id": 2, "rol": "empleado"})
    r = app.test_client().delete("/products/1", headers={"Authorization": f"Bearer {t}"})
    assert r.status_code == 403


def test_contrasena_valida():
    assert validar_password("Stock#2026") is None
    assert validar_password("abcdef1!") is None  # justo 8 caracteres


def test_contrasena_invalida_dice_que_falta():
    assert "8 caracteres" in validar_password("a1!")
    assert "un número" in validar_password("abcdefgh!")
    assert "un carácter especial" in validar_password("abcdefg1")
    msg = validar_password("abc")
    assert "8 caracteres" in msg and "un número" in msg and "especial" in msg
    assert validar_password("x" * 200) is not None
