import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../../domain/entities/media_item.dart';
import '../../domain/usecases/media_usecases.dart';
import '../../services/image_processing.dart';

enum GalleryFilter { all, photos, audio }

/// Estado de la galería: lista de medios, álbumes y filtros activos.
class GalleryProvider extends ChangeNotifier {
  GalleryProvider(this.useCases) {
    refresh();
  }

  final MediaUseCases useCases;

  List<MediaItem> _items = [];
  List<MediaItem> _all = [];
  List<Album> _albums = [];
  Map<int, int> _albumCounts = {};
  GalleryFilter _filter = GalleryFilter.all;
  int? _albumId;
  String _query = '';
  bool _loading = false;
  String? _error;

  List<MediaItem> get items => _items;

  /// Todos los elementos sin filtros (para la cámara y la grabadora).
  List<MediaItem> get allItems => _all;
  List<MediaItem> get photos => _items.where((m) => m.isPhoto).toList();
  List<MediaItem> get audios => _items.where((m) => !m.isPhoto).toList();
  List<Album> get albums => _albums;
  Map<int, int> get albumCounts => _albumCounts;
  GalleryFilter get filter => _filter;
  int? get albumId => _albumId;
  String get query => _query;
  bool get loading => _loading;
  String? get error => _error;
  MediaItem? get lastPhoto => _all.where((m) => m.isPhoto).firstOrNull;

  Album? albumById(int? id) => id == null ? null : _albums.where((a) => a.id == id).firstOrNull;

  set filter(GalleryFilter value) {
    _filter = value;
    refresh();
  }

  set albumId(int? value) {
    _albumId = value;
    refresh();
  }

  set query(String value) {
    _query = value;
    refresh();
  }

  Future<void> refresh() async {
    _loading = true;
    notifyListeners();
    try {
      final repo = useCases.repository;
      _items = await repo.getMedia(
        type: switch (_filter) {
          GalleryFilter.photos => MediaType.photo,
          GalleryFilter.audio => MediaType.audio,
          GalleryFilter.all => null,
        },
        albumId: _albumId,
        query: _query,
      );
      _all = await repo.getMedia();
      _albums = await repo.getAlbums();
      _albumCounts = await repo.albumCounts();
      _error = null;
    } catch (e) {
      _error = 'Error al leer la base de datos: $e';
    }
    _loading = false;
    notifyListeners();
  }

  File fileFor(MediaItem item) => useCases.repository.fileFor(item);
  Future<File?> thumbnailFor(MediaItem item) => useCases.repository.thumbnailFor(item);

  // --- Acciones ---

  Future<MediaItem> capturePhoto(Uint8List bytes, PhotoFilter filter, {int? albumId}) async {
    final item = await useCases.capturePhoto(bytes, filter: filter, albumId: albumId);
    await refresh();
    return item;
  }

  Future<void> importPhotos(List<Uint8List> images) async {
    for (final bytes in images) {
      await useCases.importPhoto(bytes, albumId: _albumId);
    }
    await refresh();
  }

  Future<void> saveRecording(String path, int durationMs) async {
    await useCases.saveRecording(path, durationMs);
    await refresh();
  }

  Future<void> importAudio(String path) async {
    await useCases.importAudio(path, albumId: _albumId);
    await refresh();
  }

  Future<void> delete(MediaItem item) async {
    await useCases.repository.deleteMedia(item);
    await refresh();
  }

  Future<void> editPhoto(MediaItem item, PhotoEdits edits) async {
    await useCases.editPhoto(item, edits);
    await refresh();
  }

  Future<void> addTag(MediaItem item, String tag) async {
    await useCases.addTag(item, tag);
    await refresh();
  }

  Future<void> removeTag(MediaItem item, String tag) async {
    await useCases.removeTag(item, tag);
    await refresh();
  }

  Future<void> moveToAlbum(MediaItem item, int? albumId) async {
    await useCases.moveToAlbum(item, albumId);
    await refresh();
  }

  Future<void> createAlbum(String name) async {
    if (name.trim().isEmpty) return;
    await useCases.repository.createAlbum(name);
    await refresh();
  }

  Future<void> renameAlbum(Album album, String name) async {
    if (name.trim().isEmpty) return;
    await useCases.repository.renameAlbum(album, name);
    await refresh();
  }

  Future<void> deleteAlbum(Album album) async {
    await useCases.repository.deleteAlbum(album);
    if (_albumId == album.id) _albumId = null;
    await refresh();
  }

  /// Busca el elemento actualizado (tras editar etiquetas/álbum) por id.
  MediaItem? byId(int? id) => _all.where((m) => m.id == id).firstOrNull;
}
