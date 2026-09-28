# Ejercicio 5 · Kotlin Multiplatform — Gestor de Archivos (Opción A)

Gestor de archivos para **Android e iOS** con la lógica y la interfaz compartidas en `commonMain` (Compose Multiplatform). Se eligió la opción contraria a Flutter (que implementó cámara y micrófono) para experimentar ambos tipos de acceso a recursos.

## Cómo compilar

```bash
cd GestorArchivosKMP
./gradlew :composeApp:assembleDebug        # APK: composeApp/build/outputs/apk/debug/
./gradlew :composeApp:allTests             # pruebas de commonMain (JVM + simulador iOS)
open iosApp/iosApp.xcodeproj               # ⌘R: la fase "Compile Kotlin Framework" ejecuta
                                           # ./gradlew :composeApp:embedAndSignAppleFrameworkForXcode
```

También se puede abrir la carpeta `GestorArchivosKMP` en **Android Studio** (con el plugin Kotlin Multiplatform) y ejecutar la configuración *composeApp* (Android) o *iosApp* (iOS).

## Estructura del proyecto

```
GestorArchivosKMP/
├── composeApp/src/
│   ├── commonMain/kotlin/mx/ipn/escom/gestorkmp/
│   │   ├── App.kt                    UI raíz (tema + navegación con animaciones)
│   │   ├── data/FileEntry.kt         Modelo, tipos por extensión, ordenamiento
│   │   ├── data/Repositories.kt      FileRepository + PreferencesRepository (DataStore)
│   │   ├── platform/Platform.kt      ← declaraciones expect
│   │   ├── viewmodel/                FileManagerViewModel (Coroutines + StateFlow)
│   │   └── ui/                       Home, Carpeta, Visor, Ajustes, Tema, componentes
│   ├── androidMain/                  actual con java.io / Android SDK + MainActivity
│   ├── iosMain/                      actual con Foundation/UIKit + MainViewController
│   └── commonTest/                   Pruebas de la lógica compartida
└── iosApp/                           App SwiftUI anfitriona (Xcode)
```

## Implementaciones `expect/actual`

| `expect` (commonMain) | Android (`androidMain`) | iOS (`iosMain`) |
|---|---|---|
| `class PlatformFileSystem` | `java.io.File` (`listFiles`, `renameTo`, `copyRecursively`, `deleteRecursively`) | `NSFileManager` (`contentsOfDirectoryAtPath`, `attributesOfItemAtPath`, `moveItemAtPath`, `copyItemAtPath`, `removeItemAtPath`) + `NSData` |
| `roots()` | `filesDir/Documentos`, `cacheDir`, `getExternalFilesDir`, `Pictures` público | `Documents`, `tmp`, `Library/Caches` |
| `hasStoragePermission()` / `rememberStoragePermissionRequester()` | `READ_MEDIA_IMAGES` (API 33+) o `READ_EXTERNAL_STORAGE` (≤32) con `ActivityResultContracts` | Siempre concedido: iOS no tiene permiso de almacenamiento; la app solo usa su sandbox |
| `rememberShareFile()` | `Intent.ACTION_SEND` + `FileProvider` | `UIActivityViewController` |
| `decodeImage()` | `BitmapFactory` (con submuestreo) | Skia `Image.makeFromEncoded` |
| `formatDate()` | `java.text.DateFormat` | `NSDateFormatter` |
| `ioDispatcher` | `Dispatchers.IO` | `Dispatchers.IO` (kotlinx.coroutines para Native) |
| `dataStorePath()` | `filesDir/gestor.preferences_pb` | `Library/gestor.preferences_pb` |
| `PlatformBackHandler` | `androidx.activity.compose.BackHandler` | No aplica (navegación por barra superior) |

## Funcionalidades

Explorar ubicaciones, ruta siempre visible, íconos por tipo, búsqueda, ordenamiento (nombre/fecha/tamaño, ascendente/descendente), crear carpeta/archivo, renombrar, duplicar, copiar/mover con portapapeles, eliminar con confirmación, **deslizar para eliminar**, **mantener presionado** (menú contextual), **deslizar hacia abajo para actualizar**, visor/editor de texto, visor de imágenes (pinza, rotación, doble toque), compartir, favoritos, recientes, última carpeta restaurada al abrir y tema Guinda/Azul con modo claro/oscuro automático.

## Librerías

| Librería | Uso |
|---|---|
| Compose Multiplatform 1.9 (Material 3) | UI compartida |
| kotlinx-coroutines 1.10 | Asincronía (`suspend`, `withContext`), estado con `StateFlow` |
| androidx.datastore-preferences-core 1.1 (KMP) | Persistencia multiplataforma de preferencias, favoritos y recientes |
| okio | Rutas de archivo para DataStore |
| material-icons-extended | Íconos por tipo de archivo |
| androidx.activity-compose / core-ktx | Integración Android (Activity, permisos, FileProvider) |
