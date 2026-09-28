import 'package:camara_mic_flutter/core/utils/format.dart';
import 'package:camara_mic_flutter/domain/entities/photo_edits.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formatDuration', () {
    expect(formatDuration(const Duration(seconds: 75)), '01:15');
    expect(formatDuration(const Duration(hours: 1, minutes: 2, seconds: 3)), '1:02:03');
  });

  test('formatBytes', () {
    expect(formatBytes(500), '500 B');
    expect(formatBytes(2048), '2.0 KB');
  });

  test('matriz identidad no altera la matriz del filtro', () {
    final m = combineColorMatrices(const PhotoEdits().adjustmentMatrix, PhotoFilter.sepia.matrix);
    for (var i = 0; i < 20; i++) {
      expect(m[i], closeTo(PhotoFilter.sepia.matrix[i], 1e-9));
    }
  });
}
