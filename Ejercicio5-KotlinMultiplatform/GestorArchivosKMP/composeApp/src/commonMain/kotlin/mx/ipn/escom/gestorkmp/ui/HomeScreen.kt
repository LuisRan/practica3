package mx.ipn.escom.gestorkmp.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Cached
import androidx.compose.material.icons.filled.Folder
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.PhotoLibrary
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.SdStorage
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.filled.History
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ListItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.foundation.clickable
import mx.ipn.escom.gestorkmp.data.RootLocation
import mx.ipn.escom.gestorkmp.data.fileName
import mx.ipn.escom.gestorkmp.platform.hasStoragePermission
import mx.ipn.escom.gestorkmp.platform.platformName
import mx.ipn.escom.gestorkmp.platform.rememberStoragePermissionRequester
import mx.ipn.escom.gestorkmp.viewmodel.FileManagerViewModel
import mx.ipn.escom.gestorkmp.viewmodel.Screen

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HomeScreen(vm: FileManagerViewModel) {
    val prefs by vm.prefs.collectAsState()
    var permissionGranted by remember { mutableStateOf(hasStoragePermission()) }
    var pendingRoot by remember { mutableStateOf<RootLocation?>(null) }
    val requestPermission = rememberStoragePermissionRequester { granted ->
        permissionGranted = granted
        val root = pendingRoot
        pendingRoot = null
        if (granted && root != null) vm.open(Screen.Folder(root.path, root.readOnly))
        else if (!granted) vm.showMessage("Permiso denegado: no se puede abrir el almacenamiento compartido.")
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Gestor de Archivos") },
                actions = {
                    IconButton(onClick = { vm.open(Screen.Settings) }) {
                        Icon(Icons.Filled.Settings, contentDescription = "Ajustes")
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.primaryContainer,
                ),
            )
        },
    ) { padding ->
        LazyColumn(Modifier.padding(padding)) {
            item {
                Column(
                    Modifier
                        .fillMaxWidth()
                        .padding(16.dp)
                        .background(
                            Brush.linearGradient(
                                listOf(MaterialTheme.colorScheme.primary, MaterialTheme.colorScheme.tertiary),
                            ),
                            RoundedCornerShape(20.dp),
                        )
                        .padding(20.dp),
                ) {
                    Text("Kotlin Multiplatform", color = Color.White, fontWeight = FontWeight.Bold,
                        style = MaterialTheme.typography.titleLarge)
                    Text("Tema ${prefs.theme.label} · ${platformName()}", color = Color.White.copy(alpha = 0.9f))
                }
            }
            item { SectionTitle("Ubicaciones") }
            items(vm.roots, key = { it.id }) { root ->
                ListItem(
                    headlineContent = { Text(root.title) },
                    supportingContent = {
                        Text(
                            if (root.requiresPermission && !permissionGranted) "Requiere permiso de almacenamiento"
                            else root.path,
                            maxLines = 1, overflow = TextOverflow.Ellipsis,
                        )
                    },
                    leadingContent = {
                        Icon(
                            when (root.id) {
                                "cache", "tmp" -> Icons.Filled.Cached
                                "external" -> Icons.Filled.SdStorage
                                "pictures" -> Icons.Filled.PhotoLibrary
                                else -> Icons.Filled.Folder
                            },
                            contentDescription = null,
                            tint = MaterialTheme.colorScheme.primary,
                        )
                    },
                    trailingContent = {
                        if (root.requiresPermission && !permissionGranted) Icon(Icons.Filled.Lock, contentDescription = "Bloqueado")
                    },
                    modifier = Modifier.clickable {
                        if (root.requiresPermission && !hasStoragePermission()) {
                            pendingRoot = root
                            requestPermission()
                        } else {
                            vm.open(Screen.Folder(root.path, root.readOnly))
                        }
                    },
                )
            }
            if (prefs.favorites.isNotEmpty()) {
                item { SectionTitle("Favoritos") }
                items(prefs.favorites, key = { "fav-$it" }) { path ->
                    ListItem(
                        headlineContent = { Text(fileName(path), maxLines = 1, overflow = TextOverflow.Ellipsis) },
                        supportingContent = { Text(path, maxLines = 1, overflow = TextOverflow.Ellipsis) },
                        leadingContent = { Icon(Icons.Filled.Star, contentDescription = null, tint = Color(0xFFFFB300)) },
                        modifier = Modifier.clickable { vm.openPath(path) },
                    )
                }
            }
            if (prefs.recents.isNotEmpty()) {
                item {
                    Row(Modifier.fillMaxWidth().padding(end = 8.dp), horizontalArrangement = Arrangement.SpaceBetween) {
                        SectionTitle("Recientes")
                        TextButton(onClick = { vm.clearRecents() }) { Text("Borrar") }
                    }
                }
                items(prefs.recents.take(10), key = { "rec-$it" }) { path ->
                    ListItem(
                        headlineContent = { Text(fileName(path), maxLines = 1, overflow = TextOverflow.Ellipsis) },
                        supportingContent = { Text(path, maxLines = 1, overflow = TextOverflow.Ellipsis) },
                        leadingContent = { Icon(Icons.Filled.History, contentDescription = null) },
                        modifier = Modifier.clickable { vm.openPath(path) },
                    )
                }
            }
            item { HorizontalDivider(Modifier.padding(top = 8.dp)) }
        }
    }
}

@Composable
fun SectionTitle(text: String) {
    Text(
        text,
        style = MaterialTheme.typography.titleSmall,
        color = MaterialTheme.colorScheme.primary,
        modifier = Modifier.padding(start = 16.dp, top = 16.dp, bottom = 4.dp),
    )
}
