# Firmar el APK con una clave propia

El APK de depuración se firma con una clave genérica. Para una entrega o publicación se firma con un
*keystore* propio. **Guarda el archivo `.jks` y sus contraseñas en un lugar seguro y NUNCA los subas a GitHub.**

## 1. Crear el keystore (una sola vez)
En PowerShell:

```
keytool -genkey -v -keystore C:\dev\stockgo-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias stockgo
```

Responde las preguntas y elige una contraseña. Anótala: si la pierdes no podrás actualizar la app firmada.

## 2. Crear `mobile/android/key.properties` (no se sube a Git)
```
storePassword=TU_CONTRASEÑA
keyPassword=TU_CONTRASEÑA
keyAlias=stockgo
storeFile=C:/dev/stockgo-release.jks
```

## 3. Configurar Gradle
Abre `mobile/android/app/build.gradle.kts` (o `build.gradle` si tu proyecto es Groovy).

**Kotlin DSL (`build.gradle.kts`):** al inicio del archivo agrega

```kotlin
import java.util.Properties
import java.io.FileInputStream

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}
```

dentro de `android { ... }` agrega, antes de `buildTypes`:

```kotlin
    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
            storeFile = file(keystoreProperties["storeFile"] as String)
            storePassword = keystoreProperties["storePassword"] as String
        }
    }
```

y en `buildTypes { release { ... } }` cambia la línea de firma por:

```kotlin
            signingConfig = signingConfigs.getByName("release")
```

**Groovy (`build.gradle`):** al inicio agrega

```groovy
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}
```

y dentro de `android { ... }`:

```groovy
    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }
    buildTypes {
        release {
            signingConfig signingConfigs.release
        }
    }
```

## 4. Compilar
```
cd C:\dev\StockGo\mobile
flutter build apk --release --dart-define=API_URL=https://stockgo-px32.onrender.com --dart-define=API_TIMEOUT=60
```

## 5. Verificar la firma
```
keytool -printcert -jarfile build\app\outputs\flutter-apk\app-release.apk
```
Debe mostrar el propietario que escribiste al crear el keystore (no "Android Debug").

## Importante
- Un APK firmado con otra clave **no se puede instalar encima** del anterior: desinstala la app una vez
  y vuelve a instalar. Después las actualizaciones funcionan normal mientras uses siempre el mismo keystore.
- Agrega a `.gitignore`: `key.properties`, `*.jks`, `*.keystore`.
