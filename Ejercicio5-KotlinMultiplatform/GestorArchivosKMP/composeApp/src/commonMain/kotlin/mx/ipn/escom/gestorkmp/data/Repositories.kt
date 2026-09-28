package mx.ipn.escom.gestorkmp.data

import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.PreferenceDataStoreFactory
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.withContext
import mx.ipn.escom.gestorkmp.platform.PlatformFileSystem
import mx.ipn.escom.gestorkmp.platform.dataStorePath
import mx.ipn.escom.gestorkmp.platform.ioDispatcher
import okio.Path.Companion.toPath

enum class AppThemeOption(val label: String) { GUINDA("Guinda IPN"), AZUL("Azul ESCOM") }

data class UserPrefs(
    val theme: AppThemeOption = AppThemeOption.GUINDA,
    val sort: SortOption = SortOption.NAME,
    val ascending: Boolean = true,
    val showHidden: Boolean = false,
    val favorites: List<String> = emptyList(),
    val recents: List<String> = emptyList(),
    val lastFolder: String? = null,
)

/**
 * Preferencias persistentes con DataStore multiplataforma (androidx.datastore KMP).
 * Guarda: tema, ordenamiento, favoritos, recientes y última carpeta visitada.
 */
class PreferencesRepository(private val store: DataStore<Preferences> = defaultStore) {

    private object Keys {
        val theme = stringPreferencesKey("theme")
        val sort = stringPreferencesKey("sort")
        val ascending = booleanPreferencesKey("ascending")
        val hidden = booleanPreferencesKey("showHidden")
        val favorites = stringPreferencesKey("favorites")
        val recents = stringPreferencesKey("recents")
        val lastFolder = stringPreferencesKey("lastFolder")
    }

    // Separador que no puede aparecer en rutas de archivo.
    private val sep = "\u0000"

    val prefs: Flow<UserPrefs> = store.data.map { p ->
        UserPrefs(
            theme = p[Keys.theme]?.let { runCatching { AppThemeOption.valueOf(it) }.getOrNull() } ?: AppThemeOption.GUINDA,
            sort = p[Keys.sort]?.let { runCatching { SortOption.valueOf(it) }.getOrNull() } ?: SortOption.NAME,
            ascending = p[Keys.ascending] ?: true,
            showHidden = p[Keys.hidden] ?: false,
            favorites = p[Keys.favorites]?.split(sep)?.filter { it.isNotEmpty() } ?: emptyList(),
            recents = p[Keys.recents]?.split(sep)?.filter { it.isNotEmpty() } ?: emptyList(),
            lastFolder = p[Keys.lastFolder],
        )
    }

    suspend fun setTheme(theme: AppThemeOption) = store.edit { it[Keys.theme] = theme.name }
    suspend fun setSort(sort: SortOption, ascending: Boolean) = store.edit {
        it[Keys.sort] = sort.name
        it[Keys.ascending] = ascending
    }
    suspend fun setShowHidden(value: Boolean) = store.edit { it[Keys.hidden] = value }
    suspend fun setLastFolder(path: String) = store.edit { it[Keys.lastFolder] = path }

    suspend fun toggleFavorite(path: String) = store.edit { p ->
        val list = p[Keys.favorites]?.split(sep)?.filter { it.isNotEmpty() }.orEmpty()
        p[Keys.favorites] = (if (path in list) list - path else list + path).joinToString(sep)
    }

    suspend fun addRecent(path: String) = store.edit { p ->
        val list = p[Keys.recents]?.split(sep)?.filter { it.isNotEmpty() }.orEmpty()
        p[Keys.recents] = (listOf(path) + (list - path)).take(25).joinToString(sep)
    }

    suspend fun clearRecents() = store.edit { it.remove(Keys.recents) }

    /** Mantiene favoritos y recientes coherentes al renombrar/mover/eliminar. */
    suspend fun pathChanged(old: String, new: String?) = store.edit { p ->
        fun fix(raw: String?): String {
            val list = raw?.split(sep)?.filter { it.isNotEmpty() }.orEmpty()
            return list.mapNotNull { item ->
                when {
                    item == old || item.startsWith("$old/") ->
                        new?.let { it + item.removePrefix(old) }
                    else -> item
                }
            }.joinToString(sep)
        }
        p[Keys.favorites] = fix(p[Keys.favorites])
        p[Keys.recents] = fix(p[Keys.recents])
    }

    companion object {
        /** DataStore debe ser único por archivo en todo el proceso. */
        val defaultStore: DataStore<Preferences> by lazy {
            PreferenceDataStoreFactory.createWithPath(produceFile = { dataStorePath().toPath() })
        }
    }
}

/** Resultado de una operación de archivos. */
sealed interface OpResult {
    data object Ok : OpResult
    data class Error(val message: String) : OpResult
}

/**
 * Repositorio de archivos: valida nombres, evita colisiones y ejecuta las
 * operaciones del [PlatformFileSystem] fuera del hilo principal.
 */
class FileRepository(private val fs: PlatformFileSystem = PlatformFileSystem()) {

    fun roots(): List<RootLocation> = fs.roots()

    suspend fun list(path: String, showHidden: Boolean): Result<List<FileEntry>> = withContext(ioDispatcher) {
        runCatching {
            if (!fs.exists(path)) error("La carpeta no existe o no es accesible.")
            fs.list(path).filter { showHidden || !it.name.startsWith(".") }
        }
    }

    suspend fun entry(path: String): FileEntry? = withContext(ioDispatcher) { fs.entry(path) }

    fun validateName(name: String): String? {
        val clean = name.trim()
        return when {
            clean.isEmpty() -> "El nombre no puede estar vacío."
            '/' in clean || clean == "." || clean == ".." -> "El nombre no puede contener “/”."
            else -> null
        }
    }

    suspend fun createFolder(dir: String, name: String): OpResult = withContext(ioDispatcher) {
        validateName(name)?.let { return@withContext OpResult.Error(it) }
        val target = joinPath(dir, name.trim())
        when {
            fs.exists(target) -> OpResult.Error("Ya existe “${name.trim()}”.")
            fs.createDirectory(target) -> OpResult.Ok
            else -> OpResult.Error("No se pudo crear la carpeta.")
        }
    }

    suspend fun createTextFile(dir: String, name: String): OpResult = withContext(ioDispatcher) {
        validateName(name)?.let { return@withContext OpResult.Error(it) }
        val clean = name.trim().let { if ('.' in it) it else "$it.txt" }
        val target = joinPath(dir, clean)
        when {
            fs.exists(target) -> OpResult.Error("Ya existe “$clean”.")
            fs.writeText(target, "") -> OpResult.Ok
            else -> OpResult.Error("No se pudo crear el archivo.")
        }
    }

    suspend fun rename(path: String, newName: String): Pair<OpResult, String?> = withContext(ioDispatcher) {
        validateName(newName)?.let { return@withContext OpResult.Error(it) to null }
        val target = joinPath(parentPath(path), newName.trim())
        when {
            target == path -> OpResult.Ok to path
            fs.exists(target) -> OpResult.Error("Ya existe “${newName.trim()}”.") to null
            fs.move(path, target) -> OpResult.Ok to target
            else -> OpResult.Error("No se pudo renombrar.") to null
        }
    }

    suspend fun delete(path: String): OpResult = withContext(ioDispatcher) {
        if (fs.delete(path)) OpResult.Ok else OpResult.Error("No se pudo eliminar “${fileName(path)}”.")
    }

    /** Copia o mueve [source] dentro de [destDir]. Devuelve la nueva ruta. */
    suspend fun transfer(source: String, destDir: String, move: Boolean): Pair<OpResult, String?> =
        withContext(ioDispatcher) {
            if (!fs.exists(source)) return@withContext OpResult.Error("El origen ya no existe.") to null
            if (destDir == source || destDir.startsWith("$source/")) {
                return@withContext OpResult.Error("No se puede copiar/mover una carpeta dentro de sí misma.") to null
            }
            if (move && parentPath(source) == destDir) return@withContext OpResult.Ok to source
            val target = uniquePath(destDir, fileName(source))
            val ok = if (move) fs.move(source, target) else fs.copy(source, target)
            if (ok) OpResult.Ok to target else OpResult.Error("La operación falló.") to null
        }

    suspend fun readText(path: String): Result<String> = withContext(ioDispatcher) {
        runCatching { fs.readText(path, 1_000_000) ?: error("No se pudo leer el archivo (dañado o codificación no soportada).") }
    }

    suspend fun writeText(path: String, text: String): OpResult = withContext(ioDispatcher) {
        if (fs.writeText(path, text)) OpResult.Ok else OpResult.Error("No se pudo guardar.")
    }

    suspend fun readBytes(path: String): ByteArray? = withContext(ioDispatcher) { fs.readBytes(path) }

    private fun uniquePath(dir: String, name: String): String {
        var candidate = joinPath(dir, name)
        if (!fs.exists(candidate)) return candidate
        val base = name.substringBeforeLast('.', name)
        val ext = name.substringAfterLast('.', "")
        var i = 2
        while (fs.exists(candidate)) {
            candidate = joinPath(dir, if (ext.isEmpty() || base == name) "$base ($i)" else "$base ($i).$ext")
            i++
        }
        return candidate
    }

    /** Crea archivos de ejemplo la primera vez (para poder probar la app de inmediato). */
    suspend fun seedIfEmpty(): Unit = withContext(ioDispatcher) {
        val docs = fs.roots().firstOrNull() ?: return@withContext
        if (fs.list(docs.path).isNotEmpty()) return@withContext
        val examples = joinPath(docs.path, "Ejemplos")
        fs.createDirectory(examples)
        fs.createDirectory(joinPath(docs.path, "Proyectos"))
        fs.writeText(
            joinPath(docs.path, "Bienvenida.md"),
            "# Gestor de Archivos KMP\n\nLógica compartida en commonMain; acceso a archivos con expect/actual.\n",
        )
        fs.writeText(joinPath(examples, "config.json"), "{\n  \"escuela\": \"ESCOM\",\n  \"practica\": 3\n}\n")
        fs.writeText(joinPath(examples, "Main.kt"), "fun main() {\n    println(\"Hola, ESCOM\")\n}\n")
        fs.writeText(joinPath(examples, "nota.txt"), "Archivo de texto de ejemplo.\n")
    }
}
