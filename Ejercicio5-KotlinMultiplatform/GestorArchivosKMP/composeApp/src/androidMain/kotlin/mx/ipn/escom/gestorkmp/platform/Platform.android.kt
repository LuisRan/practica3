package mx.ipn.escom.gestorkmp.platform

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.BitmapFactory
import android.os.Build
import android.os.Environment
import android.webkit.MimeTypeMap
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.platform.LocalContext
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.Dispatchers
import mx.ipn.escom.gestorkmp.data.FileEntry
import mx.ipn.escom.gestorkmp.data.RootLocation
import java.io.File
import java.text.DateFormat
import java.util.Date

/** Contexto de la aplicación; se inicializa en MainActivity. */
@SuppressLint("StaticFieldLeak")
object AndroidPlatform {
    lateinit var context: Context
        private set

    fun init(ctx: Context) {
        context = ctx.applicationContext
    }
}

actual fun platformName(): String = "Android ${Build.VERSION.RELEASE} (API ${Build.VERSION.SDK_INT})"

actual val ioDispatcher: CoroutineDispatcher = Dispatchers.IO

actual fun formatDate(epochMillis: Long): String =
    DateFormat.getDateTimeInstance(DateFormat.MEDIUM, DateFormat.SHORT).format(Date(epochMillis))

actual fun decodeImage(bytes: ByteArray): ImageBitmap? {
    // Se reduce la imagen si es muy grande para no agotar la memoria.
    val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
    BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
    if (bounds.outWidth <= 0) return null
    var sample = 1
    while (bounds.outWidth / sample > 4096 || bounds.outHeight / sample > 4096) sample *= 2
    val opts = BitmapFactory.Options().apply { inSampleSize = sample }
    return BitmapFactory.decodeByteArray(bytes, 0, bytes.size, opts)?.asImageBitmap()
}

actual fun dataStorePath(): String =
    File(AndroidPlatform.context.filesDir, "gestor.preferences_pb").absolutePath

/**
 * Implementación Android con java.io.File.
 * Raíces: almacenamiento interno de la app (Documentos), caché, almacenamiento
 * externo específico de la app y la carpeta pública Imágenes (requiere permiso, solo lectura).
 */
actual class PlatformFileSystem actual constructor() {
    private val ctx get() = AndroidPlatform.context

    actual fun roots(): List<RootLocation> {
        val docs = File(ctx.filesDir, "Documentos").apply { mkdirs() }
        val list = mutableListOf(
            RootLocation("docs", "Documentos (interno)", docs.absolutePath),
            RootLocation("cache", "Caché", ctx.cacheDir.absolutePath),
        )
        ctx.getExternalFilesDir(null)?.let {
            list += RootLocation("external", "Almacenamiento externo de la app", it.absolutePath)
        }
        val pictures = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES)
        list += RootLocation("pictures", "Imágenes (compartido)", pictures.absolutePath, requiresPermission = true, readOnly = true)
        return list
    }

    private fun toEntry(f: File) = FileEntry(
        path = f.absolutePath,
        name = f.name,
        isDirectory = f.isDirectory,
        size = if (f.isFile) f.length() else 0L,
        modifiedMillis = f.lastModified(),
        childCount = if (f.isDirectory) f.list()?.size ?: 0 else null,
    )

    actual fun list(path: String): List<FileEntry> {
        val dir = File(path)
        val children = dir.listFiles() ?: throw SecurityException("Sin permiso para leer ${dir.name}")
        return children.map { toEntry(it) }
    }

    actual fun entry(path: String): FileEntry? = File(path).takeIf { it.exists() }?.let { toEntry(it) }
    actual fun exists(path: String): Boolean = File(path).exists()
    actual fun createDirectory(path: String): Boolean = File(path).mkdirs()
    actual fun delete(path: String): Boolean = File(path).deleteRecursively()

    actual fun move(from: String, to: String): Boolean {
        val src = File(from)
        val dst = File(to)
        if (src.renameTo(dst)) return true
        // renameTo falla entre volúmenes: se copia y luego se borra el origen.
        return copy(from, to) && src.deleteRecursively()
    }

    actual fun copy(from: String, to: String): Boolean =
        runCatching { File(from).copyRecursively(File(to), overwrite = false) }.getOrDefault(false)

    actual fun readText(path: String, maxBytes: Int): String? = runCatching {
        File(path).inputStream().use { input ->
            val bytes = input.readNBytesCompat(maxBytes)
            bytes.decodeToString()
        }
    }.getOrNull()

    actual fun writeText(path: String, text: String): Boolean =
        runCatching { File(path).writeText(text) }.isSuccess

    actual fun readBytes(path: String): ByteArray? = runCatching { File(path).readBytes() }.getOrNull()
}

private fun java.io.InputStream.readNBytesCompat(max: Int): ByteArray {
    val buffer = ByteArray(max)
    var total = 0
    while (total < max) {
        val n = read(buffer, total, max - total)
        if (n < 0) break
        total += n
    }
    return buffer.copyOf(total)
}

private fun storagePermissions(): Array<String> =
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) arrayOf(Manifest.permission.READ_MEDIA_IMAGES)
    else arrayOf(Manifest.permission.READ_EXTERNAL_STORAGE)

actual fun hasStoragePermission(): Boolean = storagePermissions().all {
    ContextCompat.checkSelfPermission(AndroidPlatform.context, it) == PackageManager.PERMISSION_GRANTED
}

@Composable
actual fun rememberStoragePermissionRequester(onResult: (Boolean) -> Unit): () -> Unit {
    val launcher = rememberLauncherForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) { result ->
        onResult(result.values.all { it })
    }
    return remember(launcher) { { launcher.launch(storagePermissions()) } }
}

@Composable
actual fun rememberShareFile(): (path: String) -> Unit {
    val context = LocalContext.current
    return remember(context) {
        { path: String ->
            val file = File(path)
            val uri = FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", file)
            val mime = MimeTypeMap.getSingleton().getMimeTypeFromExtension(file.extension.lowercase()) ?: "*/*"
            val send = Intent(Intent.ACTION_SEND).apply {
                type = mime
                putExtra(Intent.EXTRA_STREAM, uri)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            context.startActivity(Intent.createChooser(send, "Compartir ${file.name}").addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        }
    }
}

@Composable
actual fun PlatformBackHandler(enabled: Boolean, onBack: () -> Unit) = BackHandler(enabled, onBack)
