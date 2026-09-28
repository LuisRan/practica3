import 'package:flutter/material.dart';

import 'audio_page.dart';
import 'camera_page.dart';
import 'gallery_page.dart';
import 'settings_page.dart';

/// Navegación principal con NavigationBar (Material 3), consistente en Android e iOS.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // La cámara solo se construye cuando su pestaña está activa (libera el recurso).
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: switch (_index) {
          0 => const CameraPage(key: ValueKey('camera')),
          1 => const AudioPage(key: ValueKey('audio')),
          2 => const GalleryPage(key: ValueKey('gallery')),
          _ => const SettingsPage(key: ValueKey('settings')),
        },
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.photo_camera_outlined), selectedIcon: Icon(Icons.photo_camera), label: 'Cámara'),
          NavigationDestination(icon: Icon(Icons.mic_none), selectedIcon: Icon(Icons.mic), label: 'Audio'),
          NavigationDestination(icon: Icon(Icons.photo_library_outlined), selectedIcon: Icon(Icons.photo_library), label: 'Galería'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Ajustes'),
        ],
      ),
    );
  }
}
