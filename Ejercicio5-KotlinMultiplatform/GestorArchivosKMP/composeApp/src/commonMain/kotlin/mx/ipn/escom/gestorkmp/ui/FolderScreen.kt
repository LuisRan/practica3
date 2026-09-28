package mx.ipn.escom.gestorkmp.ui

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.Sort
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.ContentCopy
import androidx.compose.material.icons.filled.CreateNewFolder
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.DriveFileMove
import androidx.compose.material.icons.filled.DriveFileRenameOutline
import androidx.compose.material.icons.filled.FileCopy
import androidx.compose.material.icons.filled.NoteAdd
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Share
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.filled.StarBorder
import androidx.compose.material.icons.filled.Check
import androidx.compose.material3.Button
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ListItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.SwipeToDismissBox
import androidx.compose.material3.SwipeToDismissBoxValue
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.material3.rememberSwipeToDismissBoxState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import mx.ipn.escom.gestorkmp.data.FileEntry
import mx.ipn.escom.gestorkmp.data.SortOption
import mx.ipn.escom.gestorkmp.data.formatSize
import mx.ipn.escom.gestorkmp.platform.formatDate
import mx.ipn.escom.gestorkmp.platform.rememberShareFile
import mx.ipn.escom.gestorkmp.viewmodel.ClipboardOp
import mx.ipn.escom.gestorkmp.viewmodel.FileManagerViewModel
import mx.ipn.escom.gestorkmp.viewmodel.Screen

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FolderScreen(vm: FileManagerViewModel, screen: Screen.Folder) {
    val state by vm.folder.collectAsState()
    val prefs by vm.prefs.collectAsState()
    val clipboard by vm.clipboard.collectAsState()
    val share = rememberShareFile()
    val entries = vm.visibleEntries(state, prefs)

    var showSearch by remember { mutableStateOf(false) }
    var showSortMenu by remember { mutableStateOf(false) }
    var showAddMenu by remember { mutableStateOf(false) }
    var newFolderDialog by remember { mutableStateOf(false) }
    var newFileDialog by remember { mutableStateOf(false) }
    var renameTarget by remember { mutableStateOf<FileEntry?>(null) }
    var deleteTarget by remember { mutableStateOf<FileEntry?>(null) }

    Scaffold(
        topBar = {
            Column {
                TopAppBar(
                    title = { Text(screen.path.trimEnd('/').substringAfterLast('/'), maxLines = 1, overflow = TextOverflow.Ellipsis) },
                    navigationIcon = {
                        IconButton(onClick = { vm.back() }) {
                            Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Atrás")
                        }
                    },
                    actions = {
                        IconButton(onClick = { showSearch = !showSearch; if (!showSearch) vm.setQuery("") }) {
                            Icon(Icons.Filled.Search, contentDescription = "Buscar")
                        }
                        Box {
                            IconButton(onClick = { showSortMenu = true }) {
                                Icon(Icons.AutoMirrored.Filled.Sort, contentDescription = "Ordenar")
                            }
                            DropdownMenu(expanded = showSortMenu, onDismissRequest = { showSortMenu = false }) {
                                SortOption.entries.forEach { opt ->
                                    DropdownMenuItem(
                                        text = { Text(opt.label) },
                                        leadingIcon = { if (prefs.sort == opt) Icon(Icons.Filled.Check, null) },
                                        onClick = { vm.setSort(opt, prefs.ascending); showSortMenu = false },
                                    )
                                }
                                HorizontalDivider()
                                DropdownMenuItem(
                                    text = { Text(if (prefs.ascending) "Ascendente ✓" else "Descendente ✓") },
                                    onClick = { vm.setSort(prefs.sort, !prefs.ascending); showSortMenu = false },
                                )
                            }
                        }
                        if (!screen.readOnly) {
                            Box {
                                IconButton(onClick = { showAddMenu = true }) {
                                    Icon(Icons.Filled.Add, contentDescription = "Agregar")
                                }
                                DropdownMenu(expanded = showAddMenu, onDismissRequest = { showAddMenu = false }) {
                                    DropdownMenuItem(
                                        text = { Text("Nueva carpeta") },
                                        leadingIcon = { Icon(Icons.Filled.CreateNewFolder, null) },
                                        onClick = { newFolderDialog = true; showAddMenu = false },
                                    )
                                    DropdownMenuItem(
                                        text = { Text("Nuevo archivo de texto") },
                                        leadingIcon = { Icon(Icons.Filled.NoteAdd, null) },
                                        onClick = { newFileDialog = true; showAddMenu = false },
                                    )
                                }
                            }
                        }
                    },
                )
                PathBar(screen.path)
                if (showSearch) {
                    OutlinedTextField(
                        value = state.query,
                        onValueChange = vm::setQuery,
                        placeholder = { Text("Buscar en esta carpeta") },
                        singleLine = true,
                        leadingIcon = { Icon(Icons.Filled.Search, null) },
                        modifier = Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 4.dp),
                    )
                }
            }
        },
        bottomBar = {
            AnimatedVisibility(
                visible = clipboard != null && !screen.readOnly,
                enter = slideInVertically { it },
                exit = slideOutVertically { it },
            ) {
                Surface(tonalElevation = 6.dp) {
                    Row(
                        Modifier.fillMaxWidth().navigationBarsPadding().padding(12.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        val c = clipboard
                        Text(
                            if (c == null) "" else "${if (c.op == ClipboardOp.MOVE) "Mover" else "Copiar"}: ${c.path.substringAfterLast('/')}",
                            modifier = Modifier.weight(1f),
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                        )
                        OutlinedButton(onClick = { vm.clearClipboard() }) { Text("Cancelar") }
                        Spacer(Modifier.width(8.dp))
                        Button(onClick = { vm.paste() }) { Text("Pegar aquí") }
                    }
                }
            }
        },
    ) { padding ->
        // Deslizar hacia abajo para actualizar
        PullToRefreshBox(
            isRefreshing = state.loading,
            onRefresh = { vm.loadFolder(screen.path) },
            modifier = Modifier.fillMaxSize().padding(padding),
        ) {
            when {
                state.error != null -> Message("No se puede leer la carpeta", state.error ?: "")
                !state.loading && entries.isEmpty() -> Message(
                    if (state.query.isBlank()) "Carpeta vacía" else "Sin resultados",
                    if (state.query.isBlank()) "Usa + para crear una carpeta o un archivo." else "Nada coincide con “${state.query}”.",
                )
                else -> LazyColumn(Modifier.fillMaxSize()) {
                    item {
                        Text(
                            "${entries.size} elementos · ${prefs.sort.label.lowercase()}",
                            style = MaterialTheme.typography.labelMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            modifier = Modifier.padding(horizontal = 16.dp, vertical = 6.dp),
                        )
                    }
                    items(entries, key = { it.path }) { entry ->
                        FileRow(
                            entry = entry,
                            readOnly = screen.readOnly,
                            isFavorite = entry.path in prefs.favorites,
                            onOpen = { vm.openEntry(entry, screen.readOnly) },
                            onDelete = { deleteTarget = entry },
                            onRename = { renameTarget = entry },
                            onCopy = { vm.setClipboard(ClipboardOp.COPY, entry) },
                            onMove = { vm.setClipboard(ClipboardOp.MOVE, entry) },
                            onDuplicate = { vm.duplicate(entry) },
                            onFavorite = { vm.toggleFavorite(entry.path) },
                            onShare = { share(entry.path) },
                        )
                    }
                }
            }
        }
    }

    if (newFolderDialog) {
        NameDialog("Nueva carpeta", confirmLabel = "Crear", onDismiss = { newFolderDialog = false }) { vm.createFolder(it) }
    }
    if (newFileDialog) {
        NameDialog("Nuevo archivo", initial = "nota.txt", confirmLabel = "Crear", onDismiss = { newFileDialog = false }) {
            vm.createTextFile(it)
        }
    }
    renameTarget?.let { target ->
        NameDialog("Renombrar", initial = target.name, confirmLabel = "Renombrar", onDismiss = { renameTarget = null }) {
            vm.rename(target, it)
        }
    }
    deleteTarget?.let { target ->
        ConfirmDialog(
            title = "¿Eliminar “${target.name}”?",
            text = if (target.isDirectory) "Se eliminará la carpeta y todo su contenido. No se puede deshacer."
            else "Esta acción no se puede deshacer.",
            confirmLabel = "Eliminar",
            onDismiss = { deleteTarget = null },
        ) { vm.delete(target) }
    }
}

@OptIn(ExperimentalMaterial3Api::class, ExperimentalFoundationApi::class)
@Composable
private fun FileRow(
    entry: FileEntry,
    readOnly: Boolean,
    isFavorite: Boolean,
    onOpen: () -> Unit,
    onDelete: () -> Unit,
    onRename: () -> Unit,
    onCopy: () -> Unit,
    onMove: () -> Unit,
    onDuplicate: () -> Unit,
    onFavorite: () -> Unit,
    onShare: () -> Unit,
) {
    var menu by remember { mutableStateOf(false) }
    // Deslizar a la izquierda para eliminar (pide confirmación, no borra directo).
    val dismissState = rememberSwipeToDismissBoxState(
        confirmValueChange = { value ->
            if (value == SwipeToDismissBoxValue.EndToStart && !readOnly) onDelete()
            false
        },
    )
    SwipeToDismissBox(
        state = dismissState,
        enableDismissFromStartToEnd = false,
        enableDismissFromEndToStart = !readOnly,
        backgroundContent = {
            Box(
                Modifier.fillMaxSize().background(MaterialTheme.colorScheme.errorContainer).padding(end = 24.dp),
                contentAlignment = Alignment.CenterEnd,
            ) {
                Icon(Icons.Filled.Delete, contentDescription = "Eliminar", tint = MaterialTheme.colorScheme.onErrorContainer)
            }
        },
    ) {
        Box {
            ListItem(
                headlineContent = {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(entry.name, maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f, fill = false))
                        if (isFavorite) Icon(Icons.Filled.Star, "Favorito", tint = Color(0xFFFFB300), modifier = Modifier.padding(start = 4.dp))
                    }
                },
                supportingContent = {
                    Text(
                        buildString {
                            append(formatDate(entry.modifiedMillis))
                            append(" · ")
                            append(if (entry.isDirectory) "${entry.childCount ?: 0} elementos" else formatSize(entry.size))
                        },
                        maxLines = 1,
                    )
                },
                leadingContent = { FileIcon(entry.kind) },
                trailingContent = { if (entry.isDirectory) Icon(Icons.Filled.ChevronRight, null) },
                // Mantener presionado abre el menú contextual.
                modifier = Modifier.combinedClickable(onClick = onOpen, onLongClick = { menu = true }),
            )
            DropdownMenu(expanded = menu, onDismissRequest = { menu = false }) {
                DropdownMenuItem(text = { Text("Compartir / Exportar") }, leadingIcon = { Icon(Icons.Filled.Share, null) },
                    enabled = !entry.isDirectory, onClick = { menu = false; onShare() })
                DropdownMenuItem(
                    text = { Text(if (isFavorite) "Quitar de favoritos" else "Agregar a favoritos") },
                    leadingIcon = { Icon(if (isFavorite) Icons.Filled.StarBorder else Icons.Filled.Star, null) },
                    onClick = { menu = false; onFavorite() },
                )
                if (!readOnly) {
                    HorizontalDivider()
                    DropdownMenuItem(text = { Text("Renombrar") }, leadingIcon = { Icon(Icons.Filled.DriveFileRenameOutline, null) },
                        onClick = { menu = false; onRename() })
                    DropdownMenuItem(text = { Text("Duplicar") }, leadingIcon = { Icon(Icons.Filled.FileCopy, null) },
                        onClick = { menu = false; onDuplicate() })
                    DropdownMenuItem(text = { Text("Copiar…") }, leadingIcon = { Icon(Icons.Filled.ContentCopy, null) },
                        onClick = { menu = false; onCopy() })
                    DropdownMenuItem(text = { Text("Mover…") }, leadingIcon = { Icon(Icons.Filled.DriveFileMove, null) },
                        onClick = { menu = false; onMove() })
                    HorizontalDivider()
                    DropdownMenuItem(
                        text = { Text("Eliminar", color = MaterialTheme.colorScheme.error) },
                        leadingIcon = { Icon(Icons.Filled.Delete, null, tint = MaterialTheme.colorScheme.error) },
                        onClick = { menu = false; onDelete() },
                    )
                }
            }
        }
    }
}

/** Ruta actual siempre visible (breadcrumb). */
@Composable
private fun PathBar(path: String) {
    val parts = path.split('/').filter { it.isNotEmpty() }
    Row(
        Modifier
            .fillMaxWidth()
            .background(MaterialTheme.colorScheme.surfaceVariant)
            .horizontalScroll(rememberScrollState())
            .padding(horizontal = 12.dp, vertical = 6.dp),
        horizontalArrangement = Arrangement.spacedBy(2.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        parts.takeLast(5).forEachIndexed { i, part ->
            if (i > 0 || parts.size > 5) Text("›", color = MaterialTheme.colorScheme.onSurfaceVariant)
            val last = i == parts.takeLast(5).lastIndex
            Text(
                part,
                style = MaterialTheme.typography.labelMedium,
                fontWeight = if (last) FontWeight.Bold else FontWeight.Normal,
                color = if (last) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

@Composable
private fun Message(title: String, text: String) {
    // LazyColumn para que el gesto de "deslizar para actualizar" funcione aun sin contenido.
    LazyColumn(Modifier.fillMaxSize(), horizontalAlignment = Alignment.CenterHorizontally) {
        item {
            Column(Modifier.padding(top = 96.dp, start = 32.dp, end = 32.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                Text(title, style = MaterialTheme.typography.titleMedium)
                Text(text, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
    }
}
