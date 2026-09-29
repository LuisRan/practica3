<div align="center">

# Instituto Politécnico Nacional
## Escuela Superior de Cómputo

**Ingeniería en Sistemas Computacionales · Plan 2020**
**Unidad de aprendizaje:** Desarrollo de aplicaciones móviles nativas

# Práctica 3: Aplicaciones Nativas

| Integrante | Boleta |
|---|---|
| Rangel Mata José Luis | 2023630577 |

**Profesor:** Gabriel Hurtado Avilés · **Grupo:** 7CV4 · **Asignatura:** Desarrollo de aplicaciones móviles nativas
**Fecha de entrega:** 28 de septiembre de 2026

</div>

---

## Índice

1. [Introducción](#1-introducción)
2. [Desarrollo](#2-desarrollo)
   - [Ejercicio 1 · Entorno macOS e iOS](#ejercicio-1--entorno-macos-e-ios)
   - [Ejercicio 2 · Gestor de Archivos para iPhone](#ejercicio-2--gestor-de-archivos-para-iphone)
   - [Ejercicio 3 · Cámara y Micrófono para iPhone](#ejercicio-3--cámara-y-micrófono-para-iphone)
   - [Ejercicio 4 · Flutter (cámara y micrófono)](#ejercicio-4--flutter-opción-b-cámara-y-micrófono)
   - [Ejercicio 5 · Kotlin Multiplatform (gestor de archivos)](#ejercicio-5--kotlin-multiplatform-opción-a-gestor-de-archivos)
   - [Comparación Flutter vs Kotlin Multiplatform](#comparación-entre-flutter-y-kotlin-multiplatform)
3. [Instalación y uso](#3-instalación-y-uso)
4. [Binarios](#4-binarios)
5. [Pruebas realizadas](#5-pruebas-realizadas)
6. [Bitácora de trabajo](#6-bitácora-de-trabajo)
7. [Conclusiones](#7-conclusiones)
8. [Bibliografía](#8-bibliografía)

> Las capturas de pantalla se guardan en [`docs/img/`](docs/img). Donde dice **📸** va la captura correspondiente.

---

## 1. Introducción

El objetivo de esta práctica fue desarrollar aplicaciones nativas para los ecosistemas Apple y Android que interactúan con recursos del dispositivo (sistema de archivos, cámara y micrófono) e implementan almacenamiento local, de modo que funcionan **completamente sin conexión a Internet**.

Se completaron cinco ejercicios:

| # | Aplicación | Tecnología | Persistencia | Carpeta |
|---|---|---|---|---|
| 1 | HolaESCOM (prueba del entorno) | Swift 5 · SwiftUI · Xcode | `@AppStorage` | [`Ejercicio1-EntornoMacOS`](Ejercicio1-EntornoMacOS) |
| 2 | Gestor de Archivos para iPhone | SwiftUI + UIKit (Quick Look, DocumentPicker) | UserDefaults + caché en disco | [`Ejercicio2-GestorArchivos`](Ejercicio2-GestorArchivos) |
| 3 | Cámara y Micrófono para iPhone | SwiftUI · AVFoundation · Core Image | Core Data | [`Ejercicio3-CamaraMicrofono`](Ejercicio3-CamaraMicrofono) |
| 4 | Cámara y Micrófono (Opción B) | Flutter · Dart · Provider | SQLite (sqflite) | [`Ejercicio4-Flutter`](Ejercicio4-Flutter) |
| 5 | Gestor de Archivos (Opción A) | Kotlin Multiplatform · Compose Multiplatform | DataStore multiplataforma | [`Ejercicio5-KotlinMultiplatform`](Ejercicio5-KotlinMultiplatform) |

**Entorno utilizado:** uno de los integrantes cuenta con una **Mac física (MacBook Air)**, por lo que —como lo permite la práctica— se trabajó directamente en macOS sin virtualizarlo con `MacOS-Docker`. macOS se usó únicamente como entorno de desarrollo; las apps se ejecutan en el **simulador de iPhone** (y Android en su emulador).

Todas las apps implementan los temas **Guinda (IPN)** y **Azul (ESCOM)**, que se adaptan automáticamente al modo claro/oscuro del sistema.

---

## 2. Desarrollo

### Ejercicio 1 · Entorno macOS e iOS

#### 1.1 Identificación del equipo

| Integrante | Equipo | CPU | RAM | Almacenamiento libre | GPU | Virtualización | ¿Apto? |
|---|---|---|---|---|---|---|---|
| Rangel Mata José Luis | **Mac (Apple M1)** | Apple M1 | 8 GB | _[__]_ GB | Integrada Apple | N/A (macOS nativo) | **Sí — Mac física** |
| _[Integrante 2]_ | _[Equipo]_ | _[CPU]_ | _[__]_ GB | _[__]_ GB | _[GPU]_ | _[Sí/No]_ | _[Sí/No]_ |
| _[Integrante 3]_ | _[Equipo]_ | _[CPU]_ | _[__]_ GB | _[__]_ GB | _[GPU]_ | _[Sí/No]_ | _[Sí/No]_ |

Requisitos de `gabrielhuav/MacOS-Docker`: **16 GB de RAM**, **20 GB libres (50 GB con Xcode)** y CPU con virtualización.

**Justificación:** se eligió la MacBook Air porque ejecuta macOS de forma nativa. Xcode y los simuladores usan aceleración de hardware, y no hace falta virtualizar con QEMU/KVM, generar números de serie ni descargar la imagen de macOS (~1 h).

- **Responsable del equipo utilizado:** Rangel Mata José Luis — Boleta 2023630577
- **Equipo:** Mac con chip Apple M1, 8 GB de RAM, macOS _[versión]_, Xcode _[versión]_

📸 `docs/img/ej1_acerca_de_mac.png` — *Acerca de esta Mac*

#### 1.2 Instalación con MacOS-Docker (ruta alternativa)

No fue necesaria al contar con una Mac, pero se documenta para equipos sin Mac, siguiendo el README de [gabrielhuav/MacOS-Docker](https://github.com/gabrielhuav/MacOS-Docker):

1. **Windows:** Docker Desktop → *Settings › Resources › WSL Integration* → *Enable integration with my default WSL distro*. En `C:\Users\<usuario>\.wslconfig`:
   ```ini
   [wsl2]
   nestedVirtualization=true
   ```
   Verificar KVM con `kvm-ok` (si falla: `sudo apt -y install bridge-utils cpu-checker libvirt-clients libvirt-daemon qemu qemu-kvm`) e instalar `x11-apps`.
2. **Linux:** instalar `qemu`, `libvirt`, `virt-manager`; habilitar `libvirtd` y `virtlogd`; `echo 1 | sudo tee /sys/module/kvm/parameters/ignore_msrs`; `sudo modprobe kvm`.
3. **Contenedor** (recursos: 8 GB de RAM, 8 hilos, 4 núcleos; ajustar a ~50 % del anfitrión):
   ```bash
   docker run -it --device /dev/kvm -p 50922:10022 \
     -v /tmp/.X11-unix:/tmp/.X11-unix -e "DISPLAY=${DISPLAY:-:0.0}" \
     -e GENERATE_UNIQUE=true \
     -e MASTER_PLIST_URL='https://raw.githubusercontent.com/sickcodes/osx-serial-generator/master/config-custom.plist' \
     -e SHORTNAME=ventura -e RAM=8 -e SMP=8 -e CORES=4 \
     sickcodes/docker-osx:latest
   ```
4. En el instalador: *macOS Base System* → *Disk Utility* → borrar el disco **QEMU** como `MacOS` (APFS, GUID) → *Reinstall macOS* → asistente inicial. Verificar que arranca y tiene Internet.

#### 1.3 Configuración del entorno iOS (en la Mac)

```bash
sudo xcodebuild -license accept          # tras instalar Xcode desde la Mac App Store
xcodebuild -version
xcrun simctl list devices available      # simuladores de iPhone y iPad
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew install cocoapods                   # CocoaPods (lo requiere Flutter en iOS)
swift package --version                  # Swift Package Manager (incluido en Xcode)
```

Los simuladores se instalan desde *Xcode › Settings › Components › iOS*.

**Proyecto de prueba `HolaESCOM`** (SwiftUI): muestra el modelo y la versión del sistema, si se ejecuta en simulador o en dispositivo, un contador con estado y el cambio de tema Guinda/Azul.

📸 `docs/img/ej1_xcode.png` · `docs/img/ej1_simuladores.png` · `docs/img/ej1_holaescom.png`

---

### Ejercicio 2 · Gestor de Archivos para iPhone

App en **Swift 5 + SwiftUI** con componentes UIKit integrados mediante `UIViewControllerRepresentable`. Se organiza en `Models/`, `Services/`, `Theme/` y `Views/`.

**Funcionalidades principales**

| Requisito | Implementación |
|---|---|
| Explorar el sandbox | `FileManager` sobre `Documents`, `Documents/Inbox` y `tmp` (`FileService`) |
| Estructura jerárquica con íconos por tipo | `NavigationStack` con rutas tipadas; ícono según `UTType` y miniaturas para imagen/PDF/video |
| Archivos de texto | `.txt .md .swift .json …` con edición, Markdown renderizado y formateo de JSON |
| Imágenes | Zoom con pinza (`MagnifyGesture`), rotación (`RotateGesture`), desplazamiento, doble toque, botón *Ajustar* |
| Vista previa nativa | `QLPreviewController` (Quick Look) incrustado y a pantalla completa |
| Gestión | Crear carpetas/archivos, copiar, mover (barra *Pegar aquí*), duplicar, renombrar y eliminar con confirmación |
| Importar | `UIDocumentPickerViewController` (Archivos / iCloud Drive) |
| Compartir/exportar | `UIActivityViewController` |

**Interfaz:** temas Guinda y Azul con colores dinámicos (`UIColor { traits in … }`) para modo claro/oscuro; ruta actual siempre visible (breadcrumb); búsqueda en la carpeta; orden por nombre, fecha o tamaño; **deslizar para eliminar**, **mantener presionado** (menú contextual) y **deslizar hacia abajo para actualizar**; orientación vertical y horizontal, con soporte de iPad.

**Almacenamiento local** (`PreferencesStore`, `ThumbnailCache`):
- Recientes, favoritos, última carpeta visitada, criterio de orden y tema en **UserDefaults**. Las rutas se guardan *relativas al contenedor*, porque la ruta absoluta del sandbox cambia entre instalaciones.
- Caché de miniaturas en dos niveles: `NSCache` en memoria y `Library/Caches/Thumbnails` en disco. La clave incluye la fecha de modificación.

**Permisos y seguridad:**
- Las operaciones destructivas verifican que la ruta esté dentro del contenedor.
- Las carpetas externas se abren con `UIDocumentPicker` y se conservan con **security-scoped bookmarks** (se regeneran si están obsoletos).
- Los archivos inaccesibles, dañados o no soportados muestran un mensaje claro.
- El `Info.plist` declara `UIFileSharingEnabled` y `LSSupportsOpeningDocumentsInPlace`.

**Valor agregado:** el target tiene habilitado **Mac Catalyst**. En la versión de macOS la app corre en una ventana redimensionable; el menú contextual se abre con clic secundario y los gestos de pinza y rotación se hacen con el trackpad. _[Anotar diferencias observadas y agregar captura `docs/img/ej2_macos.png`]_

📸 `docs/img/ej2_inicio.png` · `docs/img/ej2_carpeta_menu.png` · `docs/img/ej2_quicklook.png` · `docs/img/ej2_modo_oscuro_azul.png`

---

### Ejercicio 3 · Cámara y Micrófono para iPhone

App SwiftUI con cuatro pestañas: **Cámara**, **Audio**, **Galería** y **Ajustes**.

| Requisito | Implementación |
|---|---|
| Fotos | `AVCaptureSession` + `AVCapturePhotoOutput` en una cola dedicada; cambio de cámara y zoom (`videoZoomFactor`) |
| Personalización de fotos | Flash auto/encendido/apagado · temporizador de 3 o 10 s · 8 filtros de Core Image (Mono, Noir, Sepia, Chrome, Fade, Instant, Vívido) |
| Audio | `AVAudioRecorder` (AAC `.m4a`) con pausa/reanudación y medidor de nivel en vivo |
| Personalización de audio | Sensibilidad baja/media/alta (`setInputGain` + umbral del medidor) · calidad de muestreo · temporizador de duración máxima (`record(forDuration:)`) |
| Galería | Cuadrícula con miniaturas en caché, visor deslizable con zoom, editor (filtro, brillo, contraste, saturación, rotación, recorte 1:1) |
| Reproductor | `AVAudioPlayer`: progreso, ±10 s y velocidad 0.5×–2× |
| Organización | Álbumes, etiquetas y búsqueda |
| Exportar / importar | Hoja de compartir (individual y en lote); importar fotos (PHPicker) y audios (Archivos) |

**Fuente de captura en el simulador:** el simulador de iOS no tiene cámara física. La app detecta que no hay dispositivo de captura y ofrece la **fototeca con `PHPickerViewController`** como fuente alternativa; el filtro elegido se aplica también a las fotos importadas. En un iPhone físico se usa la cámara real.
**Opción usada en las pruebas:** _[simulador con PHPicker / iPhone físico]_.

**Almacenamiento local:**
- Los archivos se guardan en `Documents/Media/{Photos,Audio}`.
- Los metadatos van en **Core Data**. El modelo se define en código: `MediaItem` ↔ `Album`, con fecha, **ubicación** GPS (CoreLocation, funciona sin Internet y es opcional), **etiquetas**, filtro y duración.
- Las miniaturas se cachean en memoria y en disco.

**Permisos:** el `Info.plist` declara `NSCameraUsageDescription`, `NSMicrophoneUsageDescription` y `NSLocationWhenInUseUsageDescription`. Los permisos se piden en tiempo de ejecución; si se niegan, la app muestra una pantalla explicativa con un botón a *Ajustes*.

**Gestos y animaciones:** destello y háptica al disparar, cuenta regresiva animada, pulso del botón de grabación, zoom con pinza, doble toque para cambiar de cámara y deslizamiento entre fotos.

📸 `docs/img/ej3_camara.png` · `docs/img/ej3_grabadora.png` · `docs/img/ej3_galeria.png` · `docs/img/ej3_editor.png`

---

### Ejercicio 4 · Flutter (Opción B: cámara y micrófono)

Replica las funciones del Ejercicio 3 en **Android e iOS** con un solo código Dart.

**Arquitectura (Clean Architecture):**

```
lib/
├── domain/        entidades, contrato MediaRepository, casos de uso (sin dependencias de Flutter)
├── data/          SQLite (sqflite) + FileStorage (path_provider) + MediaRepositoryImpl
├── services/      procesamiento de imágenes en isolate, permisos
├── presentation/  páginas, widgets y providers
└── core/          tema Guinda/Azul (Material 3) y utilidades
```

Flujo: *Widget → Provider → Caso de uso → MediaRepository (abstracto) → SQLite + archivos*. Cambiar la persistencia solo afecta a `data/`.

**Gestión de estado:** **Provider** (`ChangeNotifier`): `SettingsProvider`, `GalleryProvider` y `RecorderProvider`. Se eligió sobre Bloc porque requiere menos código repetitivo para una app de este tamaño y es el enfoque recomendado por la documentación oficial.

**Plugins utilizados y justificación**

| Paquete | Uso | Por qué |
|---|---|---|
| `camera` | Vista previa, captura, flash, zoom, cambio de cámara | Plugin oficial (CameraX / AVFoundation) |
| `record` | Grabación AAC con amplitud en tiempo real | Pausa, `autoGain`, `noiseSuppress` y *stream* para el medidor |
| `audioplayers` | Reproducción, posición y velocidad | *Streams* de posición/duración |
| `permission_handler` | Permisos con diálogo hacia Ajustes | Distingue denegación permanente en ambas plataformas |
| `sqflite` | Metadatos relacionales | Álbumes ↔ medios con `ON DELETE SET NULL`, búsquedas con `JOIN`/`LIKE` |
| `path_provider` · `shared_preferences` | Directorios del sandbox · tema | Multiplataforma |
| `image` | Filtros, rotación, recorte, miniaturas | Dart puro: da el mismo resultado en Android e iOS; corre en *isolate* |
| `image_picker` · `file_picker` · `share_plus` | Importar fotos y audios · exportar | Selectores y hoja de compartir nativos |

**Decisiones destacadas:**
- Cada filtro es una **matriz de color 4×5**. La vista previa en vivo de la cámara usa `ColorFiltered` y al guardar se aplica la *misma* matriz píxel a píxel, así que lo que se ve es lo que se guarda.
- Las imágenes se limitan a 2560 px y las miniaturas (320 px) se cachean en disco y en memoria.
- La cámara se libera al cambiar de pestaña o pasar a segundo plano.
- En el simulador iOS (sin cámara) se ofrece la galería como fuente alternativa.
- UI **Material Design 3** idéntica en ambas plataformas; modo claro/oscuro según el sistema (también seleccionable).

📸 `docs/img/ej4_android.png` · `docs/img/ej4_ios.png`

---

### Ejercicio 5 · Kotlin Multiplatform (Opción A: gestor de archivos)

Se eligió la opción contraria a Flutter para experimentar con ambos tipos de acceso a recursos.

**Estructura del proyecto:**

```
GestorArchivosKMP/
├── composeApp/src/
│   ├── commonMain/   UI (Compose Multiplatform), FileManagerViewModel (Coroutines + StateFlow),
│   │                 FileRepository, PreferencesRepository (DataStore), declaraciones expect
│   ├── androidMain/  actual con java.io / Android SDK + MainActivity
│   ├── iosMain/      actual con Foundation / UIKit + MainViewController
│   └── commonTest/   pruebas de la lógica compartida
└── iosApp/           app SwiftUI anfitriona (Xcode compila el framework Kotlin)
```

**Implementaciones `expect/actual`**

| `expect` (commonMain) | Android | iOS |
|---|---|---|
| `PlatformFileSystem` | `java.io.File` | `NSFileManager` + `NSData` |
| `roots()` | `filesDir/Documentos`, caché, almacenamiento externo de la app, `Pictures` público | `Documents`, `tmp`, `Library/Caches` |
| Permisos de almacenamiento | `READ_MEDIA_IMAGES` (API 33+) / `READ_EXTERNAL_STORAGE` con `ActivityResultContracts` | Siempre concedido: la app solo usa su sandbox |
| Compartir | `Intent.ACTION_SEND` + `FileProvider` | `UIActivityViewController` |
| `decodeImage` | `BitmapFactory` | Skia |
| `formatDate` / `ioDispatcher` | `DateFormat` / `Dispatchers.IO` | `NSDateFormatter` / `Dispatchers.IO` |
| `PlatformBackHandler` | `BackHandler` | No aplica |

**Librerías:** Compose Multiplatform 1.9 (Material 3), kotlinx-coroutines 1.10, **androidx DataStore KMP** (tema, orden, favoritos, recientes, última carpeta), okio y material-icons-extended.

**Funciones:**
- Ubicaciones, ruta visible, íconos por tipo, búsqueda y ordenamiento.
- Crear, renombrar, duplicar, copiar/mover y eliminar con confirmación.
- Deslizar para eliminar, menú al mantener presionado y *pull-to-refresh*.
- Visor y editor de texto; visor de imágenes (pinza, rotación, doble toque).
- Compartir, favoritos y recientes; la app restaura la última carpeta al abrir.
- Material 3 en Android y apariencia coherente en iOS; temas con modo claro/oscuro automático.

📸 `docs/img/ej5_android.png` · `docs/img/ej5_ios.png`

---

### Comparación entre Flutter y Kotlin Multiplatform

| Criterio | Flutter (Ej. 4) | Kotlin Multiplatform (Ej. 5) |
|---|---|---|
| Lenguaje | Dart 3 | Kotlin 2 (Kotlin/Native en iOS) |
| Construcción de la interfaz | Widgets propios dibujados por el motor de Flutter; 100 % compartida | Compose Multiplatform compartido **o** UI nativa por plataforma consumiendo el mismo módulo |
| Acceso a APIs nativas | Plugins (*platform channels*); si no existe, hay que escribir código nativo + canal | Directo con `expect/actual`, sin puentes ni serialización |
| Código compartido | ≈ 100 % del código Dart | ≈ 85–90 % (`commonMain`) |
| Tamaño del APK release | _[__]_ MB medido (referencia 18–25 MB, incluye el motor) | _[__]_ MB medido (referencia 8–12 MB) |
| Curva de aprendizaje | Baja-media: un lenguaje y un árbol de widgets | Media-alta: Gradle, *source sets*, interop con Swift/ObjC y Xcode |
| Madurez del ecosistema | Muy madura (estable desde 2018), pub.dev extenso, *hot reload* | KMP estable desde 2023, Compose para iOS estable desde 2025; menos librerías listas para multimedia |

**Conclusión:** para la **app de cámara y micrófono**, Flutter resultó más adecuado. Los plugins mantenidos resuelven lo más complejo (AVFoundation/CameraX, grabación y permisos) y el *hot reload* aceleró el trabajo de interfaz. En KMP habría que escribir `expect/actual` para `AVCaptureSession` y CameraX a mano.

Para el **gestor de archivos**, KMP encajó mejor. El sistema de archivos es una API acotada, ideal para `expect/actual` (`java.io.File` ↔ `NSFileManager`), y se obtiene código nativo con la lógica de negocio compartida y probada una sola vez.

En general: Flutter si se prioriza velocidad de desarrollo y una UI idéntica; KMP si se prioriza integración nativa profunda o reutilizar conocimiento de Android/Kotlin.

---

## 3. Instalación y uso

**Requisitos:** macOS con Xcode 16+ (los proyectos usan carpetas sincronizadas de Xcode 16) · simulador iOS 17+ · Flutter 3.27+ · Android Studio con JDK 17+ · Android API 24+.

```bash
git clone https://github.com/LuisRan/practica3.git && cd practica3
```

| Ejercicio | Cómo ejecutarlo |
|---|---|
| 1 | `open Ejercicio1-EntornoMacOS/HolaESCOM/HolaESCOM.xcodeproj` → elegir un iPhone → ⌘R |
| 2 | `open Ejercicio2-GestorArchivos/GestorArchivos/GestorArchivos.xcodeproj` → ⌘R (o destino *My Mac (Mac Catalyst)*) |
| 3 | `open Ejercicio3-CamaraMicrofono/CamaraMic/CamaraMic.xcodeproj` → ⌘R |
| 4 | `cd Ejercicio4-Flutter/camara_mic_flutter && ./tool/setup_platforms.sh && flutter run` |
| 5 | Android: `cd Ejercicio5-KotlinMultiplatform/GestorArchivosKMP && ./gradlew :composeApp:assembleDebug` · iOS: `open iosApp/iosApp.xcodeproj` → ⌘R |

- `setup_platforms.sh` (Ej. 4) genera `android/` e `ios/` con `flutter create` sin tocar `lib/`. Agrega los permisos (`CAMERA`, `RECORD_AUDIO`, `NSCameraUsageDescription`, `NSMicrophoneUsageDescription`, `NSPhotoLibraryUsageDescription`), fija `minSdk 24` y ejecuta `flutter pub get`.
- En el Ej. 5, la fase *Compile Kotlin Framework* de Xcode ejecuta `./gradlew :composeApp:embedAndSignAppleFrameworkForXcode`.
- Pruebas unitarias: `flutter test` (Ej. 4) y `./gradlew :composeApp:allTests` (Ej. 5).

**Compilar todo de una vez:** `./tools/build_all.sh` compila los proyectos iOS para el simulador y los APK de Flutter y KMP, y deja los resultados en `binarios/`.

## 4. Binarios

| Archivo en [`binarios/`](binarios) | Ejercicio | Plataforma |
|---|---|---|
| `HolaESCOM-simulador.app.zip` | 1 | Simulador iOS |
| `GestorArchivos-simulador.app.zip` | 2 | Simulador iOS |
| `CamaraMic-simulador.app.zip` | 3 | Simulador iOS |
| `CamaraMicFlutter.apk` · build de simulador iOS | 4 | Android · iOS |
| `GestorArchivosKMP.apk` · `iosApp-simulador.app.zip` | 5 | Android · iOS |
| `capturas/` | 1–5 | Capturas de simulador y emulador |

Una IPA para iPhone físico requiere firmar con una cuenta de desarrollador de Apple (*Product › Archive*). Por eso, como permite la práctica, se entregan builds de simulador y capturas. Instalar un `.app` en el simulador: `xcrun simctl install booted <App>.app`.

---

## 5. Pruebas realizadas

| App | Plataforma / dispositivo | Casos probados | Resultado |
|---|---|---|---|
| HolaESCOM | Simulador iPhone _[modelo]_, iOS _[__]_ | Compilación, ejecución, estado, cambio de tema | _[OK]_ |
| Gestor de Archivos | Simulador iPhone y iPad | Navegar, crear, renombrar, copiar/mover, eliminar, Quick Look, importar, compartir, favoritos, recientes, rotación, modo oscuro | _[OK]_ |
| Cámara y Micrófono | Simulador (PHPicker) / iPhone físico _[si aplica]_ | Permisos, captura con filtros/flash/temporizador, grabación con límite, reproducción, álbumes, etiquetas, exportar/importar | _[OK]_ |
| Flutter | Emulador Android API _[__]_ y simulador iOS | Mismos casos del Ej. 3 en ambas plataformas | _[OK]_ |
| KMP | Emulador Android API _[__]_ y simulador iOS | Mismos casos del Ej. 2, permiso de almacenamiento en Android, pruebas `commonTest` | _[OK]_ |

Todas las apps se probaron en **modo avión** para verificar que funcionan sin conexión.

📸 Capturas de las pruebas en `binarios/capturas/`.

---

## 6. Bitácora de trabajo

**Responsable del equipo utilizado:** Rangel Mata José Luis (boleta 2023630577), propietario de la MacBook Air. Todas las sesiones se hicieron sobre esa computadora, en persona o de forma remota con pantalla compartida.
**Unión con otro equipo:** No aplica.

| # | Fecha | Inicio | Término | Modalidad | Integrantes presentes | Actividades | Evidencia |
|---|---|---|---|---|---|---|---|
| 1 | _[__/__/2026]_ | _[__:__]_ | _[__:__]_ | _[Presencial/Remota]_ | _[...]_ | Comparación de equipos, elección de la Mac, Xcode y simuladores, HolaESCOM | `docs/img/bitacora/s1.jpg` |
| 2 | _[__/__/2026]_ | | | | | Ej. 2: navegación, operaciones, Quick Look, importación | |
| 3 | _[__/__/2026]_ | | | | | Ej. 2: temas, favoritos, recientes, caché, pruebas | |
| 4 | _[__/__/2026]_ | | | | | Ej. 3: AVFoundation, Core Data, galería | |
| 5 | _[__/__/2026]_ | | | | | Ej. 4: Flutter, compilación Android/iOS | |
| 6 | _[__/__/2026]_ | | | | | Ej. 5: KMP, expect/actual, compilación Android/iOS | |
| 7 | 28/09/2026 | | | | | Integración, README/informe, binarios y capturas | |

📸 Evidencia de las reuniones (fotos del equipo trabajando o capturas de videollamada) en `docs/img/bitacora/`.

---

## 7. Conclusiones

**Desarrollo para iOS y el ecosistema Apple.** SwiftUI permite construir interfaces declarativas con muy poco código, pero varias capacidades clave siguen en UIKit y deben integrarse con `UIViewControllerRepresentable`: Quick Look, el selector de documentos y la hoja de compartir. El modelo de *sandbox* obliga a pensar desde el inicio en rutas relativas, permisos declarados en el `Info.plist` y *security-scoped bookmarks*, lo que hace que las apps sean más seguras por diseño.

**Entorno macOS y MacOS-Docker.** Contar con una Mac física simplificó mucho el trabajo. MacOS-Docker exige hardware con virtualización, 16 GB de RAM y un proceso de instalación largo, aunque sigue siendo una alternativa viable para equipos sin Mac, con la penalización de rendimiento propia de la emulación.

**Flutter vs Kotlin Multiplatform.** Flutter destacó por su productividad y su ecosistema de plugins, en especial para multimedia. Kotlin Multiplatform ofreció un acceso más directo y tipado a las APIs nativas con `expect/actual`, a cambio de una configuración más compleja (Gradle, Kotlin/Native y Xcode). La elección depende del tipo de app y de la experiencia del equipo; ambos permiten compartir la mayor parte del código y funcionar sin conexión.

_[Reflexión personal de cada integrante]_

---

## 8. Bibliografía

- Apple Inc. (2025). *AVFoundation*. Apple Developer Documentation. https://developer.apple.com/documentation/avfoundation
- Apple Inc. (2025). *Core Data*. Apple Developer Documentation. https://developer.apple.com/documentation/coredata
- Apple Inc. (2025). *FileManager*. Apple Developer Documentation. https://developer.apple.com/documentation/foundation/filemanager
- Apple Inc. (2025). *Human Interface Guidelines*. https://developer.apple.com/design/human-interface-guidelines
- Apple Inc. (2025). *QLPreviewController*. Apple Developer Documentation. https://developer.apple.com/documentation/quicklook/qlpreviewcontroller
- Apple Inc. (2025). *UIDocumentPickerViewController*. Apple Developer Documentation. https://developer.apple.com/documentation/uikit/uidocumentpickerviewcontroller
- Flutter. (2025). *Flutter documentation*. Google. https://docs.flutter.dev
- Flutter. (2025). *Guide to app architecture*. Google. https://docs.flutter.dev/app-architecture
- gabrielhuav. (2024). *MacOS-Docker* [Repositorio de software]. GitHub. https://github.com/gabrielhuav/MacOS-Docker
- Google. (2025). *DataStore*. Android Developers. https://developer.android.com/topic/libraries/architecture/datastore
- Google. (2025). *Material Design 3*. https://m3.material.io
- JetBrains. (2025). *Kotlin Multiplatform documentation*. https://kotlinlang.org/docs/multiplatform.html
- JetBrains. (2025). *Expected and actual declarations*. https://kotlinlang.org/docs/multiplatform/multiplatform-expect-actual.html
- JetBrains. (2025). *Compose Multiplatform*. https://www.jetbrains.com/compose-multiplatform/
- Martin, R. C. (2017). *Clean Architecture: A craftsman's guide to software structure and design*. Prentice Hall.
- sickcodes. (2024). *Docker-OSX* [Repositorio de software]. GitHub. https://github.com/sickcodes/Docker-OSX
