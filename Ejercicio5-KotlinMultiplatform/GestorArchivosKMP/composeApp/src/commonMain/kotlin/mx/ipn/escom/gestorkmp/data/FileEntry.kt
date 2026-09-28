package mx.ipn.escom.gestorkmp.data

/** Archivo o carpeta (modelo común para ambas plataformas). */
data class FileEntry(
    val path: String,
    val name: String,
    val isDirectory: Boolean,
    val size: Long,
    val modifiedMillis: Long,
    val childCount: Int? = null,
) {
    val extension: String get() = name.substringAfterLast('.', "").lowercase()

    val kind: FileKind
        get() = when {
            isDirectory -> FileKind.FOLDER
            extension in FileKind.IMAGE_EXT -> FileKind.IMAGE
            extension in FileKind.TEXT_EXT -> FileKind.TEXT
            extension in FileKind.CODE_EXT -> FileKind.CODE
            extension == "pdf" -> FileKind.PDF
            extension in FileKind.AUDIO_EXT -> FileKind.AUDIO
            extension in FileKind.VIDEO_EXT -> FileKind.VIDEO
            extension in FileKind.ARCHIVE_EXT -> FileKind.ARCHIVE
            else -> FileKind.OTHER
        }
}

enum class FileKind(val label: String) {
    FOLDER("Carpeta"), TEXT("Texto"), CODE("Código"), IMAGE("Imagen"), PDF("PDF"),
    AUDIO("Audio"), VIDEO("Video"), ARCHIVE("Comprimido"), OTHER("Archivo");

    val isTextual: Boolean get() = this == TEXT || this == CODE

    companion object {
        val IMAGE_EXT = setOf("png", "jpg", "jpeg", "gif", "webp", "bmp", "heic")
        val TEXT_EXT = setOf("txt", "md", "markdown", "csv", "log", "rtf")
        val CODE_EXT = setOf("kt", "kts", "swift", "java", "json", "xml", "yml", "yaml", "dart", "py", "js", "ts", "html", "css", "sh", "gradle", "toml", "plist")
        val AUDIO_EXT = setOf("mp3", "m4a", "wav", "aac", "ogg", "flac")
        val VIDEO_EXT = setOf("mp4", "mov", "mkv", "webm", "3gp")
        val ARCHIVE_EXT = setOf("zip", "rar", "7z", "tar", "gz")
    }
}

/** Ubicación raíz (Documentos, caché, almacenamiento externo, etc.). */
data class RootLocation(
    val id: String,
    val title: String,
    val path: String,
    val requiresPermission: Boolean = false,
    val readOnly: Boolean = false,
)

enum class SortOption(val label: String) { NAME("Nombre"), DATE("Fecha"), SIZE("Tamaño") }

fun List<FileEntry>.sortEntries(option: SortOption, ascending: Boolean): List<FileEntry> {
    val comparator: Comparator<FileEntry> = when (option) {
        SortOption.NAME -> compareBy { it.name.lowercase() }
        SortOption.DATE -> compareBy { it.modifiedMillis }
        SortOption.SIZE -> compareBy { it.size }
    }
    val ordered = if (ascending) comparator else comparator.reversed()
    // Las carpetas siempre primero.
    return sortedWith(compareByDescending<FileEntry> { it.isDirectory }.then(ordered))
}

fun formatSize(bytes: Long): String {
    if (bytes < 1024) return "$bytes B"
    val units = listOf("KB", "MB", "GB", "TB")
    var value = bytes / 1024.0
    var i = 0
    while (value >= 1024 && i < units.lastIndex) {
        value /= 1024
        i++
    }
    val rounded = (value * 10).toLong() / 10.0
    return "$rounded ${units[i]}"
}

/** Une una ruta de carpeta con un nombre usando "/" (válido en Android e iOS). */
fun joinPath(dir: String, name: String): String = if (dir.endsWith("/")) dir + name else "$dir/$name"

fun parentPath(path: String): String = path.trimEnd('/').substringBeforeLast('/', "/").ifEmpty { "/" }

fun fileName(path: String): String = path.trimEnd('/').substringAfterLast('/')
