# Ejercicio 4 · Flutter — Cámara y Micrófono (Opción B)

App multiplataforma (Android + iOS) con las funciones del Ejercicio 3: fotos con filtros, flash, temporizador y zoom; grabación de audio con sensibilidad, calidad y temporizador; galería con álbumes, etiquetas, editor y reproductor. Funciona **sin Internet**.

## Cómo ejecutar

```bash
cd camara_mic_flutter
./tool/setup_platforms.sh     # 1 sola vez: flutter create (android/ios) + permisos + pub get
flutter run                   # elige emulador Android o simulador iOS
flutter test                  # pruebas unitarias
./tool/setup_platforms.sh --build   # APK release -> ../binarios/CamaraMicFlutter.apk
```

`setup_platforms.sh` genera las carpetas nativas con `flutter create` (sin tocar `lib/`) y agrega:

- **Android** (`AndroidManifest.xml`): `CAMERA`, `RECORD_AUDIO`, `uses-feature` no obligatorios; `minSdk 24`.
- **iOS** (`Info.plist`): `NSCameraUsageDescription`, `NSMicrophoneUsageDescription`, `NSPhotoLibraryUsageDescription`, `UIFileSharingEnabled`.
- **iOS** (`Podfile`, incluido): macros de `permission_handler` (`PERMISSION_CAMERA`, `PERMISSION_MICROPHONE`, `PERMISSION_PHOTOS`).

## Arquitectura (Clean Architecture)

```
lib/
├── main.dart                     Composición / inyección de dependencias
├── core/                         Tema (Guinda/Azul, M3 claro/oscuro) y utilidades
├── domain/                       ← no depende de Flutter ni de plugins
│   ├── entities/                 MediaItem, Album, PhotoFilter, PhotoEdits
│   ├── repositories/             Contrato MediaRepository
│   └── usecases/                 Capturar, importar, editar, etiquetar, mover a álbum
├── data/
│   ├── datasources/              SQLite (sqflite) + FileStorage (path_provider)
│   ├── models/                   Mapeo entidad <-> fila SQL
│   └── repositories/             MediaRepositoryImpl
├── services/                     Procesamiento de imágenes (isolate) y permisos
└── presentation/
    ├── providers/                SettingsProvider, GalleryProvider, RecorderProvider (Provider)
    ├── pages/                    Cámara, Audio, Galería, Visor/Editor, Ajustes
    └── widgets/                  Reproductor, detalles/etiquetas, medidor de nivel
```

**Flujo:** Widget → Provider (`ChangeNotifier`) → Caso de uso → `MediaRepository` (abstracto) → implementación con SQLite + archivos. La UI nunca conoce `sqflite` ni rutas de archivo; cambiar la persistencia (p. ej. a Hive) solo toca `data/`.

**Por qué Provider:** es el mecanismo recomendado en la documentación oficial para apps medianas, requiere poco código repetitivo y encaja con `ChangeNotifier`. Bloc habría añadido eventos/estados por cada acción sin beneficio real para el tamaño de esta app.

## Plugins utilizados

| Paquete | Uso | Justificación |
|---|---|---|
| `camera` | Vista previa, captura, flash, zoom, cambio de cámara | Plugin oficial del equipo de Flutter (CameraX en Android, AVFoundation en iOS) |
| `record` | Grabación AAC con amplitud en tiempo real | Soporta pausa/reanudar, `autoGain`, `noiseSuppress` y stream de amplitud para el medidor |
| `audioplayers` | Reproducción, posición, velocidad | API sencilla con streams de posición/duración |
| `permission_handler` | Permisos en tiempo de ejecución con diálogo para abrir Ajustes | Unifica Android/iOS y distingue *denegado permanentemente* |
| `sqflite` | Metadatos (fecha, filtro, duración, etiquetas, álbum) | SQL relacional: álbumes ↔ medios con `ON DELETE SET NULL`, búsquedas con `LIKE` y `JOIN` |
| `path_provider` | Directorios de documentos y caché | Rutas del sandbox en ambas plataformas |
| `shared_preferences` | Tema y modo claro/oscuro | Clave-valor simple |
| `image` | Filtros, rotación, recorte, miniaturas | Dart puro: mismo resultado en Android e iOS; se ejecuta en un *isolate* (`compute`) |
| `image_picker` | Importar fotos / fuente alternativa en el simulador iOS | Usa PHPicker en iOS y Photo Picker en Android (sin permisos extra) |
| `file_picker` | Importar audios desde Archivos | Selector nativo de documentos |
| `share_plus` | Exportar / compartir | Hoja de compartir del sistema |
| `provider` | Gestión de estado | Ver arriba |

## Decisiones destacadas

- **Filtro en vivo idéntico al guardado:** cada filtro es una matriz de color 4×5. La vista previa de la cámara usa `ColorFiltered(ColorFilter.matrix(...))` y al guardar se aplica la **misma** matriz píxel a píxel en un *isolate*.
- **Rendimiento:** imágenes limitadas a 2560 px, miniaturas de 320 px en caché de disco + memoria, procesamiento fuera del hilo de UI, cámara liberada al salir de la pestaña o pasar a segundo plano.
- **Simulador iOS sin cámara:** `availableCameras()` devuelve lista vacía; la pantalla ofrece la galería/fototeca (el filtro se aplica al importar).
- **Temas:** `ColorScheme.fromSeed` con el guinda/azul institucional; `ThemeMode.system` por defecto (seleccionable en Ajustes).
