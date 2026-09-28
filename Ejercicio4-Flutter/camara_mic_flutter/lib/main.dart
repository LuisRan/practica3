// Práctica 3 · Ejercicio 4 — Cámara y Micrófono multiplataforma con Flutter.
// Desarrollo de aplicaciones móviles nativas · ESCOM-IPN.
//
// Arquitectura (Clean Architecture):
//   presentation/  -> widgets + providers (estado con Provider/ChangeNotifier)
//   domain/        -> entidades, contrato del repositorio y casos de uso
//   data/          -> SQLite (sqflite) + sistema de archivos (path_provider)
//   services/      -> procesamiento de imágenes y permisos

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/theme/app_theme.dart';
import 'data/datasources/file_storage.dart';
import 'data/datasources/media_local_datasource.dart';
import 'data/repositories/media_repository_impl.dart';
import 'domain/usecases/media_usecases.dart';
import 'presentation/pages/home_page.dart';
import 'presentation/providers/gallery_provider.dart';
import 'presentation/providers/recorder_provider.dart';
import 'presentation/providers/settings_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inyección de dependencias manual (composición en el punto de entrada).
  final prefs = await SharedPreferences.getInstance();
  final files = FileStorage();
  await files.init();
  final repository = MediaRepositoryImpl(MediaLocalDataSource(), files);
  final useCases = MediaUseCases(repository);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider(prefs)),
        ChangeNotifierProvider(create: (_) => GalleryProvider(useCases)),
        ChangeNotifierProvider(create: (_) => RecorderProvider()),
      ],
      child: const CamaraMicApp(),
    ),
  );
}

class CamaraMicApp extends StatelessWidget {
  const CamaraMicApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    return MaterialApp(
      title: 'Cámara y Micrófono',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(settings.theme),
      darkTheme: AppTheme.dark(settings.theme),
      themeMode: settings.themeMode,
      home: const HomePage(),
    );
  }
}
