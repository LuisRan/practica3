/// Filtros y ediciones de foto (entidades de dominio puras).
///
/// Cada filtro se define como una matriz de color 4x5 (mismo formato que
/// `ColorFilter.matrix` de Flutter). Así la vista previa EN VIVO de la cámara
/// (ColorFiltered) y la foto guardada (procesada píxel a píxel) coinciden.
library;

enum PhotoFilter {
  none('Original', [
    1, 0, 0, 0, 0,
    0, 1, 0, 0, 0,
    0, 0, 1, 0, 0,
    0, 0, 0, 1, 0,
  ]),
  mono('Mono', [
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0, 0, 0, 1, 0,
  ]),
  noir('Noir', [
    0.33, 0.95, 0.12, 0, -40,
    0.33, 0.95, 0.12, 0, -40,
    0.33, 0.95, 0.12, 0, -40,
    0, 0, 0, 1, 0,
  ]),
  sepia('Sepia', [
    0.393, 0.769, 0.189, 0, 0,
    0.349, 0.686, 0.168, 0, 0,
    0.272, 0.534, 0.131, 0, 0,
    0, 0, 0, 1, 0,
  ]),
  vivid('Vívido', [
    1.6, -0.3, -0.3, 0, 0,
    -0.3, 1.6, -0.3, 0, 0,
    -0.3, -0.3, 1.6, 0, 0,
    0, 0, 0, 1, 0,
  ]),
  warm('Cálido', [
    1.15, 0, 0, 0, 12,
    0, 1.05, 0, 0, 4,
    0, 0, 0.9, 0, -8,
    0, 0, 0, 1, 0,
  ]),
  cool('Frío', [
    0.9, 0, 0, 0, -8,
    0, 1.0, 0, 0, 0,
    0, 0, 1.2, 0, 14,
    0, 0, 0, 1, 0,
  ]),
  invert('Negativo', [
    -1, 0, 0, 0, 255,
    0, -1, 0, 0, 255,
    0, 0, -1, 0, 255,
    0, 0, 0, 1, 0,
  ]);

  const PhotoFilter(this.label, this.matrix);
  final String label;
  final List<double> matrix;
}

class PhotoEdits {
  const PhotoEdits({
    this.filter = PhotoFilter.none,
    this.brightness = 0,
    this.contrast = 1,
    this.saturation = 1,
    this.quarterTurns = 0,
    this.cropSquare = false,
  });

  final PhotoFilter filter;
  final double brightness; // -0.5 .. 0.5
  final double contrast;   // 0.5 .. 1.5
  final double saturation; // 0 .. 2
  final int quarterTurns;
  final bool cropSquare;

  PhotoEdits copyWith({
    PhotoFilter? filter,
    double? brightness,
    double? contrast,
    double? saturation,
    int? quarterTurns,
    bool? cropSquare,
  }) =>
      PhotoEdits(
        filter: filter ?? this.filter,
        brightness: brightness ?? this.brightness,
        contrast: contrast ?? this.contrast,
        saturation: saturation ?? this.saturation,
        quarterTurns: quarterTurns ?? this.quarterTurns,
        cropSquare: cropSquare ?? this.cropSquare,
      );

  /// Matriz combinada de ajustes (brillo/contraste/saturación) — útil para
  /// la vista previa en vivo del editor con `ColorFilter.matrix`.
  List<double> get adjustmentMatrix {
    final s = saturation;
    const lr = 0.2126, lg = 0.7152, lb = 0.0722;
    final sr = (1 - s) * lr, sg = (1 - s) * lg, sb = (1 - s) * lb;
    final c = contrast;
    final t = (1 - c) * 127.5 + brightness * 255;
    return [
      c * (sr + s), c * sg, c * sb, 0, t,
      c * sr, c * (sg + s), c * sb, 0, t,
      c * sr, c * sg, c * (sb + s), 0, t,
      0, 0, 0, 1, 0,
    ];
  }
}

/// Multiplica dos matrices de color 4x5 (a ∘ b: primero b, luego a).
List<double> combineColorMatrices(List<double> a, List<double> b) {
  final out = List<double>.filled(20, 0);
  for (var r = 0; r < 4; r++) {
    for (var c = 0; c < 5; c++) {
      var v = 0.0;
      for (var k = 0; k < 4; k++) {
        v += a[r * 5 + k] * b[k * 5 + c];
      }
      if (c == 4) v += a[r * 5 + 4];
      out[r * 5 + c] = v;
    }
  }
  return out;
}
