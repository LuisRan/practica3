import 'dart:io';
import 'dart:typed_data';

import '../../domain/entities/media_item.dart';
import '../../domain/repositories/media_repository.dart';
import '../../services/image_processing.dart';
import '../datasources/file_storage.dart';
import '../datasources/media_local_datasource.dart';

/// Implementación del repositorio: combina SQLite (metadatos) y archivos.
class MediaRepositoryImpl implements MediaRepository {
  MediaRepositoryImpl(this._db, this._files);
  final MediaLocalDataSource _db;
  final FileStorage _files;

  /// Caché en memoria de rutas de miniaturas ya generadas.
  final Map<String, File> _thumbCache = {};

  @override
  Future<List<MediaItem>> getMedia({MediaType? type, int? albumId, String? query}) =>
      _db.queryMedia(type: type, albumId: albumId, query: query);

  @override
  Future<MediaItem> savePhoto(Uint8List jpegBytes, {String? filter, int? albumId, List<String> tags = const []}) async {
    final name = await _files.writePhoto(jpegBytes);
    final item = MediaItem(
      type: MediaType.photo,
      fileName: name,
      createdAt: DateTime.now(),
      filter: filter,
      albumId: albumId,
      tags: tags,
    );
    final id = await _db.insertMedia(item);
    final saved = item.copyWith(id: id);
    await thumbnailFor(saved); // pre-genera la miniatura
    return saved;
  }

  @override
  Future<MediaItem> saveAudio(String tempPath,
      {required int durationMs, int? albumId, List<String> tags = const []}) async {
    final name = await _files.adoptAudio(tempPath);
    final item = MediaItem(
      type: MediaType.audio,
      fileName: name,
      createdAt: DateTime.now(),
      durationMs: durationMs,
      albumId: albumId,
      tags: tags,
    );
    final id = await _db.insertMedia(item);
    return item.copyWith(id: id);
  }

  @override
  Future<void> updateMedia(MediaItem item) => _db.updateMedia(item);

  @override
  Future<void> replacePhotoBytes(MediaItem item, Uint8List jpegBytes) async {
    await fileFor(item).writeAsBytes(jpegBytes, flush: true);
    _thumbCache.remove(item.fileName);
    final thumb = await _files.thumbFile(item.fileName);
    if (await thumb.exists()) await thumb.delete();
    await thumbnailFor(item);
  }

  @override
  Future<void> deleteMedia(MediaItem item) async {
    final file = fileFor(item);
    if (await file.exists()) await file.delete();
    final thumb = await _files.thumbFile(item.fileName);
    if (await thumb.exists()) await thumb.delete();
    _thumbCache.remove(item.fileName);
    if (item.id != null) await _db.deleteMedia(item.id!);
  }

  @override
  Future<List<Album>> getAlbums() => _db.queryAlbums();

  @override
  Future<Album> createAlbum(String name) async {
    final album = Album(name: name.trim(), createdAt: DateTime.now());
    final id = await _db.insertAlbum(album);
    return Album(id: id, name: album.name, createdAt: album.createdAt);
  }

  @override
  Future<void> renameAlbum(Album album, String name) => _db.renameAlbum(album.id!, name.trim());

  @override
  Future<void> deleteAlbum(Album album) => _db.deleteAlbum(album.id!);

  @override
  Future<Map<int, int>> albumCounts() => _db.albumCounts();

  @override
  File fileFor(MediaItem item) =>
      item.isPhoto ? _files.photoFile(item.fileName) : _files.audioFile(item.fileName);

  @override
  Future<File?> thumbnailFor(MediaItem item) async {
    if (!item.isPhoto) return null;
    final cached = _thumbCache[item.fileName];
    if (cached != null) return cached;
    final thumb = await _files.thumbFile(item.fileName);
    if (await thumb.exists()) return _thumbCache[item.fileName] = thumb;
    final source = fileFor(item);
    if (!await source.exists()) return null;
    try {
      final bytes = await ImageProcessing.thumbnail(await source.readAsBytes());
      if (bytes == null) return null;
      await thumb.writeAsBytes(bytes, flush: true);
      return _thumbCache[item.fileName] = thumb;
    } catch (_) {
      return null; // archivo dañado: la UI muestra un ícono de error
    }
  }

  @override
  Future<int> storageUsage() => _files.usage();

  @override
  Future<void> clearThumbnails() async {
    _thumbCache.clear();
    await _files.clearThumbs();
  }
}
