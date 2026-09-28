package mx.ipn.escom.gestorkmp.platform

import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.ImageBitmap
import kotlinx.coroutines.CoroutineDispatcher
import mx.ipn.escom.gestorkmp.data.FileEntry
import mx.ipn.escom.gestorkmp.data.RootLocation

/*
 * Declaraciones `expect` del módulo compartido.
 * Cada una tiene su implementación `actual` en androidMain (java.io / Android SDK)
 * y en iosMain (Foundation / UIKit vía Kotlin/Native).
 */

/** Nombre y versión del sistema operativo. */
expect fun platformName(): String

/** Dispatcher para operaciones de E/S (Dispatchers.IO en ambas plataformas). */
expect val ioDispatcher: CoroutineDispatcher

/** Formatea una fecha (epoch en ms) con el formato local del sistema. */
expect fun formatDate(epochMillis: Long): String

/** Decodifica una imagen (PNG/JPEG/...) a ImageBitmap. Android: BitmapFactory. iOS: Skia. */
expect fun decodeImage(bytes: ByteArray): ImageBitmap?

/** Ruta del archivo de DataStore dentro del sandbox. */
expect fun dataStorePath(): String

/**
 * Acceso al sistema de archivos. Android usa java.io.File sobre los directorios
 * de la app; iOS usa NSFileManager sobre el contenedor (sandbox) de la app.
 */
expect class PlatformFileSystem() {
    /** Ubicaciones raíz accesibles para la app. */
    fun roots(): List<RootLocation>
    fun list(path: String): List<FileEntry>
    fun entry(path: String): FileEntry?
    fun exists(path: String): Boolean
    fun createDirectory(path: String): Boolean
    fun delete(path: String): Boolean
    fun move(from: String, to: String): Boolean
    fun copy(from: String, to: String): Boolean
    fun readText(path: String, maxBytes: Int): String?
    fun writeText(path: String, text: String): Boolean
    fun readBytes(path: String): ByteArray?
}

/** ¿Se concedió el permiso de almacenamiento compartido? (iOS: siempre true, usa sandbox). */
expect fun hasStoragePermission(): Boolean

/** Devuelve una función que solicita el permiso de almacenamiento y reporta el resultado. */
@Composable
expect fun rememberStoragePermissionRequester(onResult: (Boolean) -> Unit): () -> Unit

/** Devuelve una función que abre la hoja de compartir del sistema para un archivo. */
@Composable
expect fun rememberShareFile(): (path: String) -> Unit

/** Manejo del botón "atrás" del sistema (Android). En iOS no existe; se usa la barra superior. */
@Composable
expect fun PlatformBackHandler(enabled: Boolean, onBack: () -> Unit)
