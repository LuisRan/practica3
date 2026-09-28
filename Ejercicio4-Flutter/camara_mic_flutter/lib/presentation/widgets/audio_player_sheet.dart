import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/utils/format.dart';
import '../../domain/entities/media_item.dart';
import '../providers/gallery_provider.dart';
import 'media_details_sheet.dart';

Future<void> showAudioPlayer(BuildContext context, MediaItem item) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => AudioPlayerSheet(item: item),
  );
}

/// Reproductor con audioplayers: play/pausa, barra de progreso, ±10 s y velocidad.
class AudioPlayerSheet extends StatefulWidget {
  const AudioPlayerSheet({super.key, required this.item});
  final MediaItem item;

  @override
  State<AudioPlayerSheet> createState() => _AudioPlayerSheetState();
}

class _AudioPlayerSheetState extends State<AudioPlayerSheet> {
  final AudioPlayer _player = AudioPlayer();
  final List<StreamSubscription> _subs = [];
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  PlayerState _state = PlayerState.stopped;
  double _rate = 1;
  String? _error;

  @override
  void initState() {
    super.initState();
    final file = context.read<GalleryProvider>().fileFor(widget.item);
    _subs
      ..add(_player.onPositionChanged.listen((p) => setState(() => _position = p)))
      ..add(_player.onDurationChanged.listen((d) => setState(() => _duration = d)))
      ..add(_player.onPlayerStateChanged.listen((s) => setState(() => _state = s)))
      ..add(_player.onPlayerComplete.listen((_) => setState(() => _position = Duration.zero)));
    _player.setSource(DeviceFileSource(file.path)).then((_) async {
      final d = await _player.getDuration();
      if (d != null && mounted) setState(() => _duration = d);
    }).catchError((Object e) {
      if (mounted) setState(() => _error = 'No se pudo abrir el audio (¿dañado o formato no soportado?).');
    });
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_state == PlayerState.playing) {
      await _player.pause();
    } else {
      await _player.resume();
    }
  }

  Future<void> _skip(int seconds) async {
    final target = _position + Duration(seconds: seconds);
    final clamped = target < Duration.zero ? Duration.zero : (target > _duration ? _duration : target);
    await _player.seek(clamped);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final playing = _state == PlayerState.playing;
    final maxMs = _duration.inMilliseconds.toDouble().clamp(1.0, double.infinity);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.graphic_eq, size: 64, color: scheme.primary),
          const SizedBox(height: 8),
          Text(widget.item.fileName, style: Theme.of(context).textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(formatDate(widget.item.createdAt), style: Theme.of(context).textTheme.bodySmall),
          if (_error != null) Padding(padding: const EdgeInsets.all(8), child: Text(_error!, style: TextStyle(color: scheme.error))),
          Slider(
            value: _position.inMilliseconds.toDouble().clamp(0.0, maxMs),
            max: maxMs,
            onChanged: (v) => _player.seek(Duration(milliseconds: v.round())),
          ),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(formatDuration(_position)),
            Text('-${formatDuration(_duration - _position)}'),
          ]),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            IconButton(iconSize: 36, onPressed: () => _skip(-10), icon: const Icon(Icons.replay_10)),
            IconButton.filled(
              iconSize: 48,
              onPressed: _error == null ? _toggle : null,
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(playing ? Icons.pause : Icons.play_arrow, key: ValueKey(playing)),
              ),
            ),
            IconButton(iconSize: 36, onPressed: () => _skip(10), icon: const Icon(Icons.forward_10)),
          ]),
          const SizedBox(height: 8),
          SegmentedButton<double>(
            segments: const [
              ButtonSegment(value: 0.5, label: Text('0.5x')),
              ButtonSegment(value: 1, label: Text('1x')),
              ButtonSegment(value: 1.5, label: Text('1.5x')),
              ButtonSegment(value: 2, label: Text('2x')),
            ],
            selected: {_rate},
            onSelectionChanged: (s) {
              setState(() => _rate = s.first);
              _player.setPlaybackRate(_rate);
            },
          ),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            TextButton.icon(
              onPressed: () => SharePlus.instance.share(ShareParams(
                  files: [XFile(context.read<GalleryProvider>().fileFor(widget.item).path)])),
              icon: const Icon(Icons.ios_share),
              label: const Text('Exportar'),
            ),
            TextButton.icon(
              onPressed: () => showMediaDetails(context, widget.item),
              icon: const Icon(Icons.sell_outlined),
              label: const Text('Etiquetas y álbum'),
            ),
          ]),
        ]),
      ),
    );
  }
}
