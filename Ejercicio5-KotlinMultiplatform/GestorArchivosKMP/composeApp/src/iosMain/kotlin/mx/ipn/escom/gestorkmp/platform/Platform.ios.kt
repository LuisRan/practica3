@file:OptIn(ExperimentalForeignApi::class, BetaInteropApi::class)

package mx.ipn.escom.gestorkmp.platform

import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.toComposeImageBitmap
import kotlinx.cinterop.BetaInteropApi
import kotlinx.cinterop.ExperimentalForeignApi
import kotlinx.cinterop.addressOf
import kotlinx.cinterop.usePinned
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.IO
import mx.ipn.escom.gestorkmp.data.FileEntry
import mx.ipn.escom.gestorkmp.data.RootLocation
import org.jetbrains.skia.Image
import platform.Foundation.NSCachesDirectory
import platform.Foundation.NSData
import platform.Foundation.NSDate
import platform.Foundation.NSDateFormatter
import platform.Foundation.NSDateFormatterMediumStyle
import platform.Foundation.NSDateFormatterShortStyle
import platform.Foundation.NSDocumentDirectory
import platform.Foundation.NSFileManager
import platform.Foundation.NSFileModificationDate
import platform.Foundation.NSFileSize
import platform.Foundation.NSFileType
import platform.Foundation.NSFileTypeDirectory
import platform.Foundation.NSHomeDirectory
import platform.Foundation.NSNumber
import platform.Foundation.NSSearchPathForDirectoriesInDomains
import platform.Foundation.NSTemporaryDirectory
import platform.Foundation.NSURL
import platform.Foundation.NSUserDomainMask
import platform.Foundation.create
import platform.Foundation.dataWithContentsOfFile
import platform.Foundation.dateWithTimeIntervalSince1970
import platform.Foundation.timeIntervalSince1970
import platform.Foundation.writeToFile
import platform.UIKit.UIActivityViewController
import platform.UIKit.UIApplication
import platform.UIKit.UIDevice
import platform.UIKit.UIViewController
import platform.posix.memcpy

actual fun platformName(): String =
    "${UIDevice.currentDevice.systemName} ${UIDevice.currentDevice.systemVersion}"

actual val ioDispatcher: CoroutineDispatcher = Dispatchers.IO

actual fun formatDate(epochMillis: Long): String {
    val formatter = NSDateFormatter().apply {
        dateStyle = NSDateFormatterMediumStyle
        timeStyle = NSDateFormatterShortStyle
    }
    return formatter.stringFromDate(NSDate.dateWithTimeIntervalSince1970(epochMillis / 1000.0))
}

/** Decodificación con Skia (el motor gráfico de Compose Multiplatform en iOS). */
actual fun decodeImage(bytes: ByteArray): ImageBitmap? =
    runCatching { Image.makeFromEncoded(bytes).toComposeImageBitmap() }.getOrNull()

/** DataStore vive en Library/ (no visible en la app Archivos ni en "Documentos"). */
actual fun dataStorePath(): String = "${NSHomeDirectory()}/Library/gestor.preferences_pb"

private fun searchPath(directory: ULong): String =
    (NSSearchPathForDirectoriesInDomains(directory, NSUserDomainMask, true).firstOrNull() as? String)
        ?: NSHomeDirectory()

/**
 * Implementación iOS con NSFileManager. Solo se accede al contenedor (sandbox)
 * de la app: Documents, tmp y Library/Caches.
 */
actual class PlatformFileSystem actual constructor() {
    private val fm = NSFileManager.defaultManager

    actual fun roots(): List<RootLocation> = listOf(
        RootLocation("docs", "Documentos", searchPath(NSDocumentDirectory)),
        RootLocation("tmp", "Temporales (tmp)", NSTemporaryDirectory().trimEnd('/')),
        RootLocation("cache", "Caché (Library/Caches)", searchPath(NSCachesDirectory)),
    )

    actual fun list(path: String): List<FileEntry> {
        val names = fm.contentsOfDirectoryAtPath(path, null)
            ?: throw IllegalStateException("No se puede leer la carpeta.")
        return names.mapNotNull { name -> (name as? String)?.let { entry("$path/$it") } }
    }

    actual fun entry(path: String): FileEntry? {
        val attrs = fm.attributesOfItemAtPath(path, null) ?: return null
        val isDir = (attrs[NSFileType] as? String) == NSFileTypeDirectory
        val size = when (val v = attrs[NSFileSize]) {
            is NSNumber -> v.longLongValue
            is Long -> v
            is Int -> v.toLong()
            else -> 0L
        }
        val modified = (attrs[NSFileModificationDate] as? NSDate)?.timeIntervalSince1970 ?: 0.0
        return FileEntry(
            path = path,
            name = path.trimEnd('/').substringAfterLast('/'),
            isDirectory = isDir,
            size = if (isDir) 0L else size,
            modifiedMillis = (modified * 1000).toLong(),
            childCount = if (isDir) fm.contentsOfDirectoryAtPath(path, null)?.size ?: 0 else null,
        )
    }

    actual fun exists(path: String): Boolean = fm.fileExistsAtPath(path)

    actual fun createDirectory(path: String): Boolean = fm.createDirectoryAtPath(path, true, null, null)

    actual fun delete(path: String): Boolean = fm.removeItemAtPath(path, null)

    actual fun move(from: String, to: String): Boolean = fm.moveItemAtPath(from, to, null)

    actual fun copy(from: String, to: String): Boolean = fm.copyItemAtPath(from, to, null)

    actual fun readText(path: String, maxBytes: Int): String? {
        val bytes = readBytes(path) ?: return null
        return (if (bytes.size > maxBytes) bytes.copyOf(maxBytes) else bytes).decodeToString()
    }

    actual fun writeText(path: String, text: String): Boolean =
        text.encodeToByteArray().toNSData().writeToFile(path, true)

    actual fun readBytes(path: String): ByteArray? {
        val data = NSData.dataWithContentsOfFile(path) ?: return null
        val size = data.length.toInt()
        val bytes = ByteArray(size)
        if (size > 0) {
            bytes.usePinned { pinned -> memcpy(pinned.addressOf(0), data.bytes, data.length) }
        }
        return bytes
    }
}

private fun ByteArray.toNSData(): NSData =
    if (isEmpty()) NSData()
    else usePinned { pinned -> NSData.create(bytes = pinned.addressOf(0), length = size.toULong()) }

/** iOS no requiere permiso para el sandbox de la app: siempre concedido. */
actual fun hasStoragePermission(): Boolean = true

@Composable
actual fun rememberStoragePermissionRequester(onResult: (Boolean) -> Unit): () -> Unit =
    remember { { onResult(true) } }

@Composable
actual fun rememberShareFile(): (path: String) -> Unit = remember {
    { path: String ->
        val url = NSURL.fileURLWithPath(path)
        val controller = UIActivityViewController(activityItems = listOf(url), applicationActivities = null)
        topViewController()?.let { top ->
            // En iPad la hoja se presenta como popover y necesita una vista de origen.
            controller.popoverPresentationController?.sourceView = top.view
            top.presentViewController(controller, animated = true, completion = null)
        }
    }
}

private fun topViewController(): UIViewController? {
    var top = UIApplication.sharedApplication.keyWindow?.rootViewController
    while (top?.presentedViewController != null) top = top.presentedViewController
    return top
}

/** En iOS no hay botón "atrás" del sistema; la navegación usa la barra superior. */
@Composable
actual fun PlatformBackHandler(enabled: Boolean, onBack: () -> Unit) = Unit
