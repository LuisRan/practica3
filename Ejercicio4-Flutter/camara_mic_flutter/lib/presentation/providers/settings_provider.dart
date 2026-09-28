import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_theme.dart';

/// Preferencias persistentes (tema y opciones de captura) con SharedPreferences.
class SettingsProvider extends ChangeNotifier {
  SettingsProvider(this._prefs) {
    _theme = AppThemeOption.values.firstWhere(
      (t) => t.name == _prefs.getString('theme'),
      orElse: () => AppThemeOption.guinda,
    );
    _themeMode = ThemeMode.values.firstWhere(
      (m) => m.name == _prefs.getString('themeMode'),
      orElse: () => ThemeMode.system,
    );
  }

  final SharedPreferences _prefs;
  late AppThemeOption _theme;
  late ThemeMode _themeMode;

  AppThemeOption get theme => _theme;
  ThemeMode get themeMode => _themeMode;

  set theme(AppThemeOption value) {
    _theme = value;
    _prefs.setString('theme', value.name);
    notifyListeners();
  }

  /// Por defecto `system` (adaptación automática claro/oscuro).
  set themeMode(ThemeMode value) {
    _themeMode = value;
    _prefs.setString('themeMode', value.name);
    notifyListeners();
  }
}
