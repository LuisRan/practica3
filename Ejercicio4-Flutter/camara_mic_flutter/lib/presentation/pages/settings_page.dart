import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../domain/entities/media_item.dart';
import '../providers/gallery_provider.dart';
import '../providers/settings_provider.dart';

/// Ajustes: tema (Guinda/Azul + modo claro/oscuro/sistema), álbumes,
/// almacenamiento local y permisos.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final gallery = context.watch<GalleryProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(children: [
        const _Header('Tema'),
        for (final t in AppThemeOption.values)
          RadioListTile<AppThemeOption>(
            value: t,
            groupValue: settings.theme,
            onChanged: (v) => settings.theme = v!,
            title: Text(t.label),
            secondary: CircleAvatar(backgroundColor: t.seed, radius: 12),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(value: ThemeMode.system, label: Text('Sistema'), icon: Icon(Icons.brightness_auto)),
              ButtonSegment(value: ThemeMode.light, label: Text('Claro'), icon: Icon(Icons.light_mode)),
              ButtonSegment(value: ThemeMode.dark, label: Text('Oscuro'), icon: Icon(Icons.dark_mode)),
            ],
            selected: {settings.themeMode},
            onSelectionChanged: (s) => settings.themeMode = s.first,
          ),
        ),
        const _Header('Álbumes'),
        for (final a in gallery.albums) _AlbumTile(album: a, count: gallery.albumCounts[a.id] ?? 0),
        ListTile(
          leading: const Icon(Icons.create_new_folder_outlined),
          title: const Text('Nuevo álbum'),
          onTap: () async {
            final name = await _askName(context, 'Nuevo álbum', '');
            if (name != null) await gallery.createAlbum(name);
          },
        ),
        const _Header('Almacenamiento local'),
        ListTile(
          leading: const Icon(Icons.photo),
          title: const Text('Fotos'),
          trailing: Text('${gallery.allItems.where((m) => m.isPhoto).length}'),
        ),
        ListTile(
          leading: const Icon(Icons.graphic_eq),
          title: const Text('Grabaciones'),
          trailing: Text('${gallery.allItems.where((m) => m.type == MediaType.audio).length}'),
        ),
        FutureBuilder<int>(
          future: gallery.useCases.repository.storageUsage(),
          builder: (_, s) => ListTile(
            leading: const Icon(Icons.sd_storage_outlined),
            title: const Text('Espacio usado'),
            trailing: Text(s.hasData ? formatBytes(s.data!) : '…'),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.cleaning_services_outlined),
          title: const Text('Vaciar caché de miniaturas'),
          onTap: () async {
            await gallery.useCases.repository.clearThumbnails();
            await gallery.refresh();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Caché vaciada')));
            }
          },
        ),
        const _Header('Permisos'),
        const ListTile(
          leading: Icon(Icons.info_outline),
          title: Text('Cámara y micrófono se solicitan en tiempo de ejecución.'),
          subtitle: Text('Android: CAMERA, RECORD_AUDIO · iOS: NSCameraUsageDescription, NSMicrophoneUsageDescription'),
        ),
        ListTile(
          leading: const Icon(Icons.settings_applications_outlined),
          title: const Text('Abrir ajustes del sistema'),
          onTap: openAppSettings,
        ),
        const _Header('Acerca de'),
        const ListTile(title: Text('Práctica 3 · Ejercicio 4'), subtitle: Text('Flutter · ESCOM-IPN')),
      ]),
    );
  }
}

class _AlbumTile extends StatelessWidget {
  const _AlbumTile({required this.album, required this.count});
  final Album album;
  final int count;

  @override
  Widget build(BuildContext context) {
    final g = context.read<GalleryProvider>();
    return ListTile(
      leading: const Icon(Icons.collections_bookmark),
      title: Text(album.name),
      subtitle: Text('$count elemento(s)'),
      trailing: PopupMenuButton<String>(
        onSelected: (v) async {
          if (v == 'rename') {
            final name = await _askName(context, 'Renombrar álbum', album.name);
            if (name != null) await g.renameAlbum(album, name);
          } else {
            await g.deleteAlbum(album);
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'rename', child: Text('Renombrar')),
          PopupMenuItem(value: 'delete', child: Text('Eliminar (conserva los archivos)')),
        ],
      ),
    );
  }
}

Future<String?> _askName(BuildContext context, String title, String initial) {
  final ctrl = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(controller: ctrl, autofocus: true, decoration: const InputDecoration(labelText: 'Nombre')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Aceptar')),
      ],
    ),
  );
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
        child: Text(text,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary)),
      );
}
