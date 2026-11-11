"""Pruebas de perfil, stock mínimo, exportación, estadísticas, auditoría y caché de Open Food Facts."""
import os, sys, datetime
os.environ.setdefault("SECRET_KEY", "test")
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "backend"))
import pytest
from werkzeug.security import generate_password_hash
import app as backend
from app import app, make_token


@pytest.fixture(autouse=True)
def limpio():
    backend._off_cache.clear()
    backend._intentos.clear()
    yield
    backend._off_cache.clear()


def h(rol="admin"):
    return {"Authorization": "Bearer " + make_token({"id": 1, "rol": rol})}


def fake_query(rol="admin", extra=None, registro=None):
    """Simula la base: usuario activo para auth() y respuestas por consulta."""
    def q(sql, params=(), one=False, write=False):
        if registro is not None:
            registro.append((sql, params))
        if sql.startswith("SELECT id,rol,activo"):
            return {"id": 1, "rol": rol, "activo": 1}
        if extra:
            r = extra(sql, params)
            if r is not None:
                return r
        return 1 if write else ([] if not one else None)
    return q


# ---------- contraseña propia ----------
def test_cambiar_contrasena_correcta(monkeypatch):
    log = []
    monkeypatch.setattr(backend, "query", fake_query(registro=log, extra=lambda s, p:
        {"password_hash": generate_password_hash("Vieja123!")} if s.startswith("SELECT password_hash") else None))
    r = app.test_client().put("/me/password", json={"actual": "Vieja123!", "nueva": "Nueva456#"}, headers=h())
    assert r.status_code == 200 and any(s.startswith("UPDATE usuarios SET password_hash") for s, _ in log)


@pytest.mark.parametrize("datos,codigo", [
    ({"actual": "mala", "nueva": "Nueva456#"}, 400),
    ({"actual": "Vieja123!", "nueva": "corta"}, 400),
    ({"actual": "Vieja123!"}, 400),
])
def test_cambiar_contrasena_rechazos(monkeypatch, datos, codigo):
    monkeypatch.setattr(backend, "query", fake_query(extra=lambda s, p:
        {"password_hash": generate_password_hash("Vieja123!")} if s.startswith("SELECT password_hash") else None))
    assert app.test_client().put("/me/password", json=datos, headers=h()).status_code == codigo


# ---------- stock mínimo ----------
@pytest.mark.parametrize("v,esperado", [(None, (5, None)), ("", (5, None)), ("8", (8, None)), (0, (0, None))])
def test_stock_minimo_valido(v, esperado):
    assert backend._stock_minimo(v, 5) == esperado


@pytest.mark.parametrize("v", [-1, "abc", 2.5e99 if False else "1x"])
def test_stock_minimo_invalido(v):
    valor, err = backend._stock_minimo(v, 5)
    assert valor is None and err


def test_crear_producto_con_stock_minimo_negativo(monkeypatch):
    monkeypatch.setattr(backend, "query", fake_query())
    r = app.test_client().post("/products", json={"nombre": "x", "stock_minimo": -3}, headers=h())
    assert r.status_code == 400


def test_crear_producto_registra_auditoria(monkeypatch):
    log = []
    monkeypatch.setattr(backend, "query", fake_query(registro=log))
    r = app.test_client().post("/products", json={"nombre": "Agua", "stock_minimo": 2}, headers=h())
    assert r.status_code == 201
    assert any(s.startswith("INSERT INTO auditoria") for s, _ in log)


def test_error_de_auditoria_no_rompe_la_operacion(monkeypatch):
    base = fake_query()
    def q(sql, params=(), one=False, write=False):
        if sql.startswith("INSERT INTO auditoria"):
            raise RuntimeError("tabla inexistente")
        return base(sql, params, one, write)
    monkeypatch.setattr(backend, "query", q)
    assert app.test_client().post("/products", json={"nombre": "Agua"}, headers=h()).status_code == 201


# ---------- exportación CSV ----------
def test_exportar_csv_protege_formulas(monkeypatch):
    filas = [{"codigo_barras": "750", "nombre": "=CMD()", "marca": "Marca", "categoria": None, "stock": 3, "stock_minimo": 5}]
    monkeypatch.setattr(backend, "query", fake_query(extra=lambda s, p: filas if "FROM productos" in s else None))
    r = app.test_client().get("/products/export.csv", headers=h())
    assert r.status_code == 200 and r.mimetype == "text/csv"
    texto = r.get_data(as_text=True)
    assert texto.splitlines()[0] == "codigo_barras,nombre,marca,categoria,stock,stock_minimo"
    assert "'=CMD()" in texto


def test_empleado_no_exporta(monkeypatch):
    monkeypatch.setattr(backend, "query", fake_query("empleado"))
    assert app.test_client().get("/products/export.csv", headers=h("empleado")).status_code == 403


# ---------- estadísticas semanales ----------
def test_estadisticas_semanales_rellena_siete_dias(monkeypatch):
    hoy = datetime.date.today()
    filas = [{"dia": hoy, "tipo": "entrada", "total": 10}, {"dia": hoy, "tipo": "salida", "total": 4}]
    monkeypatch.setattr(backend, "query", fake_query(extra=lambda s, p: filas if "GROUP BY" in s else None))
    r = app.test_client().get("/stats/weekly", headers=h("empleado"))
    datos = r.get_json()
    assert r.status_code == 200 and len(datos) == 7
    assert datos[-1] == {"fecha": hoy.isoformat(), "entradas": 10, "salidas": 4}
    assert datos[0]["entradas"] == 0


# ---------- auditoría ----------
def test_empleado_no_ve_auditoria(monkeypatch):
    monkeypatch.setattr(backend, "query", fake_query("empleado"))
    assert app.test_client().get("/audit", headers=h("empleado")).status_code == 403


def test_admin_ve_auditoria(monkeypatch):
    filas = [{"id": 1, "accion": "crear", "entidad": "producto", "detalle": "id=1", "fecha": datetime.datetime(2026, 1, 1), "usuario": "A"}]
    monkeypatch.setattr(backend, "query", fake_query(extra=lambda s, p: filas if "FROM auditoria" in s else None))
    r = app.test_client().get("/audit", headers=h())
    assert r.status_code == 200 and r.get_json()[0]["accion"] == "crear"


# ---------- caché de Open Food Facts ----------
class Resp:
    status_code = 200
    def json(self):
        return {"status": 1, "product": {"product_name": "Coca cola", "brands": "Coca-cola", "categories": "Colas", "image_front_url": ""}}


def test_consulta_repetida_usa_cache(monkeypatch):
    monkeypatch.setattr(backend, "query", fake_query())
    llamadas = []
    monkeypatch.setattr(backend.requests, "get", lambda *a, **k: llamadas.append(1) or Resp())
    c = app.test_client()
    assert c.get("/barcode/7501055304745", headers=h()).status_code == 200
    assert c.get("/barcode/7501055304745", headers=h()).status_code == 200
    assert len(llamadas) == 1


def test_cache_expira(monkeypatch):
    monkeypatch.setattr(backend, "query", fake_query())
    llamadas = []
    monkeypatch.setattr(backend.requests, "get", lambda *a, **k: llamadas.append(1) or Resp())
    c = app.test_client()
    c.get("/barcode/7501055304745", headers=h())
    backend._off_cache["7501055304745"] = (0, backend._off_cache["7501055304745"][1])  # entrada antigua
    c.get("/barcode/7501055304745", headers=h())
    assert len(llamadas) == 2
