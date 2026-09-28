import 'dart:typed_data';

import '../entities/media_item.dart';
import '../repositories/media_repository.dart';
import '../../services/image_processing.dart';

/// Casos de uso: orquestan la lógica de negocio sobre el repositorio.
/// Se agrupan en una clase para mantener el ejemplo compacto.
class MediaUseCases {
  MediaUseCases(this._repo);
  final MediaRepository _repo;

  MediaRepository get repository => _repo;

  /// Captura de foto: aplica el filtro (en un isolate) y guarda archivo + metadatos.
  Future<MediaItem> capturePhoto(Uint8List rawBytes, {required PhotoFilter filter, int? albumId}) async {
    final processed = filter == PhotoFilter.none
        ? await ImageProcessing.normalize(rawBytes)
        : await ImageProcessing.applyEdits(rawBytes, PhotoEdits(filter: filter));
    return _repo.savePhoto(processed,
        filter: filter == PhotoFilter.none ? null : filter.label, albumId: albumId);
  }

  Future<MediaItem> importPhoto(Uint8List bytes, {int? albumId}) async {
    final processed = await ImageProcessing.normalize(bytes);
    return _repo.savePhoto(processed, albumId: albumId, tags: const ['importado']);
  }

  Future<MediaItem> saveRecording(String path, int durationMs, {int? albumId}) =>
      _repo.saveAudio(path, durationMs: durationMs, albumId: albumId);

  Future<MediaItem> importAudio(String path, {int? albumId}) =>
      _repo.saveAudio(path, durationMs: 0, albumId: albumId, tags: const ['importado']);

  Future<void> editPhoto(MediaItem item, PhotoEdits edits) async {
    final original = await _repo.fileFor(item).readAsBytes();
    final out = await ImageProcessing.applyEdits(original, edits);
    await _repo.replacePhotoBytes(item, out);
    if (edits.filter != PhotoFilter.none) {
      await _repo.updateMedia(item.copyWith(filter: edits.filter.label));
    }
  }

  Future<void> addTag(MediaItem item, String tag) {
    final clean = tag.trim().replaceAll(',', ' ');
    if (clean.isEmpty || item.tags.contains(clean)) return Future.value();
    return _repo.updateMedia(item.copyWith(tags: [...item.tags, clean]));
  }

  Future<void> removeTag(MediaItem item, String tag) =>
      _repo.updateMedia(item.copyWith(tags: item.tags.where((t) => t != tag).toList()));

  Future<void> moveToAlbum(MediaItem item, int? albumId) =>
      _repo.updateMedia(albumId == null ? item.copyWith(clearAlbum: true) : item.copyWith(albumId: albumId));
}
