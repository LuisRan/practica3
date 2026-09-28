# Práctica 3 · Aplicaciones Nativas

**Instituto Politécnico Nacional — Escuela Superior de Cómputo**
Ingeniería en Sistemas Computacionales (Plan 2020) · *Desarrollo de aplicaciones móviles nativas*

Repositorio con los 5 ejercicios de la práctica: entorno macOS/Xcode, dos apps nativas para iPhone (Swift/SwiftUI) y dos apps multiplataforma (Flutter y Kotlin Multiplatform) para Android e iOS. Todas funcionan **sin conexión a Internet** y almacenan sus datos localmente, con los temas **Guinda (IPN)** y **Azul (ESCOM)** adaptados a modo claro/oscuro.

| # | Ejercicio | Tecnología | Carpeta |
|---|-----------|------------|---------|
| 1 | Entorno macOS + Xcode y proyecto de prueba | Mac física · Swift/SwiftUI | [`Ejercicio1-EntornoMacOS`](Ejercicio1-EntornoMacOS) |
| 2 | Gestor de Archivos para iPhone | Swift 5 · SwiftUI + UIKit · UserDefaults | [`Ejercicio2-GestorArchivos`](Ejercicio2-GestorArchivos) |
| 3 | Cámara y Micrófono para iPhone | Swift 5 · SwiftUI · AVFoundation · Core Data | [`Ejercicio3-CamaraMicrofono`](Ejercicio3-CamaraMicrofono) |
| 4 | Multiplataforma **Opción B** (cámara y micrófono) | Flutter/Dart · Provider · sqflite | [`Ejercicio4-Flutter`](Ejercicio4-Flutter) |
| 5 | Multiplataforma **Opción A** (gestor de archivos) | Kotlin Multiplatform · Compose Multiplatform · DataStore | [`Ejercicio5-KotlinMultiplatform`](Ejercicio5-KotlinMultiplatform) |

Documentación: [`docs/`](docs) (informe técnico, guía de instalación, bitácora, comparativa Flutter vs KMP). Binarios: [`binarios/`](binarios).

---

## Requisitos

| Herramienta | Versión probada / mínima |
|---|---|
| macOS + Xcode | Xcode 16 o superior (los proyectos usan el formato de carpetas sincronizadas de Xcode 16) |
| iOS (simulador o dispositivo) | iOS 17+ (ejercicios 1–3 y 5), iOS 14+ (Flutter) |
| Flutter | 3.27+ (Dart 3.5+) |
| Android Studio | Ladybug/Meerkat o superior, JDK 17+ |
| Android | API 24 (Android 7.0) o superior |

---

## Ejercicio 1 · Entorno de desarrollo

El equipo cuenta con una **Mac física (MacBook Air)**, por lo que, como permite la práctica, se trabajó directamente en macOS sin virtualizar con `MacOS-Docker`. La guía completa (incluida la ruta con Docker para quien no tenga Mac) está en [`docs/Ejercicio1_Instalacion.md`](docs/Ejercicio1_Instalacion.md).

Proyecto de prueba:

```bash
open Ejercicio1-EntornoMacOS/HolaESCOM/HolaESCOM.xcodeproj
# o por terminal:
xcodebuild -project Ejercicio1-EntornoMacOS/HolaESCOM/HolaESCOM.xcodeproj -scheme HolaESCOM \
  -destination 'platform=iOS Simulator,name=iPhone 16' build
```

## Ejercicio 2 · Gestor de Archivos (iPhone)

```bash
open Ejercicio2-GestorArchivos/GestorArchivos/GestorArchivos.xcodeproj   # ⌘R con un simulador de iPhone
```

- Explora `Documents`, `Documents/Inbox` y `tmp` con `FileManager`; íconos por `UTType`; ruta actual siempre visible.
- Texto (`.txt .md .swift .json…`, con edición y Markdown renderizado), imágenes con pinza/rotación/ajuste, **Quick Look** (`QLPreviewController`).
- Crear carpetas y archivos, copiar, mover, duplicar, renombrar y eliminar con confirmación.
- Importar desde Archivos/iCloud (`UIDocumentPickerViewController`), compartir (`UIActivityViewController`).
- Carpetas externas con **security-scoped bookmarks**.
- Búsqueda, ordenamiento (nombre/fecha/tamaño), deslizar para eliminar, menú contextual, *pull-to-refresh*, vertical/horizontal.
- Persistencia: recientes, favoritos, última carpeta, criterio de orden y tema (UserDefaults); caché de miniaturas en memoria + disco.
- `Info.plist`: `UIFileSharingEnabled` y `LSSupportsOpeningDocumentsInPlace`.
- **Opcional (valor agregado):** el target tiene habilitado **Mac Catalyst** (`SUPPORTS_MACCATALYST = YES`): elige *My Mac (Mac Catalyst)* como destino.

## Ejercicio 3 · Cámara y Micrófono (iPhone)

```bash
open Ejercicio3-CamaraMicrofono/CamaraMic/CamaraMic.xcodeproj
```

- Fotos con `AVCaptureSession` + `AVCapturePhotoOutput`: flash (auto/on/off), temporizador (3/10 s), 8 filtros Core Image, zoom con pinza, doble toque para cambiar de cámara.
- Audio con `AVAudioRecorder`: sensibilidad (ganancia + umbral), calidad, temporizador de duración máxima, medidor de nivel en vivo.
- **Simulador:** no tiene cámara; la app lo detecta y ofrece la fototeca con `PHPickerViewController` (fuente alternativa documentada). En un iPhone físico se usa la cámara real.
- Galería: cuadrícula con miniaturas en caché, visor con zoom y deslizamiento, editor (filtro, brillo, contraste, saturación, rotación, recorte 1:1), reproductor `AVAudioPlayer` (±10 s, velocidad), álbumes y etiquetas.
- **Core Data** (modelo definido en código) para metadatos: fecha, ubicación (GPS, opcional), etiquetas, filtro, duración y álbum.
- Exportar (hoja de compartir) e importar (fototeca y archivos de audio).

## Ejercicio 4 · Flutter (Opción B: cámara y micrófono)

```bash
cd Ejercicio4-Flutter/camara_mic_flutter
./tool/setup_platforms.sh          # genera android/ e ios/ y aplica permisos
flutter run                        # Android o simulador iOS
./tool/setup_platforms.sh --build  # APK en binarios/ (+ build de simulador iOS en macOS)
```

Clean Architecture (`domain` / `data` / `presentation`), estado con **Provider**, metadatos en **SQLite (sqflite)**, preferencias en SharedPreferences, filtros con matriz de color (vista previa en vivo con `ColorFiltered` y procesado en *isolate* con `image`). Detalle de plugins y decisiones en [`Ejercicio4-Flutter/README.md`](Ejercicio4-Flutter/README.md).

## Ejercicio 5 · Kotlin Multiplatform (Opción A: gestor de archivos)

```bash
cd Ejercicio5-KotlinMultiplatform/GestorArchivosKMP
./gradlew :composeApp:assembleDebug          # APK Android
open iosApp/iosApp.xcodeproj                 # iOS: Xcode compila el framework Kotlin automáticamente
```

`commonMain` contiene la UI (Compose Multiplatform), el ViewModel (Coroutines + `StateFlow`) y los repositorios; `androidMain`/`iosMain` implementan con `expect/actual` el sistema de archivos (java.io vs `NSFileManager`), permisos, compartir, decodificación de imágenes, fechas y *dispatcher* de E/S. Persistencia con **DataStore multiplataforma**. Ver [`Ejercicio5-KotlinMultiplatform/README.md`](Ejercicio5-KotlinMultiplatform/README.md) y la comparativa en [`docs/Comparativa_Flutter_vs_KMP.md`](docs/Comparativa_Flutter_vs_KMP.md).

---

## Estructura

```
practica3/
├── Ejercicio1-EntornoMacOS/HolaESCOM/         Proyecto Swift de prueba
├── Ejercicio2-GestorArchivos/GestorArchivos/  App iOS (SwiftUI)
├── Ejercicio3-CamaraMicrofono/CamaraMic/      App iOS (SwiftUI + AVFoundation + Core Data)
├── Ejercicio4-Flutter/camara_mic_flutter/     App Flutter (Android + iOS)
├── Ejercicio5-KotlinMultiplatform/GestorArchivosKMP/  App KMP (Android + iOS)
├── binarios/                                  APK / builds de simulador / capturas
├── docs/                                      Informe, guía, bitácora y comparativa
└── tools/gen_xcodeproj.py                     Generador de los .xcodeproj
```

## Compilar todo (script)

En macOS con Xcode, Flutter y Android SDK instalados:

```bash
./tools/build_all.sh
```

Compila los tres proyectos iOS para el simulador, el APK de Flutter y el APK de KMP, y deja los resultados en `binarios/`.

## Integrantes

| Nombre | Boleta |
|---|---|
| _[Nombre completo]_ | _[Boleta]_ |
| _[Nombre completo]_ | _[Boleta]_ |
| _[Nombre completo]_ | _[Boleta]_ |

Profesor: _[Nombre]_ · Grupo: _[Grupo]_ · Fecha de entrega: 28 de septiembre de 2026
