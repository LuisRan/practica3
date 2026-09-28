import 'dart:io';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Directorios del sandbox (Android: /data/data/<app>/..., iOS: contenedor de la app).
///  - media/photos, media/audio  -> documentos de la app (persistentes)
///  - thumbs                     -> caché (el sistema puede borrarla)
class FileStorage {
  Directory? _docs;
  Directory? _cache;

  Future<Directory> get _documents async => _docs ??= await getApplicationDocumentsDirectory();
  Future<Directory> get _caches async => _cache ??= await getApplicationCacheDirectory();

  late String _docsPath;

  Future<void> init() async {
    _docsPath = (await _documents).path;
    for (final sub in ['media/photos', 'media/audio']) {
      await Directory(p.join(_docsPath, sub)).create(recursive: true);
    }
    await Directory(p.join((await _caches).path, 'thumbs')).create(recursive: true);
  }

  String photosDir() => p.join(_docsPath, 'media', 'photos');
  String audioDir() => p.join(_docsPath, 'media', 'audio');

  File photoFile(String name) => File(p.join(photosDir(), name));
  File audioFile(String name) => File(p.join(audioDir(), name));

  Future<File> thumbFile(String name) async => File(p.join((await _caches).path, 'thumbs', name));

  static String newName(String prefix, String ext) {
    final stamp = DateFormat('yyyyMMdd_HHmmss_SSS').format(DateTime.now());
    return '${prefix}_$stamp.$ext';
  }

  Future<String> writePhoto(Uint8List bytes) async {
    final name = newName('IMG', 'jpg');
    await photoFile(name).writeAsBytes(bytes, flush: true);
    return name;
  }

  /// Mueve (o copia si está en otro volumen) un audio temporal al directorio de medios.
  Future<String> adoptAudio(String sourcePath) async {
    final ext = p.extension(sourcePath).replaceFirst('.', '');
    final name = newName('AUD', ext.isEmpty ? 'm4a' : ext);
    final target = audioFile(name);
    final source = File(sourcePath);
    if (p.isWithin(audioDir(), sourcePath)) {
      await source.rename(target.path);
    } else {
      await source.copy(target.path);
    }
    return name;
  }

  Future<int> usage() async {
    var total = 0;
    final root = Directory(p.join(_docsPath, 'media'));
    if (!await root.exists()) return 0;
    await for (final e in root.list(recursive: true)) {
      if (e is File) total += await e.length();
    }
    return total;
  }

  Future<void> clearThumbs() async {
    final dir = Directory(p.join((await _caches).path, 'thumbs'));
    if (await dir.exists()) await dir.delete(recursive: true);
    await dir.create(recursive: true);
  }
}
