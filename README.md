# StockGo — Gestión de inventario inteligente

![CI](https://github.com/alexis20051212/StockGo/actions/workflows/ci.yml/badge.svg)

## Objetivo
StockGo es una aplicación móvil cliente-servidor que automatiza el registro de entradas y
salidas de inventario de un pequeño negocio. Cada movimiento queda asociado al usuario que lo
realizó y el acceso se controla por roles (Administrador y Empleado).

Este repositorio también documenta el entorno de desarrollo: control de versiones con Git y
GitHub, y un flujo de integración continua que ejecuta las pruebas automáticamente.

## Herramientas utilizadas
| Herramienta | Uso |
|---|---|
| Python 3.12 + Flask | API REST (backend) |
| MySQL (Aiven) | Base de datos |
| Flutter + Dart | Aplicación móvil Android |
| pytest | Pruebas automatizadas |
| Git y GitHub | Control de versiones |
| GitHub Actions | Integración continua |
| Render | Despliegue de la API en la nube |

## Estructura del proyecto
```
StockGo/
├── .github/workflows/ci.yml   # integración continua
├── backend/                   # API Flask (app.py, requirements.txt)
├── database/                  # scripts SQL de MySQL
├── mobile/                    # app Flutter
├── tests/                     # pruebas automatizadas (pytest)
├── docs/                      # documentación
└── README.md
```

## Cómo ejecutar el proyecto
### API (backend)
```
cd backend
python -m venv venv
venv\Scripts\activate            # Linux/Mac: source venv/bin/activate
pip install -r requirements.txt
copy .env.example .env           # Linux/Mac: cp .env.example .env  (y editar los datos)
python app.py
```
La API queda en `http://127.0.0.1:5000` (prueba con `/health`).

### Pruebas automatizadas
Desde la raíz del repositorio:
```
pip install -r backend/requirements.txt
pytest tests -v
```

### App móvil
```
cd mobile
flutter pub get
flutter run --dart-define=API_URL=http://10.0.2.2:5000
```

## Integración continua
El archivo `.github/workflows/ci.yml` ejecuta las pruebas con pytest en cada `push` y en cada
`pull request` hacia `main` o `develop`. El resultado aparece en la pestaña **Actions**.

## Control de versiones
- Ramas: `main` (estable), `develop` (integración) y `feature/*` (funcionalidades).
- Commits con el formato `tipo: descripción` (`feat`, `fix`, `docs`, `test`, `refactor`, `style`).

## Autores
Alexis Jiménez Salas y Melani Judith Zermeño Yáñez — Desarrollo Móvil Integral, grupo 10 D.
