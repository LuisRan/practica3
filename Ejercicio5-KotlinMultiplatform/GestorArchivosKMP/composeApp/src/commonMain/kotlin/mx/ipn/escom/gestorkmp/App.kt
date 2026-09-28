package mx.ipn.escom.gestorkmp

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.togetherWith
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Surface
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import mx.ipn.escom.gestorkmp.platform.PlatformBackHandler
import mx.ipn.escom.gestorkmp.ui.FileViewerScreen
import mx.ipn.escom.gestorkmp.ui.FolderScreen
import mx.ipn.escom.gestorkmp.ui.GestorTheme
import mx.ipn.escom.gestorkmp.ui.HomeScreen
import mx.ipn.escom.gestorkmp.ui.SettingsScreen
import mx.ipn.escom.gestorkmp.viewmodel.FileManagerViewModel
import mx.ipn.escom.gestorkmp.viewmodel.Screen

/**
 * Punto de entrada de la UI compartida (Compose Multiplatform).
 * Android lo llama desde MainActivity e iOS desde MainViewController.
 */
@Composable
fun App() {
    val vm = remember { FileManagerViewModel() }
    DisposableEffect(Unit) { onDispose { vm.dispose() } }

    val prefs by vm.prefs.collectAsState()
    val stack by vm.stack.collectAsState()
    val message by vm.messages.collectAsState()
    val snackbar = remember { SnackbarHostState() }

    LaunchedEffect(message) {
        message?.let {
            snackbar.showSnackbar(it)
            vm.consumeMessage()
        }
    }

    PlatformBackHandler(enabled = stack.size > 1) { vm.back() }

    GestorTheme(prefs.theme) {
        Surface(color = MaterialTheme.colorScheme.background) {
            Box(Modifier.fillMaxSize()) {
                AnimatedContent(
                    targetState = stack,
                    transitionSpec = {
                        val forward = targetState.size >= initialState.size
                        (slideInHorizontally { if (forward) it / 3 else -it / 3 } + fadeIn()) togetherWith
                            (slideOutHorizontally { if (forward) -it / 3 else it / 3 } + fadeOut())
                    },
                    contentKey = { it.size to it.last() },
                ) { s ->
                    when (val screen = s.last()) {
                        Screen.Home -> HomeScreen(vm)
                        is Screen.Folder -> FolderScreen(vm, screen)
                        is Screen.Viewer -> FileViewerScreen(vm, screen.path)
                        Screen.Settings -> SettingsScreen(vm)
                    }
                }
                SnackbarHost(snackbar, Modifier.align(Alignment.BottomCenter).navigationBarsPadding())
            }
        }
    }
}
