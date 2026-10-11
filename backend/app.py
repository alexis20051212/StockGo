import os, functools, datetime
import jwt, requests, mysql.connector
from dotenv import load_dotenv
from flask import Flask, request, jsonify, g
from werkzeug.security import generate_password_hash, check_password_hash

load_dotenv()
app = Flask(__name__)
SECRET = os.environ["SECRET_KEY"]  # variable de entorno, nunca en código


def conn():
    return mysql.connector.connect(
        host=os.getenv("DB_HOST"), port=int(os.getenv("DB_PORT", "3306")),
        user=os.getenv("DB_USER"),
        password=os.getenv("DB_PASSWORD"), database=os.getenv("DB_NAME"))


def query(sql, params=(), one=False, write=False):
    """Siempre consultas parametrizadas (anti SQL Injection)."""
    con = conn(); cur = con.cursor(dictionary=True)
    try:
        cur.execute(sql, params)
        if write:
            con.commit(); return cur.lastrowid
        rows = cur.fetchall()
        return (rows[0] if rows else None) if one else rows
    finally:
        cur.close(); con.close()


def auth(roles=None):
    def deco(f):
        @functools.wraps(f)
        def wrapper(*a, **k):
            token = request.headers.get("Authorization", "").removeprefix("Bearer ")
            try:
                g.user = jwt.decode(token, SECRET, algorithms=["HS256"])
            except Exception:
                return jsonify(error="Token inválido o expirado"), 401
            if roles and g.user["rol"] not in roles:
                return jsonify(error="No tienes permisos"), 403
            return f(*a, **k)
        return wrapper
    return deco


def need(data, *fields):
    return [f for f in fields if not str(data.get(f, "")).strip()]


def make_token(u):
    exp = datetime.datetime.utcnow() + datetime.timedelta(hours=8)
    return jwt.encode({"id": u["id"], "rol": u["rol"], "exp": exp}, SECRET, algorithm="HS256")


# ---------- AUTH ----------
@app.get("/auth/has-users")
def has_users():
    return jsonify(has_users=bool(query("SELECT id FROM usuarios LIMIT 1", one=True)))


@app.post("/auth/register")
def register():
    """Solo permite registrar al PRIMER administrador."""
    if query("SELECT id FROM usuarios LIMIT 1", one=True):
        return jsonify(error="Registro cerrado; un administrador debe crear tu cuenta"), 403
    d = request.get_json(silent=True) or {}
    if need(d, "nombre", "email", "password") or len(d["password"]) < 6:
        return jsonify(error="Datos inválidos (contraseña mínimo 6 caracteres)"), 400
    uid = query("INSERT INTO usuarios(nombre,email,password_hash,rol) VALUES(%s,%s,%s,'admin')",
                (d["nombre"], d["email"], generate_password_hash(d["password"])), write=True)
    return jsonify(id=uid), 201


@app.post("/auth/login")
def login():
    d = request.get_json(silent=True) or {}
    u = query("SELECT * FROM usuarios WHERE email=%s AND activo=1", (d.get("email"),), one=True)
    if not u or not check_password_hash(u["password_hash"], d.get("password", "")):
        return jsonify(error="Credenciales incorrectas"), 401
    return jsonify(token=make_token(u), rol=u["rol"], nombre=u["nombre"])


# ---------- PERFIL ----------
@app.get("/me")
@auth()
def me():
    return jsonify(query("SELECT id,nombre,email,rol FROM usuarios WHERE id=%s", (g.user["id"],), one=True))


@app.put("/me")
@auth()
def update_me():
    d = request.get_json(silent=True) or {}
    if need(d, "nombre"):
        return jsonify(error="Nombre requerido"), 400
    query("UPDATE usuarios SET nombre=%s WHERE id=%s", (d["nombre"], g.user["id"]), write=True)
    return jsonify(ok=True)


# ---------- PRODUCTOS ----------
@app.get("/products")
@auth()
def products():
    return jsonify(query("SELECT * FROM productos WHERE activo=1 ORDER BY nombre"))


@app.post("/products")
@auth(["admin"])
def create_product():
    d = request.get_json(silent=True) or {}
    if need(d, "nombre"):
        return jsonify(error="Nombre requerido"), 400
    try:
        pid = query("INSERT INTO productos(codigo_barras,nombre,marca,categoria,imagen_url) VALUES(%s,%s,%s,%s,%s)",
                    (d.get("codigo_barras") or None, d["nombre"], d.get("marca"), d.get("categoria"), d.get("imagen_url")), write=True)
    except mysql.connector.IntegrityError:
        return jsonify(error="Ya existe un producto con ese código de barras"), 409
    return jsonify(id=pid), 201


@app.put("/products/<int:pid>")
@auth(["admin"])
def update_product(pid):
    d = request.get_json(silent=True) or {}
    if need(d, "nombre"):
        return jsonify(error="Nombre requerido"), 400
    query("UPDATE productos SET nombre=%s,marca=%s,categoria=%s,imagen_url=%s WHERE id=%s",
          (d["nombre"], d.get("marca"), d.get("categoria"), d.get("imagen_url"), pid), write=True)
    return jsonify(ok=True)


@app.delete("/products/<int:pid>")
@auth(["admin"])
def delete_product(pid):  # baja lógica: conserva el historial
    query("UPDATE productos SET activo=0 WHERE id=%s", (pid,), write=True)
    return jsonify(ok=True)


# ---------- MOVIMIENTOS ----------
@app.post("/movements")
@auth(["admin", "empleado"])
def create_movement():
    d = request.get_json(silent=True) or {}
    try:
        pid, qty = int(d["product_id"]), int(d["cantidad"])
    except (KeyError, ValueError, TypeError):
        return jsonify(error="Datos inválidos"), 400
    if d.get("tipo") not in ("entrada", "salida") or qty <= 0:
        return jsonify(error="Tipo o cantidad inválidos"), 400
    con = conn(); cur = con.cursor(dictionary=True)
    try:  # transacción: stock + historial juntos
        cur.execute("SELECT stock FROM productos WHERE id=%s AND activo=1 FOR UPDATE", (pid,))
        p = cur.fetchone()
        if not p:
            return jsonify(error="Producto no encontrado"), 404
        if d["tipo"] == "salida" and p["stock"] < qty:
            return jsonify(error=f"Stock insuficiente ({p['stock']} disponibles)"), 409
        delta = qty if d["tipo"] == "entrada" else -qty
        cur.execute("UPDATE productos SET stock=stock+%s WHERE id=%s", (delta, pid))
        cur.execute("INSERT INTO movimientos(producto_id,usuario_id,tipo,cantidad) VALUES(%s,%s,%s,%s)",
                    (pid, g.user["id"], d["tipo"], qty))
        con.commit()
        return jsonify(ok=True, stock=p["stock"] + delta), 201
    except Exception:
        con.rollback(); raise
    finally:
        cur.close(); con.close()


@app.get("/movements")
@auth()
def movements():
    rows = query("""SELECT m.id,m.tipo,m.cantidad,m.fecha,p.nombre AS producto,u.nombre AS usuario
        FROM movimientos m JOIN productos p ON p.id=m.producto_id
        JOIN usuarios u ON u.id=m.usuario_id ORDER BY m.fecha DESC LIMIT 200""")
    return jsonify([{**r, "fecha": r["fecha"].isoformat()} for r in rows])


# ---------- USUARIOS (admin) ----------
@app.get("/users")
@auth(["admin"])
def users():
    return jsonify(query("SELECT id,nombre,email,rol,activo FROM usuarios"))


@app.post("/users")
@auth(["admin"])
def create_user():
    d = request.get_json(silent=True) or {}
    if need(d, "nombre", "email", "password") or d.get("rol") not in ("admin", "empleado"):
        return jsonify(error="Datos inválidos"), 400
    uid = query("INSERT INTO usuarios(nombre,email,password_hash,rol) VALUES(%s,%s,%s,%s)",
                (d["nombre"], d["email"], generate_password_hash(d["password"]), d["rol"]), write=True)
    return jsonify(id=uid), 201


@app.put("/users/<int:uid>")
@auth(["admin"])
def update_user(uid):
    d = request.get_json(silent=True) or {}
    query("UPDATE usuarios SET rol=COALESCE(%s,rol), activo=COALESCE(%s,activo) WHERE id=%s",
          (d.get("rol"), d.get("activo"), uid), write=True)
    return jsonify(ok=True)


# ---------- API EXTERNA: Open Food Facts ----------
@app.get("/barcode/<code>")
@auth(["admin"])
def barcode(code):
    if not code.isdigit():
        return jsonify(error="Código inválido"), 400
    try:
        r = requests.get(f"https://world.openfoodfacts.org/api/v2/product/{code}.json",
                         headers={"User-Agent": "StockGo/1.0 (proyecto escolar)"}, timeout=8)
        data = r.json()
    except (requests.RequestException, ValueError):
        return jsonify(error="No se pudo contactar Open Food Facts"), 502
    if data.get("status") != 1:
        return jsonify(error="Producto no encontrado en Open Food Facts"), 404
    p = data["product"]
    return jsonify(codigo_barras=code, nombre=p.get("product_name", ""), marca=p.get("brands", ""),
                   categoria=(p.get("categories", "") or "").split(",")[0].strip(),
                   imagen_url=p.get("image_front_url", ""))


if __name__ == "__main__":
    app.run(debug=True)
