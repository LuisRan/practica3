package mx.ipn.escom.gestorkmp.viewmodel

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import mx.ipn.escom.gestorkmp.data.AppThemeOption
import mx.ipn.escom.gestorkmp.data.FileEntry
import mx.ipn.escom.gestorkmp.data.FileRepository
import mx.ipn.escom.gestorkmp.data.OpResult
import mx.ipn.escom.gestorkmp.data.PreferencesRepository
import mx.ipn.escom.gestorkmp.data.RootLocation
import mx.ipn.escom.gestorkmp.data.SortOption
import mx.ipn.escom.gestorkmp.data.UserPrefs
import mx.ipn.escom.gestorkmp.data.parentPath
import mx.ipn.escom.gestorkmp.data.sortEntries

/** Pantallas de la app (pila de navegación compartida entre plataformas). */
sealed interface Screen {
    data object Home : Screen
    data class Folder(val path: String, val readOnly: Boolean = false) : Screen
    data class Viewer(val path: String) : Screen
    data object Settings : Screen
}

enum class ClipboardOp { COPY, MOVE }
data class Clipboard(val op: ClipboardOp, val path: String)

data class FolderState(
    val path: String = "",
    val entries: List<FileEntry> = emptyList(),
    val loading: Boolean = false,
    val error: String? = null,
    val query: String = "",
)

/**
 * Lógica de presentación COMPARTIDA (commonMain): Android e iOS usan exactamente
 * este ViewModel. Estado expuesto con StateFlow; operaciones en corrutinas.
 */
class FileManagerViewModel(
    private val files: FileRepository = FileRepository(),
    private val prefsRepo: PreferencesRepository = PreferencesRepository(),
) {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    val prefs: StateFlow<UserPrefs> = prefsRepo.prefs.stateIn(scope, SharingStarted.Eagerly, UserPrefs())

    private val _stack = MutableStateFlow<List<Screen>>(listOf(Screen.Home))
    val stack: StateFlow<List<Screen>> = _stack.asStateFlow()

    private val _folder = MutableStateFlow(FolderState())
    val folder: StateFlow<FolderState> = _folder.asStateFlow()

    private val _clipboard = MutableStateFlow<Clipboard?>(null)
    val clipboard: StateFlow<Clipboard?> = _clipboard.asStateFlow()

    private val _messages = MutableStateFlow<String?>(null)
    val messages: StateFlow<String?> = _messages.asStateFlow()

    val roots: List<RootLocation> = files.roots()

    init {
        scope.launch {
            files.seedIfEmpty()
            // Restaura la última carpeta visitada.
            val last = prefsRepo.prefs.first().lastFolder
            if (last != null && files.entry(last)?.isDirectory == true) {
                val root = roots.filter { last.startsWith(it.path) }.maxByOrNull { it.path.length }
                if (root != null) {
                    val chain = mutableListOf<Screen>(Screen.Home)
                    var current = root.path
                    chain += Screen.Folder(current, root.readOnly)
                    last.removePrefix(root.path).split('/').filter { it.isNotEmpty() }.forEach { part ->
                        current = "$current/$part"
                        chain += Screen.Folder(current, root.readOnly)
                    }
                    _stack.value = chain
                    loadFolder(last)
                }
            }
        }
    }

    // ---- Navegación ----

    val current: Screen get() = _stack.value.last()

    fun open(screen: Screen) {
        _stack.update { it + screen }
        when (screen) {
            is Screen.Folder -> loadFolder(screen.path)
            is Screen.Viewer -> scope.launch { prefsRepo.addRecent(screen.path) }
            else -> Unit
        }
    }

    fun openEntry(entry: FileEntry, readOnly: Boolean) {
        if (entry.isDirectory) open(Screen.Folder(entry.path, readOnly)) else open(Screen.Viewer(entry.path))
    }

    /** Abre una ruta guardada (favorito/reciente) detectando si es carpeta o archivo. */
    fun openPath(path: String) = scope.launch {
        val e = files.entry(path)
        if (e == null) {
            _messages.value = "“${path.substringAfterLast('/')}” ya no existe."
        } else if (e.isDirectory) {
            open(Screen.Folder(path))
        } else {
            open(Screen.Viewer(path))
        }
    }

    fun back(): Boolean {
        if (_stack.value.size <= 1) return false
        _stack.update { it.dropLast(1) }
        (current as? Screen.Folder)?.let { loadFolder(it.path) }
        return true
    }

    // ---- Carpeta actual ----

    fun loadFolder(path: String = _folder.value.path) {
        if (path.isEmpty()) return
        _folder.update { it.copy(path = path, loading = true, error = null, query = if (it.path == path) it.query else "") }
        scope.launch {
            prefsRepo.setLastFolder(path)
            val result = files.list(path, prefs.value.showHidden)
            _folder.update { st ->
                result.fold(
                    onSuccess = { st.copy(entries = it, loading = false) },
                    onFailure = { st.copy(entries = emptyList(), loading = false, error = it.message ?: "Error de lectura") },
                )
            }
        }
    }

    fun setQuery(q: String) = _folder.update { it.copy(query = q) }

    /** Entradas filtradas por búsqueda y ordenadas según las preferencias. */
    fun visibleEntries(state: FolderState, p: UserPrefs): List<FileEntry> =
        state.entries
            .filter { state.query.isBlank() || it.name.contains(state.query, ignoreCase = true) }
            .sortEntries(p.sort, p.ascending)

    fun createFolder(name: String) = runOp { files.createFolder(_folder.value.path, name) }
    fun createTextFile(name: String) = runOp { files.createTextFile(_folder.value.path, name) }

    fun rename(entry: FileEntry, newName: String) = scope.launch {
        val (result, newPath) = files.rename(entry.path, newName)
        if (newPath != null && newPath != entry.path) prefsRepo.pathChanged(entry.path, newPath)
        report(result)
        loadFolder()
    }

    fun delete(entry: FileEntry) = scope.launch {
        val result = files.delete(entry.path)
        if (result is OpResult.Ok) prefsRepo.pathChanged(entry.path, null)
        report(result, ok = "“${entry.name}” eliminado")
        loadFolder()
    }

    fun duplicate(entry: FileEntry) = scope.launch {
        report(files.transfer(entry.path, parentPath(entry.path), move = false).first, ok = "Duplicado")
        loadFolder()
    }

    fun setClipboard(op: ClipboardOp, entry: FileEntry) {
        _clipboard.value = Clipboard(op, entry.path)
    }

    fun clearClipboard() {
        _clipboard.value = null
    }

    fun paste() = scope.launch {
        val clip = _clipboard.value ?: return@launch
        val (result, newPath) = files.transfer(clip.path, _folder.value.path, move = clip.op == ClipboardOp.MOVE)
        if (clip.op == ClipboardOp.MOVE && newPath != null) prefsRepo.pathChanged(clip.path, newPath)
        report(result, ok = if (clip.op == ClipboardOp.MOVE) "Movido" else "Copiado")
        _clipboard.value = null
        loadFolder()
    }

    fun toggleFavorite(path: String) = scope.launch { prefsRepo.toggleFavorite(path) }

    // ---- Visor ----

    suspend fun readText(path: String) = files.readText(path)
    suspend fun saveText(path: String, text: String) = files.writeText(path, text).also { report(it, ok = "Guardado") }
    suspend fun readBytes(path: String) = files.readBytes(path)
    suspend fun entry(path: String) = files.entry(path)

    // ---- Preferencias ----

    fun setTheme(t: AppThemeOption) = scope.launch { prefsRepo.setTheme(t) }
    fun setSort(s: SortOption, ascending: Boolean) = scope.launch { prefsRepo.setSort(s, ascending) }
    fun setShowHidden(v: Boolean) = scope.launch {
        prefsRepo.setShowHidden(v)
        loadFolder()
    }
    fun clearRecents() = scope.launch { prefsRepo.clearRecents() }

    fun consumeMessage() {
        _messages.value = null
    }

    fun showMessage(msg: String) {
        _messages.value = msg
    }

    private fun runOp(block: suspend () -> OpResult) = scope.launch {
        report(block())
        loadFolder()
    }

    private fun report(result: OpResult, ok: String? = null) {
        if (result is OpResult.Error) {
            _messages.value = result.message
        } else if (ok != null) {
            _messages.value = ok
        }
    }

    fun dispose() = scope.cancel()
}
