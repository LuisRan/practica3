import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Niveles de sensibilidad del micrófono.
enum MicSensitivity {
  low('Baja', -35, false),
  medium('Media', -45, true),
  high('Alta', -60, true);

  const MicSensitivity(this.label, this.noiseFloorDb, this.autoGain);
  final String label;

  /// Umbral (dBFS) por debajo del cual el medidor muestra silencio.
  final double noiseFloorDb;

  /// Control automático de ganancia (aumenta la sensibilidad efectiva).
  final bool autoGain;
}

enum AudioQuality {
  voice('Voz 22 kHz', 22050, 64000),
  standard('Estándar 44.1 kHz', 44100, 128000),
  high('Alta 48 kHz', 48000, 192000);

  const AudioQuality(this.label, this.sampleRate, this.bitRate);
  final String label;
  final int sampleRate;
  final int bitRate;
}

/// Grabación de audio con el paquete `record`, medidor de nivel y temporizador.
class RecorderProvider extends ChangeNotifier {
  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Amplitude>? _ampSub;
  Timer? _ticker;
  final Stopwatch _watch = Stopwatch();

  MicSensitivity sensitivity = MicSensitivity.medium;
  AudioQuality quality = AudioQuality.standard;

  /// Duración máxima en segundos (0 = sin límite).
  int maxSeconds = 0;

  bool _recording = false;
  bool _paused = false;
  Duration _elapsed = Duration.zero;
  final List<double> levels = List<double>.filled(40, 0);
  String? error;
  bool permissionDenied = false;

  /// Se llama al terminar con (ruta, duración en ms).
  Future<void> Function(String path, int durationMs)? onFinished;

  bool get isRecording => _recording;
  bool get isPaused => _paused;
  Duration get elapsed => _elapsed;

  void setSensitivity(MicSensitivity s) { sensitivity = s; notifyListeners(); }
  void setQuality(AudioQuality q) { quality = q; notifyListeners(); }
  void setMaxSeconds(int s) { maxSeconds = s; notifyListeners(); }

  Future<void> start() async {
    error = null;
    if (!await _recorder.hasPermission()) {
      permissionDenied = true;
      notifyListeners();
      return;
    }
    permissionDenied = false;
    try {
      final dir = await getTemporaryDirectory();
      final path = p.join(dir.path, 'rec_${DateTime.now().millisecondsSinceEpoch}.m4a');
      await _recorder.start(
        RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: quality.sampleRate,
          bitRate: quality.bitRate,
          numChannels: 1,
          autoGain: sensitivity.autoGain,
          noiseSuppress: sensitivity == MicSensitivity.low,
        ),
        path: path,
      );
      _recording = true;
      _paused = false;
      _watch
        ..reset()
        ..start();
      _ampSub = _recorder.onAmplitudeChanged(const Duration(milliseconds: 80)).listen(_onAmplitude);
      _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
        _elapsed = _watch.elapsed;
        if (maxSeconds > 0 && _elapsed.inSeconds >= maxSeconds) {
          stop(); // temporizador de grabación
        }
        notifyListeners();
      });
      notifyListeners();
    } catch (e) {
      error = 'No se pudo iniciar la grabación: $e';
      notifyListeners();
    }
  }

  void _onAmplitude(Amplitude amp) {
    final floor = sensitivity.noiseFloorDb;
    final db = amp.current.isFinite ? amp.current : -160.0;
    final normalized = db <= floor ? 0.0 : ((db - floor) / -floor).clamp(0.0, 1.0);
    levels
      ..removeAt(0)
      ..add(normalized);
  }

  Future<void> pauseOrResume() async {
    if (!_recording) return;
    if (_paused) {
      await _recorder.resume();
      _watch.start();
    } else {
      await _recorder.pause();
      _watch.stop();
    }
    _paused = !_paused;
    notifyListeners();
  }

  Future<void> stop() async {
    if (!_recording) return;
    _recording = false; // evita dobles llamadas desde el temporizador
    _cleanupTimers();
    final path = await _recorder.stop();
    final ms = _watch.elapsedMilliseconds;
    _watch.stop();
    _reset();
    if (path != null && await File(path).exists()) {
      await onFinished?.call(path, ms);
    } else {
      error = 'La grabación no se guardó.';
    }
    notifyListeners();
  }

  Future<void> cancel() async {
    if (!_recording) return;
    _recording = false;
    _cleanupTimers();
    await _recorder.cancel();
    _watch.stop();
    _reset();
    notifyListeners();
  }

  void _cleanupTimers() {
    _ampSub?.cancel();
    _ampSub = null;
    _ticker?.cancel();
    _ticker = null;
  }

  void _reset() {
    _paused = false;
    _elapsed = Duration.zero;
    levels.fillRange(0, levels.length, 0);
  }

  @override
  void dispose() {
    _cleanupTimers();
    _recorder.dispose();
    super.dispose();
  }
}
