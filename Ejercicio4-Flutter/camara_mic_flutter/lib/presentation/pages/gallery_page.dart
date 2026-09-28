import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/utils/format.dart';
import '../../domain/entities/media_item.dart';
import '../providers/gallery_provider.dart';
import '../widgets/audio_player_sheet.dart';
import '../widgets/media_details_sheet.dart';
import 'photo_viewer_page.dart';

/// Galería integrada: fotos en cuadrícula (miniaturas en caché), audios en lista,
/// filtros por tipo/álbum/etiqueta, importación y exportación.
class GalleryPage extends StatefulWidget {
  const GalleryPage({super.key});

  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _importPhotos(GalleryProvider g) async {
    final picked = await ImagePicker().pickMultiImage();
    if (picked.isEmpty) return;
    final bytes = <Uint8List>[];
    for (final x in picked) {
      bytes.add(await x.readAsBytes());
    }
    try {
      await g.importPhotos(bytes);
      _snack('${bytes.length} foto(s) importada(s)');
    } catch (e) {
      _snack('Error al importar: $e');
    }
  }

  Future<void> _importAudio(GalleryProvider g) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.audio, allowMultiple: true);
    if (result == null) return;
    for (final f in result.files) {
      if (f.path != null) await g.importAudio(f.path!);
    }
    _snack('${result.files.length} audio(s) importado(s)');
  }

  Future<void> _exportVisible(GalleryProvider g) async {
    final files = g.items.map((m) => g.fileFor(m)).where((f) => f.existsSync()).map((f) => XFile(f.path)).toList();
    if (files.isEmpty) {
      _snack('No hay elementos para exportar');
      return;
    }
    await SharePlus.instance.share(ShareParams(files: files, text: 'Exportado desde Cámara y Micrófono'));
  }

  void _snack(String m) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    final g = context.watch<GalleryProvider>();
    final album = g.albumById(g.albumId);
    return Scaffold(
      appBar: AppBar(
        title: Text(album?.name ?? 'Galería'),
        actions: [
          PopupMenuButton<int?>(
            tooltip: 'Álbum',
            icon: const Icon(Icons.collections_bookmark_outlined),
            onSelected: (id) => g.albumId = id == -1 ? null : id,
            itemBuilder: (_) => [
              CheckedPopupMenuItem(value: -1, checked: g.albumId == null, child: const Text('Todos los álbumes')),
              for (final a in g.albums)
                CheckedPopupMenuItem(
                  value: a.id,
                  checked: g.albumId == a.id,
                  child: Text('${a.name} (${g.albumCounts[a.id] ?? 0})'),
                ),
            ],
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              switch (v) {
                case 'photos':
                  _importPhotos(g);
                case 'audio':
                  _importAudio(g);
                case 'export':
                  _exportVisible(g);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'photos', child: ListTile(leading: Icon(Icons.add_photo_alternate), title: Text('Importar fotos'))),
              PopupMenuItem(value: 'audio', child: ListTile(leading: Icon(Icons.library_music), title: Text('Importar audio'))),
              PopupMenuItem(value: 'export', child: ListTile(leading: Icon(Icons.ios_share), title: Text('Exportar lo visible'))),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(112),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Column(children: [
              SearchBar(
                controller: _search,
                hintText: 'Buscar por etiqueta, nombre o álbum',
                leading: const Icon(Icons.search),
                onChanged: (q) => g.query = q,
                trailing: [
                  if (_search.text.isNotEmpty)
                    IconButton(
                        onPressed: () {
                          _search.clear();
                          g.query = '';
                        },
                        icon: const Icon(Icons.clear)),
                ],
              ),
              const SizedBox(height: 8),
              SegmentedButton<GalleryFilter>(
                segments: const [
                  ButtonSegment(value: GalleryFilter.all, label: Text('Todo'), icon: Icon(Icons.apps)),
                  ButtonSegment(value: GalleryFilter.photos, label: Text('Fotos'), icon: Icon(Icons.photo)),
                  ButtonSegment(value: GalleryFilter.audio, label: Text('Audio'), icon: Icon(Icons.graphic_eq)),
                ],
                selected: {g.filter},
                onSelectionChanged: (s) => g.filter = s.first,
              ),
            ]),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: g.refresh,
        child: g.items.isEmpty
            ? ListView(children: const [
                SizedBox(height: 120),
                Icon(Icons.photo_library_outlined, size: 72),
                SizedBox(height: 8),
                Center(child: Text('Sin contenido. Toma fotos o graba audio.')),
              ])
            : CustomScrollView(slivers: [
                if (g.photos.isNotEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.all(3),
                    sliver: SliverGrid.builder(
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 130, mainAxisSpacing: 3, crossAxisSpacing: 3),
                      itemCount: g.photos.length,
                      itemBuilder: (_, i) => _PhotoTile(
                        item: g.photos[i],
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => PhotoViewerPage(photos: g.photos, initialIndex: i),
                        )),
                      ),
                    ),
                  ),
                if (g.audios.isNotEmpty) ...[
                  const SliverToBoxAdapter(
                    child: Padding(padding: EdgeInsets.fromLTRB(16, 16, 16, 4), child: Text('Grabaciones')),
                  ),
                  SliverList.builder(
                    itemCount: g.audios.length,
                    itemBuilder: (_, i) => _AudioTile(item: g.audios[i]),
                  ),
                ],
              ]),
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.item, required this.onTap});
  final MediaItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final g = context.read<GalleryProvider>();
    return GestureDetector(
      onTap: onTap,
      onLongPress: () => showMediaDetails(context, item),
      child: Hero(
        tag: 'photo-${item.id}',
        child: FutureBuilder<File?>(
          future: g.thumbnailFor(item),
          builder: (_, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const ColoredBox(color: Colors.black12);
            }
            if (snap.data == null) {
              return const ColoredBox(color: Colors.black12, child: Icon(Icons.broken_image_outlined));
            }
            return Stack(fit: StackFit.expand, children: [
              Image.file(snap.data!, fit: BoxFit.cover, gaplessPlayback: true),
              if (item.filter != null)
                const Positioned(left: 4, bottom: 4, child: Icon(Icons.filter_vintage, size: 14, color: Colors.white)),
            ]);
          },
        ),
      ),
    );
  }
}

class _AudioTile extends StatelessWidget {
  const _AudioTile({required this.item});
  final MediaItem item;

  @override
  Widget build(BuildContext context) {
    final g = context.read<GalleryProvider>();
    final album = g.albumById(item.albumId);
    return Dismissible(
      key: ValueKey('audio-${item.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Theme.of(context).colorScheme.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) => showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('¿Eliminar grabación?'),
          content: const Text('Se borrará el archivo del dispositivo.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar')),
          ],
        ),
      ),
      onDismissed: (_) => g.delete(item),
      child: ListTile(
        leading: CircleAvatar(child: Icon(Icons.graphic_eq, color: Theme.of(context).colorScheme.primary)),
        title: Text(item.fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text([
          formatDate(item.createdAt),
          formatDuration(Duration(milliseconds: item.durationMs)),
          if (album != null) album.name,
          if (item.tags.isNotEmpty) item.tags.map((t) => '#$t').join(' '),
        ].join(' · ')),
        trailing: IconButton(icon: const Icon(Icons.more_vert), onPressed: () => showMediaDetails(context, item)),
        onTap: () => showAudioPlayer(context, item),
      ),
    );
  }
}
