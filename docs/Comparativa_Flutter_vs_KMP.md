# 5.5 Comparación entre Flutter y Kotlin Multiplatform

Comparación basada en las dos apps de esta práctica: **Flutter → cámara y micrófono** (Ejercicio 4) y **KMP → gestor de archivos** (Ejercicio 5).

| Criterio | Flutter (Ej. 4) | Kotlin Multiplatform (Ej. 5) |
|---|---|---|
| **Lenguaje** | Dart 3 (null-safety, *records*, *pattern matching*) | Kotlin 2.2 (el mismo de Android; en iOS compila a nativo con Kotlin/Native) |
| **Construcción de la interfaz** | Widgets propios dibujados por el motor de Flutter (Impeller/Skia); Material 3 o Cupertino; 100 % compartida | Compose Multiplatform (declarativa, compartida) **o** UI nativa por plataforma (Jetpack Compose + SwiftUI) consumiendo el mismo módulo. Aquí: Compose compartido y SwiftUI solo como anfitrión |
| **Acceso a APIs nativas** | Mediante *plugins* (platform channels). Cámara, audio y permisos resueltos con paquetes existentes (`camera`, `record`, `permission_handler`). Si no hay plugin, hay que escribir código Kotlin/Swift y un canal | Directo: `expect/actual` llama a `java.io`/Android SDK y a Foundation/UIKit (`NSFileManager`, `UIActivityViewController`) desde Kotlin sin puentes ni serialización |
| **Código compartido** | ≈ 100 % del código Dart (`lib/`); lo nativo son solo archivos de configuración (Manifest, Info.plist, Podfile) | ≈ 85–90 %: `commonMain` (UI, ViewModel, repositorios, modelo) frente a ~2 archivos `actual` por plataforma (~200 líneas c/u) + la app SwiftUI anfitriona |
| **Tamaño del binario** | APK release típico de 18–25 MB (incluye el motor de Flutter por ABI); `app-bundle` reduce la descarga por dispositivo | APK release de ~8–12 MB (Compose + runtime de Kotlin; con R8 baja más). En iOS el framework de Kotlin/Native + Skiko añade ~15–25 MB |
| **Curva de aprendizaje** | Baja-media: un solo lenguaje y un solo árbol de widgets; hay que aprender Dart y el modelo de *state management* | Media-alta: requiere Kotlin, Gradle, conceptos de *source sets*, interop con Objective-C/Swift y Xcode para iOS. Muy natural para quien ya hace Android |
| **Madurez del ecosistema** | Muy madura (estable desde 2018), pub.dev con miles de paquetes, herramientas (*hot reload*, DevTools) muy pulidas | KMP estable desde nov-2023 y Compose Multiplatform para iOS estable desde mayo-2025; ecosistema creciendo (Ktor, SQLDelight, Room KMP, DataStore KMP), menos librerías listas para cámara/multimedia |
| **Rendimiento / integración** | Excelente y consistente; la UI no usa componentes nativos | Lógica compilada a nativo; con UI nativa se obtiene el *look & feel* exacto de cada plataforma |
| **Depuración y *tooling*** | *Hot reload* muy rápido en ambos SO | *Live edit* limitado; en iOS cada cambio en Kotlin recompila el framework (más lento) |

> Los tamaños de binario son valores de referencia; los medidos en esta entrega se anotan en el informe
> (`ls -lh binarios/*.apk`) una vez compiladas las apps con `tools/build_all.sh`.

## Conclusión

Para la **app de cámara y micrófono**, Flutter resultó el enfoque más adecuado: el trabajo pesado (AVFoundation/CameraX, grabación, permisos) ya está resuelto por plugins mantenidos, lo que permitió enfocarse en la experiencia (filtros en vivo con matrices de color, galería, editor) con un solo código y *hot reload*. Implementar lo mismo en KMP habría exigido escribir a mano `expect/actual` para `AVCaptureSession` y `CameraX`, que es justamente la parte más compleja.

Para el **gestor de archivos**, KMP encajó mejor: el acceso al sistema de archivos es una API pequeña y bien definida, ideal para `expect/actual` (`java.io.File` ↔ `NSFileManager`), y el resultado es código nativo sin canales intermedios, con la lógica de negocio (validación, colisiones de nombres, favoritos, recientes) compartida y probada una sola vez en `commonTest`.

**En general:** si el equipo prioriza velocidad de desarrollo y una UI idéntica en ambas plataformas, Flutter es la opción más productiva; si prioriza integración profunda con APIs nativas, reutilizar conocimiento de Android/Kotlin o conservar interfaces 100 % nativas, KMP es la mejor elección.
