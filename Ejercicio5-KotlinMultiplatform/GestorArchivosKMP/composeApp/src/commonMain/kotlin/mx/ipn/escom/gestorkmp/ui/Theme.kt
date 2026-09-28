package mx.ipn.escom.gestorkmp.ui

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import mx.ipn.escom.gestorkmp.data.AppThemeOption

// Paleta Guinda (IPN)
private val GuindaLight = lightColorScheme(
    primary = Color(0xFF6F1D46),
    onPrimary = Color.White,
    primaryContainer = Color(0xFFFFD9E4),
    onPrimaryContainer = Color(0xFF3B0620),
    secondary = Color(0xFF8E4A66),
    secondaryContainer = Color(0xFFF4E4EC),
    tertiary = Color(0xFFB08D57),
    surface = Color(0xFFFFF8F9),
)
private val GuindaDark = darkColorScheme(
    primary = Color(0xFFFFB0CB),
    onPrimary = Color(0xFF5A0F34),
    primaryContainer = Color(0xFF6F1D46),
    onPrimaryContainer = Color(0xFFFFD9E4),
    secondary = Color(0xFFE2BDCB),
    secondaryContainer = Color(0xFF3A1426),
    tertiary = Color(0xFFE3C28A),
)

// Paleta Azul (ESCOM)
private val AzulLight = lightColorScheme(
    primary = Color(0xFF005B9F),
    onPrimary = Color.White,
    primaryContainer = Color(0xFFD3E4FF),
    onPrimaryContainer = Color(0xFF001C38),
    secondary = Color(0xFF3F6A8F),
    secondaryContainer = Color(0xFFE1EEF9),
    tertiary = Color(0xFF00897B),
    surface = Color(0xFFF8FAFF),
)
private val AzulDark = darkColorScheme(
    primary = Color(0xFFA2C9FF),
    onPrimary = Color(0xFF00315B),
    primaryContainer = Color(0xFF005B9F),
    onPrimaryContainer = Color(0xFFD3E4FF),
    secondary = Color(0xFFB9C8DA),
    secondaryContainer = Color(0xFF0F2A42),
    tertiary = Color(0xFF80CBC4),
)

/** Tema Material 3 que se adapta al modo claro/oscuro del sistema en ambas plataformas. */
@Composable
fun GestorTheme(option: AppThemeOption, content: @Composable () -> Unit) {
    val dark = isSystemInDarkTheme()
    val scheme = when (option) {
        AppThemeOption.GUINDA -> if (dark) GuindaDark else GuindaLight
        AppThemeOption.AZUL -> if (dark) AzulDark else AzulLight
    }
    MaterialTheme(colorScheme = scheme, content = content)
}
