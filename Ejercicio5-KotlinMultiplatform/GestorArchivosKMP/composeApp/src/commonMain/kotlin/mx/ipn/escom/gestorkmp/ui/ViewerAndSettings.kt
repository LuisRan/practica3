package mx.ipn.escom.gestorkmp.ui

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.gestures.detectTransformGestures
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.Save
import androidx.compose.material.icons.filled.Share
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.filled.StarBorder
import androidx.compose.material.icons.filled.RotateRight
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ListItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.RadioButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TextField
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.launch
import mx.ipn.escom.gestorkmp.data.AppThemeOption
import mx.ipn.escom.gestorkmp.data.FileEntry
import mx.ipn.escom.gestorkmp.data.FileKind
import mx.ipn.escom.gestorkmp.data.OpResult
import mx.ipn.escom.gestorkmp.data.SortOption
import mx.ipn.escom.gestorkmp.data.formatSize
import mx.ipn.escom.gestorkmp.platform.decodeImage
import mx.ipn.escom.gestorkmp.platform.formatDate
import mx.ipn.escom.gestorkmp.platform.platformName
import mx.ipn.escom.gestorkmp.platform.rememberShareFile
import mx.ipn.escom.gestorkmp.viewmodel.FileManagerViewModel

/** Visor de archivos: texto (con edición), imágenes (zoom/rotación) y metadatos para el resto. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FileViewerScreen(vm: FileManagerViewModel, path: String) {
    val prefs by vm.prefs.collectAsState()
    val share = rememberShareFile()
    val scope = rememberCoroutineScope()
    var entry by remember { mutableStateOf<FileEntry?>(null) }
    var text by remember { mutableStateOf<String?>(null) }
    var image by remember { mutableStateOf<ImageBitmap?>(null) }
    var error by remember { mutableStateOf<String?>(null) }
    var loading by remember { mutableStateOf(true) }
    var editing by remember { mutableStateOf(false) }
    var draft by remember { mutableStateOf("") }

    LaunchedEffect(path) {
        val e = vm.entry(path)
        entry = e
        when {
            e == null -> error = "El archivo ya no existe."
            e.kind.isTextual -> vm.readText(path).fold({ text = it; draft = it }, { error = it.message })
            e.kind == FileKind.IMAGE -> {
                val bytes = vm.readBytes(path)
                image = bytes?.let { decodeImage(it) }
                if (image == null) error = "Imagen dañada o formato no soportado."
            }
            else -> Unit
        }
        loading = false
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(path.substringAfterLast('/'), maxLines = 1, overflow = TextOverflow.Ellipsis) },
                navigationIcon = {
                    IconButton(onClick = { vm.back() }) { Icon(Icons.AutoMirrored.Filled.ArrowBack, "Atrás") }
                },
                actions = {
                    val fav = path in prefs.favorites
                    IconButton(onClick = { vm.toggleFavorite(path) }) {
                        Icon(if (fav) Icons.Filled.Star else Icons.Filled.StarBorder, "Favorito",
                            tint = if (fav) Color(0xFFFFB300) else MaterialTheme.colorScheme.onSurface)
                    }
                    IconButton(onClick = { share(path) }) { Icon(Icons.Filled.Share, "Compartir") }
                    if (text != null) {
                        if (editing) {
                            IconButton(onClick = {
                                scope.launch {
                                    if (vm.saveText(path, draft) is OpResult.Ok) {
                                        text = draft
                                        editing = false
                                    }
                                }
                            }) { Icon(Icons.Filled.Save, "Guardar") }
                        } else {
                            IconButton(onClick = { editing = true }) { Icon(Icons.Filled.Edit, "Editar") }
                        }
                    }
                },
            )
        },
    ) { padding ->
        Box(Modifier.fillMaxSize().padding(padding)) {
            when {
                loading -> CircularProgressIndicator(Modifier.align(Alignment.Center))
                error != null -> Column(Modifier.align(Alignment.Center).padding(32.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                    Text("No se pudo abrir", style = MaterialTheme.typography.titleMedium)
                    Text(error ?: "", color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
                text != null && editing -> TextField(
                    value = draft,
                    onValueChange = { draft = it },
                    modifier = Modifier.fillMaxSize(),
                    textStyle = MaterialTheme.typography.bodyMedium.copy(fontFamily = FontFamily.Monospace),
                )
                text != null -> SelectionContainer {
                    Text(
                        text ?: "",
                        fontFamily = FontFamily.Monospace,
                        fontSize = 13.sp,
                        modifier = Modifier
                            .fillMaxSize()
                            .verticalScroll(rememberScrollState())
                            .horizontalScroll(rememberScrollState())
                            .padding(16.dp),
                    )
                }
                image != null -> ZoomableImage(image!!)
                else -> entry?.let { InfoPanel(it) }
            }
        }
    }
}

/** Imagen con zoom (pinza), desplazamiento, rotación con dos dedos y doble toque para ajustar. */
@Composable
private fun ZoomableImage(bitmap: ImageBitmap) {
    var scale by remember { mutableFloatStateOf(1f) }
    var rotation by remember { mutableFloatStateOf(0f) }
    var offset by remember { mutableStateOf(Offset.Zero) }
    Box(Modifier.fillMaxSize().background(Color.Black)) {
        Image(
            bitmap = bitmap,
            contentDescription = "Imagen",
            contentScale = ContentScale.Fit,
            modifier = Modifier
                .fillMaxSize()
                .pointerInput(Unit) {
                    detectTransformGestures { _, pan, zoom, rot ->
                        scale = (scale * zoom).coerceIn(1f, 8f)
                        rotation += rot
                        offset = if (scale > 1f) offset + pan else Offset.Zero
                    }
                }
                .pointerInput(Unit) {
                    detectTapGestures(onDoubleTap = {
                        if (scale > 1f || rotation != 0f) {
                            scale = 1f; rotation = 0f; offset = Offset.Zero
                        } else {
                            scale = 2.5f
                        }
                    })
                }
                .graphicsLayer {
                    scaleX = scale
                    scaleY = scale
                    rotationZ = rotation
                    translationX = offset.x
                    translationY = offset.y
                },
        )
        Row(Modifier.align(Alignment.BottomCenter).padding(16.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            TextButton(onClick = { rotation += 90f }) {
                Icon(Icons.Filled.RotateRight, null, tint = Color.White)
                Text(" Rotar", color = Color.White)
            }
            TextButton(onClick = { scale = 1f; rotation = 0f; offset = Offset.Zero }) {
                Text("Ajustar a pantalla", color = Color.White)
            }
            Text("${(scale * 100).toInt()}%", color = Color.White, modifier = Modifier.align(Alignment.CenterVertically))
        }
    }
}

@Composable
private fun InfoPanel(e: FileEntry) {
    Column(Modifier.fillMaxSize().padding(24.dp), horizontalAlignment = Alignment.CenterHorizontally) {
        Spacer(Modifier.height(32.dp))
        FileIcon(e.kind, Modifier.size(72.dp))
        Spacer(Modifier.height(16.dp))
        Text(e.name, style = MaterialTheme.typography.titleMedium)
        Text("${e.kind.label} · ${formatSize(e.size)}", color = MaterialTheme.colorScheme.onSurfaceVariant)
        Text("Modificado: ${formatDate(e.modifiedMillis)}", color = MaterialTheme.colorScheme.onSurfaceVariant)
        Spacer(Modifier.height(16.dp))
        Text(
            "No hay vista previa integrada para este tipo. Usa “Compartir” para abrirlo con otra app.",
            style = MaterialTheme.typography.bodySmall,
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(vm: FileManagerViewModel) {
    val prefs by vm.prefs.collectAsState()
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Ajustes") },
                navigationIcon = { IconButton(onClick = { vm.back() }) { Icon(Icons.AutoMirrored.Filled.ArrowBack, "Atrás") } },
            )
        },
    ) { padding ->
        Column(Modifier.fillMaxSize().padding(padding).verticalScroll(rememberScrollState())) {
            SectionTitle("Tema")
            AppThemeOption.entries.forEach { t ->
                ListItem(
                    headlineContent = { Text(t.label) },
                    leadingContent = {
                        Box(
                            Modifier.size(24.dp).clip(CircleShape)
                                .background(if (t == AppThemeOption.GUINDA) Color(0xFF6F1D46) else Color(0xFF005B9F)),
                        )
                    },
                    trailingContent = { RadioButton(selected = prefs.theme == t, onClick = { vm.setTheme(t) }) },
                    modifier = Modifier.selectable(selected = prefs.theme == t, onClick = { vm.setTheme(t) }),
                )
            }
            Text(
                "El tema se adapta automáticamente al modo claro/oscuro del sistema.",
                style = MaterialTheme.typography.bodySmall,
                modifier = Modifier.padding(horizontal = 16.dp),
            )
            SectionTitle("Archivos")
            SortOption.entries.forEach { s ->
                ListItem(
                    headlineContent = { Text("Ordenar por ${s.label.lowercase()}") },
                    trailingContent = { RadioButton(selected = prefs.sort == s, onClick = { vm.setSort(s, prefs.ascending) }) },
                )
            }
            ListItem(
                headlineContent = { Text("Orden ascendente") },
                trailingContent = { Switch(checked = prefs.ascending, onCheckedChange = { vm.setSort(prefs.sort, it) }) },
            )
            ListItem(
                headlineContent = { Text("Mostrar archivos ocultos") },
                trailingContent = { Switch(checked = prefs.showHidden, onCheckedChange = { vm.setShowHidden(it) }) },
            )
            ListItem(
                headlineContent = { Text("Borrar historial de recientes") },
                trailingContent = { TextButton(onClick = { vm.clearRecents() }) { Text("Borrar") } },
            )
            SectionTitle("Acerca de")
            ListItem(headlineContent = { Text("Práctica 3 · Ejercicio 5") }, supportingContent = { Text("Kotlin Multiplatform + Compose Multiplatform") })
            ListItem(headlineContent = { Text("Plataforma") }, supportingContent = { Text(platformName()) })
            Spacer(Modifier.height(24.dp))
        }
    }
}
