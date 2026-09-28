import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../core/utils/format.dart';
import '../../domain/entities/media_item.dart';
import '../../services/permission_service.dart';
import '../providers/gallery_provider.dart';
import '../providers/recorder_provider.dart';
import '../widgets/audio_player_sheet.dart';
import '../widgets/level_meter.dart';

/// Grabadora: sensibilidad, calidad, temporizador y medidor de nivel animado.
class AudioPage extends StatefulWidget {
  const AudioPage({super.key});

  @override
  State<AudioPage> createState() => _AudioPageState();
}

class _AudioPageState extends State<AudioPage> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    final recorder = context.read<RecorderProvider>();
    final gallery = context.read<GalleryProvider>();
    recorder.onFinished = (path, ms) => gallery.saveRecording(path, ms);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _toggle(RecorderProvider rec) async {
    if (rec.isRecording) {
      await rec.stop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Grabación guardada')));
      }
    } else {
      final ok = await PermissionService.ensure(
          context, Permission.microphone, 'La app necesita el micrófono para grabar audio.');
      if (ok) await rec.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    final rec = context.watch<RecorderProvider>();
    final gallery = context.watch<GalleryProvider>();
    final scheme = Theme.of(context).colorScheme;
    final recent = gallery.allItems.where((m) => m.type == MediaType.audio).take(5).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Grabadora')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                SizedBox(height: 80, child: LevelMeter(levels: rec.levels, color: scheme.primary)),
                const SizedBox(height: 12),
                Text(formatDuration(rec.elapsed),
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
                if (rec.maxSeconds > 0) ...[
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: (rec.elapsed.inMilliseconds / (rec.maxSeconds * 1000)).clamp(0.0, 1.0)),
                  const SizedBox(height: 4),
                  Text('Límite: ${formatDuration(Duration(seconds: rec.maxSeconds))}',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
                const SizedBox(height: 20),
                Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                  IconButton.filledTonal(
                    tooltip: 'Descartar',
                    iconSize: 32,
                    onPressed: rec.isRecording ? rec.cancel : null,
                    icon: const Icon(Icons.close),
                  ),
                  AnimatedBuilder(
                    animation: _pulse,
                    builder: (_, child) => Transform.scale(
                      scale: rec.isRecording && !rec.isPaused ? 1 + _pulse.value * 0.12 : 1,
                      child: child,
                    ),
                    child: FloatingActionButton.large(
                      heroTag: 'rec',
                      onPressed: () => _toggle(rec),
                      child: Icon(rec.isRecording ? Icons.stop : Icons.mic, size: 40),
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: rec.isPaused ? 'Reanudar' : 'Pausar',
                    iconSize: 32,
                    onPressed: rec.isRecording ? rec.pauseOrResume : null,
                    icon: Icon(rec.isPaused ? Icons.play_arrow : Icons.pause),
                  ),
                ]),
                if (rec.error != null) ...[
                  const SizedBox(height: 12),
                  Text(rec.error!, style: TextStyle(color: scheme.error)),
                ],
              ]),
            ),
          ),
          const SizedBox(height: 12),
          Text('Opciones de captura', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          AbsorbPointer(
            absorbing: rec.isRecording,
            child: Opacity(
              opacity: rec.isRecording ? 0.5 : 1,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Text('Sensibilidad'),
                const SizedBox(height: 4),
                SegmentedButton<MicSensitivity>(
                  segments: [
                    for (final s in MicSensitivity.values) ButtonSegment(value: s, label: Text(s.label)),
                  ],
                  selected: {rec.sensitivity},
                  onSelectionChanged: (s) => rec.setSensitivity(s.first),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<AudioQuality>(
                  value: rec.quality,
                  decoration: const InputDecoration(labelText: 'Calidad', border: OutlineInputBorder()),
                  items: [
                    for (final q in AudioQuality.values) DropdownMenuItem(value: q, child: Text(q.label)),
                  ],
                  onChanged: (q) => rec.setQuality(q!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: rec.maxSeconds,
                  decoration: const InputDecoration(labelText: 'Temporizador de grabación', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('Sin límite')),
                    DropdownMenuItem(value: 15, child: Text('15 segundos')),
                    DropdownMenuItem(value: 30, child: Text('30 segundos')),
                    DropdownMenuItem(value: 60, child: Text('1 minuto')),
                    DropdownMenuItem(value: 120, child: Text('2 minutos')),
                  ],
                  onChanged: (v) => rec.setMaxSeconds(v ?? 0),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          Text('Últimas grabaciones', style: Theme.of(context).textTheme.titleMedium),
          if (recent.isEmpty)
            const Padding(padding: EdgeInsets.all(8), child: Text('Aún no hay grabaciones.')),
          for (final item in recent)
            ListTile(
              leading: Icon(Icons.graphic_eq, color: scheme.primary),
              title: Text(item.fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text('${formatDate(item.createdAt)} · ${formatDuration(Duration(milliseconds: item.durationMs))}'),
              onTap: () => showAudioPlayer(context, item),
            ),
        ],
      ),
    );
  }
}
