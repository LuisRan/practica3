import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../domain/entities/photo_edits.dart';

export '../domain/entities/photo_edits.dart';

/// Procesamiento de imágenes con el paquete `image` (Dart puro, funciona igual
/// en Android e iOS). Todo corre en un isolate con `compute` para no bloquear la UI.
class ImageProcessing {
  static const int maxDimension = 2560;

  /// Corrige orientación EXIF, limita el tamaño y re-codifica a JPEG.
  static Future<Uint8List> normalize(Uint8List bytes) => compute(_normalize, bytes);

  static Future<Uint8List> applyEdits(Uint8List bytes, PhotoEdits edits) =>
      compute(_applyEdits, _EditJob(bytes, edits));

  static Future<Uint8List?> thumbnail(Uint8List bytes, {int size = 320}) =>
      compute(_thumbnail, _ThumbJob(bytes, size));
}

class _EditJob {
  const _EditJob(this.bytes, this.edits);
  final Uint8List bytes;
  final PhotoEdits edits;
}

class _ThumbJob {
  const _ThumbJob(this.bytes, this.size);
  final Uint8List bytes;
  final int size;
}

img.Image? _decode(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  var image = img.bakeOrientation(decoded);
  final longest = image.width > image.height ? image.width : image.height;
  if (longest > ImageProcessing.maxDimension) {
    image = image.width >= image.height
        ? img.copyResize(image, width: ImageProcessing.maxDimension)
        : img.copyResize(image, height: ImageProcessing.maxDimension);
  }
  return image;
}

Uint8List _normalize(Uint8List bytes) {
  final image = _decode(bytes);
  if (image == null) throw const FormatException('Imagen dañada o formato no soportado');
  return Uint8List.fromList(img.encodeJpg(image, quality: 90));
}

Uint8List _applyEdits(_EditJob job) {
  var image = _decode(job.bytes);
  if (image == null) throw const FormatException('Imagen dañada o formato no soportado');
  final e = job.edits;

  // 1) Filtro + ajustes como una sola matriz de color.
  final matrix = combineColorMatrices(e.adjustmentMatrix, e.filter.matrix);
  final isIdentity = e.filter == PhotoFilter.none && e.brightness == 0 && e.contrast == 1 && e.saturation == 1;
  if (!isIdentity) {
    for (final p in image) {
      final r = p.r.toDouble(), g = p.g.toDouble(), b = p.b.toDouble(), a = p.a.toDouble();
      p
        ..r = _clamp(matrix[0] * r + matrix[1] * g + matrix[2] * b + matrix[3] * a + matrix[4])
        ..g = _clamp(matrix[5] * r + matrix[6] * g + matrix[7] * b + matrix[8] * a + matrix[9])
        ..b = _clamp(matrix[10] * r + matrix[11] * g + matrix[12] * b + matrix[13] * a + matrix[14]);
    }
  }

  // 2) Rotación.
  final turns = ((e.quarterTurns % 4) + 4) % 4;
  if (turns != 0) image = img.copyRotate(image, angle: 90 * turns);

  // 3) Recorte cuadrado centrado.
  if (e.cropSquare) {
    final side = image.width < image.height ? image.width : image.height;
    image = img.copyCrop(image,
        x: (image.width - side) ~/ 2, y: (image.height - side) ~/ 2, width: side, height: side);
  }
  return Uint8List.fromList(img.encodeJpg(image, quality: 92));
}

Uint8List? _thumbnail(_ThumbJob job) {
  final decoded = img.decodeImage(job.bytes);
  if (decoded == null) return null;
  final oriented = img.bakeOrientation(decoded);
  final thumb = oriented.width >= oriented.height
      ? img.copyResize(oriented, height: job.size)
      : img.copyResize(oriented, width: job.size);
  return Uint8List.fromList(img.encodeJpg(thumb, quality: 80));
}

num _clamp(double v) => v < 0 ? 0 : (v > 255 ? 255 : v);
