# StockGo — Gestión de inventario inteligente
Flutter + Flask + MySQL + Open Food Facts.

## 1. Base de datos
Ejecuta `database/schema.sql` en tu MySQL (local o cloud).

## 2. Backend
cd backend && python -m venv venv && source venv/bin/activate   # Windows: venv\Scripts\activate
pip install -r requirements.txt
cp .env.example .env   # y edita tus credenciales
python app.py          # http://127.0.0.1:5000
pytest ../tests        # pruebas

## 3. App móvil
cd mobile
flutter create . --org com.stockgo --platforms android   # genera la carpeta android/
flutter pub get
flutter run                                              # emulador usa 10.0.2.2:5000
# Release (requiere HTTPS en tu backend desplegado):
flutter build apk --release --dart-define=API_URL=https://tu-backend

> En AndroidManifest.xml agrega: <uses-permission android:name="android.permission.INTERNET"/>
