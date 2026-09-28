package mx.ipn.escom.gestorkmp

import androidx.compose.ui.window.ComposeUIViewController

/** Punto de entrada para iOS: SwiftUI (iosApp) incrusta este UIViewController. */
fun MainViewController() = ComposeUIViewController { App() }
