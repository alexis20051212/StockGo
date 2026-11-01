# StockGo — Gestión de inventario inteligente

![CI](https://github.com/alexis20051212/StockGo/actions/workflows/ci.yml/badge.svg)

Aplicación móvil cliente-servidor para controlar el inventario de un pequeño negocio: registra
entradas y salidas, asocia cada movimiento con el usuario responsable y restringe las acciones
por rol (Administrador y Empleado). Integra una API de terceros (Open Food Facts) para llenar
automáticamente los datos de un producto a partir de su código de barras.

## Tecnologías
| Componente | Tecnología |
|---|---|
| App móvil | Flutter + Dart (Android) |
| API REST | Python 3.12 + Flask, JWT (PyJWT), gunicorn |
| Base de datos | MySQL (Aiven, conexión SSL) |
| API de terceros | Open Food Facts (API v2) |
| Nube | Render (API con HTTPS) |
| Pruebas / CI | pytest + GitHub Actions |

## Requisitos
- Python 3.12 o superior
- Flutter 3.x y Android SDK (para compilar la app)
- Un servidor MySQL (local o en la nube)
- Git

## Instalación y ejecución
### 1. Base de datos
Ejecuta `database/schema.sql` en tu servidor MySQL.

### 2. API (backend)
```
cd backend
python -m venv venv
venv\Scripts\activate            # Linux/Mac: source venv/bin/activate
pip install -r requirements.txt
copy .env.example .env           # Linux/Mac: cp .env.example .env
python app.py
```
La API queda en `http://127.0.0.1:5000`. Comprueba con `/health`.

### 3. Variables de entorno
Se configuran en `backend/.env` (local) o en el panel de Render (nube). **El archivo `.env` no se
sube al repositorio** (está en `.gitignore`); solo se incluye `.env.example`, sin valores reales.

| Variable | Descripción |
|---|---|
| `SECRET_KEY` | Clave para firmar los tokens. Genera una larga y aleatoria: `python -c "import secrets; print(secrets.token_hex(32))"` |
| `DB_HOST`, `DB_PORT` | Servidor y puerto de MySQL |
| `DB_USER`, `DB_PASSWORD` | Credenciales de MySQL |
| `DB_NAME` | Nombre de la base de datos |
| `DB_SSL` | `true` para bases en la nube que exigen SSL |
| `DB_SSL_CA` | Archivo del certificado de la autoridad (por ejemplo `ca.pem`) |

### 4. App móvil
```
cd mobile
flutter pub get
flutter run --dart-define=API_URL=http://10.0.2.2:5000          # emulador + API local
flutter build apk --release --dart-define=API_URL=https://TU-API.onrender.com --dart-define=API_TIMEOUT=60
```
`API_URL` indica la dirección de la API y `API_TIMEOUT` el tiempo máximo de espera en segundos.

### 5. Primer uso
Al abrir la app por primera vez, se crea la cuenta del **Administrador** (la contraseña debe tener
al menos 8 caracteres, un número y un carácter especial). Después, el Administrador crea a los
empleados desde la pestaña **Usuarios**.

## Pruebas
Desde la raíz del repositorio:
```
pip install -r backend/requirements.txt
pytest tests -v
```
Las mismas pruebas se ejecutan en GitHub Actions (`.github/workflows/ci.yml`) en cada `push`.

## Estado de las funcionalidades
**Terminadas:** inicio de sesión con JWT, roles y restricciones, consulta de inventario, alta de
productos (manual y con código de barras), registro de entradas y salidas, historial de
movimientos, administración de usuarios, validación de contraseñas, consulta a Open Food Facts,
despliegue en la nube y pruebas automatizadas.

**Pendientes:** pantalla para editar productos (el endpoint ya existe), pantalla de perfil, límite
de intentos de inicio de sesión, caché sin conexión, APK firmado de producción y atribución a
Open Food Facts en la interfaz.

## Estructura
```
StockGo/
├── .github/workflows/ci.yml   # integración continua
├── backend/                   # API Flask
├── database/                  # scripts SQL
├── mobile/                    # app Flutter (lib/core, lib/repositories, lib/screens, lib/widgets)
├── tests/                     # pruebas automatizadas
├── docs/                      # documentación técnica
└── README.md
```

## Control de versiones
Ramas `main` (estable), `develop` (integración) y `feature/*`. Commits con el formato
`tipo: descripción` (`feat`, `fix`, `docs`, `test`, `refactor`, `style`).

## Documentación
El documento técnico completo está en la carpeta `docs/`.
