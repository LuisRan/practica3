import 'package:flutter/material.dart';

/// Temas personalizables de la práctica: Guinda (IPN) y Azul (ESCOM).
/// Cada tema genera un esquema Material 3 claro y otro oscuro, y la app
/// usa `ThemeMode.system` para adaptarse automáticamente al sistema.
enum AppThemeOption {
  guinda('Guinda IPN', Color(0xFF6F1D46)),
  azul('Azul ESCOM', Color(0xFF005B9F));

  const AppThemeOption(this.label, this.seed);
  final String label;
  final Color seed;
}

class AppTheme {
  static ThemeData light(AppThemeOption option) => _build(option, Brightness.light);
  static ThemeData dark(AppThemeOption option) => _build(option, Brightness.dark);

  static ThemeData _build(AppThemeOption option, Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: option.seed,
      brightness: brightness,
    ).copyWith(
      // En modo claro se usa el color institucional exacto como primario.
      primary: brightness == Brightness.light ? option.seed : null,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: brightness == Brightness.light ? option.seed : scheme.surface,
        foregroundColor: brightness == Brightness.light ? Colors.white : scheme.onSurface,
      ),
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: scheme.primaryContainer,
      ),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: ZoomPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      }),
    );
  }
}
