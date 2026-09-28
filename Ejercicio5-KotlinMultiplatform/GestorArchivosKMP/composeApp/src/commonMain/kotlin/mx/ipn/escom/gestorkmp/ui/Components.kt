package mx.ipn.escom.gestorkmp.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.InsertDriveFile
import androidx.compose.material.icons.filled.AudioFile
import androidx.compose.material.icons.filled.Code
import androidx.compose.material.icons.filled.Description
import androidx.compose.material.icons.filled.Folder
import androidx.compose.material.icons.filled.FolderZip
import androidx.compose.material.icons.filled.Image
import androidx.compose.material.icons.filled.PictureAsPdf
import androidx.compose.material.icons.filled.VideoFile
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.unit.dp
import mx.ipn.escom.gestorkmp.data.FileKind

fun FileKind.icon(): ImageVector = when (this) {
    FileKind.FOLDER -> Icons.Filled.Folder
    FileKind.TEXT -> Icons.Filled.Description
    FileKind.CODE -> Icons.Filled.Code
    FileKind.IMAGE -> Icons.Filled.Image
    FileKind.PDF -> Icons.Filled.PictureAsPdf
    FileKind.AUDIO -> Icons.Filled.AudioFile
    FileKind.VIDEO -> Icons.Filled.VideoFile
    FileKind.ARCHIVE -> Icons.Filled.FolderZip
    FileKind.OTHER -> Icons.AutoMirrored.Filled.InsertDriveFile
}

@Composable
fun FileKind.tint(): Color = when (this) {
    FileKind.FOLDER -> MaterialTheme.colorScheme.primary
    FileKind.CODE -> Color(0xFFEF6C00)
    FileKind.IMAGE -> Color(0xFF2E7D32)
    FileKind.PDF -> Color(0xFFC62828)
    FileKind.AUDIO -> Color(0xFFAD1457)
    FileKind.VIDEO -> Color(0xFF6A1B9A)
    FileKind.ARCHIVE -> Color(0xFF6D4C41)
    else -> MaterialTheme.colorScheme.onSurfaceVariant
}

/** Ícono de archivo según su tipo, dentro de un contenedor redondeado. */
@Composable
fun FileIcon(kind: FileKind, modifier: Modifier = Modifier) {
    Box(
        modifier
            .size(44.dp)
            .background(
                if (kind == FileKind.FOLDER) MaterialTheme.colorScheme.secondaryContainer
                else MaterialTheme.colorScheme.surfaceVariant,
                RoundedCornerShape(12.dp),
            ),
        contentAlignment = Alignment.Center,
    ) {
        Icon(kind.icon(), contentDescription = kind.label, tint = kind.tint())
    }
}

/** Diálogo con un campo de texto (crear carpeta, renombrar...). */
@Composable
fun NameDialog(
    title: String,
    initial: String = "",
    confirmLabel: String = "Aceptar",
    onDismiss: () -> Unit,
    onConfirm: (String) -> Unit,
) {
    var text by remember { mutableStateOf(initial) }
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(title) },
        text = {
            OutlinedTextField(value = text, onValueChange = { text = it }, singleLine = true, label = { Text("Nombre") })
        },
        confirmButton = {
            TextButton(onClick = { onConfirm(text); onDismiss() }, enabled = text.isNotBlank()) { Text(confirmLabel) }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text("Cancelar") } },
    )
}

@Composable
fun ConfirmDialog(title: String, text: String, confirmLabel: String, onDismiss: () -> Unit, onConfirm: () -> Unit) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(title) },
        text = { Text(text) },
        confirmButton = {
            TextButton(onClick = { onConfirm(); onDismiss() }) {
                Text(confirmLabel, color = MaterialTheme.colorScheme.error)
            }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text("Cancelar") } },
    )
}
