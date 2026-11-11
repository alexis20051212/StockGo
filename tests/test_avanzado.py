"""Pruebas de login, inventario y errores del servicio externo (sin base de datos real)."""
import os, sys
os.environ.setdefault("SECRET_KEY", "test")
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "backend"))
import pytest, requests
from werkzeug.security import generate_password_hash
import app as backend
from app import app, make_token


@pytest.fixture(autouse=True)
def limpio():
    backend._intentos.clear()
    yield
    backend._intentos.clear()


def cabecera(rol="admin"):
    return {"Authorization": "Bearer " + make_token({"id": 1, "rol": rol})}


def como_usuario(monkeypatch, rol="admin"):
    """La capa de autenticación consulta al usuario; aquí se simula activo."""
    monkeypatch.setattr(backend, "query", lambda *a, **k: {"id": 1, "rol": rol, "activo": 1})


# ---------- límite de intentos de login ----------
def test_login_se_bloquea_tras_intentos_fallidos(monkeypatch):
    monkeypatch.setattr(backend, "query", lambda *a, **k: None)
    c = app.test_client()
    for _ in range(backend.MAX_INTENTOS):
        assert c.post("/auth/login", json={"email": "a@a.com", "password": "x"}).status_code == 401
    r = c.post("/auth/login", json={"email": "a@a.com", "password": "x"})
    assert r.status_code == 429 and int(r.headers["Retry-After"]) > 0


def test_login_correcto_reinicia_intentos(monkeypatch):
    u = {"id": 1, "rol": "admin", "nombre": "A", "password_hash": generate_password_hash("Clave123!")}
    monkeypatch.setattr(backend, "query", lambda *a, **k: u)
    c = app.test_client()
    for _ in range(backend.MAX_INTENTOS - 1):
        c.post("/auth/login", json={"email": "a@a.com", "password": "mala"})
    assert c.post("/auth/login", json={"email": "a@a.com", "password": "Clave123!"}).status_code == 200
    assert backend._intentos == {}


def test_bloqueo_expira(monkeypatch):
    backend._intentos["ip|a@a.com"] = {"n": 0, "hasta": 1000}
    assert backend._segundos_bloqueo("ip|a@a.com", ahora=900) > 0
    assert backend._segundos_bloqueo("ip|a@a.com", ahora=1001) == 0


# ---------- Open Food Facts: errores del servicio externo ----------
class Resp:
    def __init__(self, status=200, data=None, bad_json=False):
        self.status_code, self._d, self._bad = status, data, bad_json

    def json(self):
        if self._bad:
            raise ValueError("no es JSON")
        return self._d


def off(monkeypatch, resp=None, exc=None):
    como_usuario(monkeypatch)
    def fake(*a, **k):
        if exc:
            raise exc
        return resp
    monkeypatch.setattr(backend.requests, "get", fake)


def test_barcode_codigo_invalido(monkeypatch):
    como_usuario(monkeypatch)
    assert app.test_client().get("/barcode/abc", headers=cabecera()).status_code == 400


@pytest.mark.parametrize("resp,exc,esperado", [
    (Resp(429), None, 429),
    (Resp(503), None, 502),
    (Resp(200, bad_json=True), None, 502),
    (Resp(200, {"status": 0}), None, 404),
    (None, requests.Timeout(), 502),
    (None, requests.ConnectionError(), 502),
])
def test_barcode_errores_del_servicio_externo(monkeypatch, resp, exc, esperado):
    off(monkeypatch, resp, exc)
    assert app.test_client().get("/barcode/7501055304745", headers=cabecera()).status_code == esperado


def test_barcode_correcto(monkeypatch):
    off(monkeypatch, Resp(200, {"status": 1, "product": {"product_name": "Coca cola", "brands": "Coca-cola",
        "categories": "Bebidas, Colas", "image_front_url": "http://x/img.jpg"}}))
    r = app.test_client().get("/barcode/7501055304745", headers=cabecera())
    assert r.status_code == 200
    assert r.get_json() == {"codigo_barras": "7501055304745", "nombre": "Coca cola", "marca": "Coca-cola",
                            "categoria": "Bebidas", "imagen_url": "http://x/img.jpg"}


def test_empleado_no_consulta_open_food_facts(monkeypatch):
    como_usuario(monkeypatch, "empleado")
    assert app.test_client().get("/barcode/7501055304745", headers=cabecera("empleado")).status_code == 403


# ---------- Movimientos de inventario ----------
class FakeCur:
    def __init__(self, db): self.db, self.fila = db, None
    def execute(self, sql, params=()):
        self.db.sqls.append(sql)
        if sql.startswith("SELECT stock"):
            self.fila = {"stock": self.db.stock} if self.db.existe else None
        elif sql.startswith("UPDATE productos"):
            self.db.stock += params[0]
    def fetchone(self): return self.fila
    def close(self): pass


class FakeCon:
    def __init__(self, stock=10, existe=True):
        self.stock, self.existe, self.sqls, self.commits, self.rollbacks = stock, existe, [], 0, 0
    def cursor(self, dictionary=True): return FakeCur(self)
    def commit(self): self.commits += 1
    def rollback(self): self.rollbacks += 1
    def close(self): pass


def mover(monkeypatch, db, **datos):
    como_usuario(monkeypatch, "empleado")
    monkeypatch.setattr(backend, "conn", lambda: db)
    return app.test_client().post("/movements", json=datos, headers=cabecera("empleado"))


def test_entrada_aumenta_stock_y_confirma(monkeypatch):
    db = FakeCon(stock=10)
    r = mover(monkeypatch, db, product_id=1, tipo="entrada", cantidad=5)
    assert r.status_code == 201 and r.get_json()["stock"] == 15 and db.commits == 1


def test_salida_mayor_al_stock_se_rechaza(monkeypatch):
    db = FakeCon(stock=3)
    r = mover(monkeypatch, db, product_id=1, tipo="salida", cantidad=5)
    assert r.status_code == 409 and db.stock == 3 and db.commits == 0


def test_dos_salidas_seguidas_no_dejan_stock_negativo(monkeypatch):
    db = FakeCon(stock=10)
    assert mover(monkeypatch, db, product_id=1, tipo="salida", cantidad=6).status_code == 201
    assert mover(monkeypatch, db, product_id=1, tipo="salida", cantidad=6).status_code == 409
    assert db.stock == 4


def test_movimiento_bloquea_la_fila(monkeypatch):
    db = FakeCon()
    mover(monkeypatch, db, product_id=1, tipo="entrada", cantidad=1)
    assert any("FOR UPDATE" in s for s in db.sqls)


@pytest.mark.parametrize("datos", [
    {"product_id": 1, "tipo": "entrada", "cantidad": 0},
    {"product_id": 1, "tipo": "entrada", "cantidad": -2},
    {"product_id": 1, "tipo": "otro", "cantidad": 1},
    {"tipo": "entrada", "cantidad": 1},
    {"product_id": "x", "tipo": "entrada", "cantidad": 1},
])
def test_movimiento_con_datos_invalidos(monkeypatch, datos):
    assert mover(monkeypatch, FakeCon(), **datos).status_code == 400


def test_movimiento_de_producto_inexistente(monkeypatch):
    assert mover(monkeypatch, FakeCon(existe=False), product_id=9, tipo="entrada", cantidad=1).status_code == 404
