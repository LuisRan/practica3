import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/utils/format.dart';
import '../../domain/entities/media_item.dart';
import '../../services/image_processing.dart';
import '../providers/gallery_provider.dart';
import '../widgets/media_details_sheet.dart';

/// Visor de fotos: deslizar entre fotos (PageView) y zoom con pinza (InteractiveViewer).
class PhotoViewerPage extends StatefulWidget {
  const PhotoViewerPage({super.key, required this.photos, required this.initialIndex});
  final List<MediaItem> photos;
  final int initialIndex;

  @override
  State<PhotoViewerPage> createState() => _PhotoViewerPageState();
}

class _PhotoViewerPageState extends State<PhotoViewerPage> {
  late final PageController _pages = PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;
  late List<MediaItem> _photos = List.of(widget.photos);
  int _version = 0; // fuerza recarga de la imagen después de editar

  MediaItem get _current => _photos[_index];

  Future<void> _delete() async {
    final g = context.read<GalleryProvider>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar foto?'),
        content: const Text('Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (ok != true) return;
    await g.delete(_current);
    if (!mounted) return;
    if (_photos.length == 1) {
      Navigator.pop(context);
    } else {
      setState(() {
        _photos = List.of(_photos)..removeAt(_index);
        _index = _index.clamp(0, _photos.length - 1);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = context.read<GalleryProvider>();
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(formatDate(_current.createdAt), style: const TextStyle(fontSize: 16)),
        actions: [
          IconButton(
            tooltip: 'Compartir',
            icon: const Icon(Icons.ios_share),
            onPressed: () => SharePlus.instance.share(ShareParams(files: [XFile(g.fileFor(_current).path)])),
          ),
          IconButton(
            tooltip: 'Detalles',
            icon: const Icon(Icons.info_outline),
            onPressed: () => showMediaDetails(context, _current),
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pages,
        itemCount: _photos.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (_, i) {
          final item = _photos[i];
          return InteractiveViewer(
            minScale: 1,
            maxScale: 6,
            child: Center(
              child: Hero(
                tag: 'photo-${item.id}',
                child: Image.file(
                  g.fileFor(item),
                  key: ValueKey('${item.fileName}-$_version'),
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.broken_image, color: Colors.white, size: 64),
                    Text('Imagen dañada o no soportada', style: TextStyle(color: Colors.white)),
                  ]),
                ),
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: BottomAppBar(
        color: Colors.black,
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          TextButton.icon(
            onPressed: () async {
              final edited = await Navigator.of(context).push<bool>(
                MaterialPageRoute(builder: (_) => PhotoEditorPage(item: _current)),
              );
              if (edited == true) {
                PaintingBinding.instance.imageCache
                  ..clear()
                  ..clearLiveImages();
                setState(() => _version++);
              }
            },
            icon: const Icon(Icons.tune, color: Colors.white),
            label: const Text('Editar', style: TextStyle(color: Colors.white)),
          ),
          TextButton.icon(
            onPressed: _delete,
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            label: const Text('Eliminar', style: TextStyle(color: Colors.redAccent)),
          ),
        ]),
      ),
    );
  }
}

/// Editor básico: filtro, brillo, contraste, saturación, rotación y recorte 1:1.
/// La vista previa usa matrices de color (instantáneo); al guardar se procesa en un isolate.
class PhotoEditorPage extends StatefulWidget {
  const PhotoEditorPage({super.key, required this.item});
  final MediaItem item;

  @override
  State<PhotoEditorPage> createState() => _PhotoEditorPageState();
}

class _PhotoEditorPageState extends State<PhotoEditorPage> {
  PhotoEdits _edits = const PhotoEdits();
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await context.read<GalleryProvider>().editPhoto(widget.item, _edits);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo guardar: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = context.read<GalleryProvider>();
    final matrix = combineColorMatrices(_edits.adjustmentMatrix, _edits.filter.matrix);
    Widget image = Image.file(g.fileFor(widget.item), fit: BoxFit.contain);
    if (_edits.cropSquare) {
      image = AspectRatio(aspectRatio: 1, child: ClipRect(child: FittedBox(fit: BoxFit.cover, child: image)));
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar foto'),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => setState(() => _edits = const PhotoEdits()),
            child: const Text('Restablecer'),
          ),
          FilledButton(onPressed: _saving ? null : _save, child: const Text('Guardar')),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: Container(
            color: Colors.black,
            alignment: Alignment.center,
            child: _saving
                ? const CircularProgressIndicator()
                : RotatedBox(
                    quarterTurns: _edits.quarterTurns,
                    child: ColorFiltered(colorFilter: ColorFilter.matrix(matrix), child: image),
                  ),
          ),
        ),
        SizedBox(
          height: 56,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            children: [
              for (final f in PhotoFilter.values)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(f.label),
                    selected: _edits.filter == f,
                    onSelected: (_) => setState(() => _edits = _edits.copyWith(filter: f)),
                  ),
                ),
            ],
          ),
        ),
        _slider('Brillo', _edits.brightness, -0.5, 0.5, (v) => _edits = _edits.copyWith(brightness: v)),
        _slider('Contraste', _edits.contrast, 0.5, 1.5, (v) => _edits = _edits.copyWith(contrast: v)),
        _slider('Saturación', _edits.saturation, 0, 2, (v) => _edits = _edits.copyWith(saturation: v)),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Row(children: [
            OutlinedButton.icon(
              onPressed: () => setState(() => _edits = _edits.copyWith(quarterTurns: _edits.quarterTurns + 1)),
              icon: const Icon(Icons.rotate_90_degrees_cw),
              label: const Text('Rotar'),
            ),
            const Spacer(),
            FilterChip(
              label: const Text('Recorte 1:1'),
              selected: _edits.cropSquare,
              onSelected: (v) => setState(() => _edits = _edits.copyWith(cropSquare: v)),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _slider(String label, double value, double min, double max, void Function(double) apply) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [
        SizedBox(width: 90, child: Text(label)),
        Expanded(
          child: Slider(value: value, min: min, max: max, onChanged: (v) => setState(() => apply(v))),
        ),
        SizedBox(width: 40, child: Text(value.toStringAsFixed(2), textAlign: TextAlign.end)),
      ]),
    );
  }
}
