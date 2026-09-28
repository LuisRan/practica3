import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/format.dart';
import '../../domain/entities/media_item.dart';
import '../providers/gallery_provider.dart';

Future<void> showMediaDetails(BuildContext context, MediaItem item) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => MediaDetailsSheet(itemId: item.id!),
  );
}

/// Metadatos editables: etiquetas y álbum (persistidos en SQLite).
class MediaDetailsSheet extends StatefulWidget {
  const MediaDetailsSheet({super.key, required this.itemId});
  final int itemId;

  @override
  State<MediaDetailsSheet> createState() => _MediaDetailsSheetState();
}

class _MediaDetailsSheetState extends State<MediaDetailsSheet> {
  final _tagCtrl = TextEditingController();

  @override
  void dispose() {
    _tagCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gallery = context.watch<GalleryProvider>();
    final item = gallery.byId(widget.itemId);
    if (item == null) return const SizedBox(height: 120, child: Center(child: Text('Elemento no encontrado')));
    final file = gallery.fileFor(item);
    final size = file.existsSync() ? file.lengthSync() : 0;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Detalles', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        _row('Archivo', item.fileName),
        _row('Fecha', formatDate(item.createdAt)),
        _row('Tipo', item.isPhoto ? 'Foto' : 'Audio'),
        if (!item.isPhoto) _row('Duración', formatDuration(Duration(milliseconds: item.durationMs))),
        if (item.filter != null) _row('Filtro', item.filter!),
        _row('Tamaño', formatBytes(size)),
        const Divider(height: 24),
        DropdownButtonFormField<int?>(
          key: ValueKey('album-${item.albumId}'),
          value: item.albumId,
          decoration: const InputDecoration(labelText: 'Álbum', border: OutlineInputBorder()),
          items: [
            const DropdownMenuItem<int?>(value: null, child: Text('Sin álbum')),
            for (final a in gallery.albums) DropdownMenuItem<int?>(value: a.id, child: Text(a.name)),
          ],
          onChanged: (id) => gallery.moveToAlbum(item, id),
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final t in item.tags)
            InputChip(label: Text('#$t'), onDeleted: () => gallery.removeTag(item, t)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _tagCtrl,
              decoration: const InputDecoration(hintText: 'Nueva etiqueta', prefixIcon: Icon(Icons.sell_outlined)),
              onSubmitted: (_) => _addTag(gallery, item),
            ),
          ),
          IconButton(onPressed: () => _addTag(gallery, item), icon: const Icon(Icons.add)),
        ]),
      ]),
    );
  }

  void _addTag(GalleryProvider gallery, MediaItem item) {
    gallery.addTag(item, _tagCtrl.text);
    _tagCtrl.clear();
  }

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          SizedBox(width: 90, child: Text(k, style: const TextStyle(fontWeight: FontWeight.w600))),
          Expanded(child: Text(v, overflow: TextOverflow.ellipsis)),
        ]),
      );
}
