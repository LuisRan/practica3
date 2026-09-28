import 'dart:io';
import 'dart:typed_data';

import '../entities/media_item.dart';

/// Contrato del repositorio. La capa de presentación solo conoce esta
/// abstracción; la implementación concreta (SQLite + sistema de archivos)
/// vive en la capa de datos.
abstract class MediaRepository {
  Future<List<MediaItem>> getMedia({MediaType? type, int? albumId, String? query});
  Future<MediaItem> savePhoto(Uint8List jpegBytes, {String? filter, int? albumId, List<String> tags = const []});
  Future<MediaItem> saveAudio(String tempPath, {required int durationMs, int? albumId, List<String> tags = const []});
  Future<void> updateMedia(MediaItem item);
  Future<void> replacePhotoBytes(MediaItem item, Uint8List jpegBytes);
  Future<void> deleteMedia(MediaItem item);

  Future<List<Album>> getAlbums();
  Future<Album> createAlbum(String name);
  Future<void> renameAlbum(Album album, String name);
  Future<void> deleteAlbum(Album album);
  Future<Map<int, int>> albumCounts();

  File fileFor(MediaItem item);
  Future<File?> thumbnailFor(MediaItem item);
  Future<int> storageUsage();
  Future<void> clearThumbnails();
}
