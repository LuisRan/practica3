import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../services/image_processing.dart';
import '../../services/permission_service.dart';
import '../providers/gallery_provider.dart';

/// Cámara: vista previa con filtro EN VIVO (ColorFiltered), flash, temporizador,
/// zoom con pinza, doble toque para cambiar de cámara y animación de obturador.
/// Si no hay cámara (simulador de iOS) se ofrece la fototeca como fuente alternativa.
class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> with WidgetsBindingObserver {
  List<CameraDescription> _cameras = [];
  CameraController? _controller;
  int _cameraIndex = 0;
  bool _initializing = true;
  bool _permissionDenied = false;
  String? _error;

  FlashMode _flash = FlashMode.auto;
  PhotoFilter _filter = PhotoFilter.none;
  int _timerSeconds = 0;
  int? _countdown;
  Timer? _countdownTimer;
  bool _shutter = false;
  bool _saving = false;

  double _minZoom = 1, _maxZoom = 1, _zoom = 1, _baseZoom = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setup();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _countdownTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  /// Libera la cámara al pasar a segundo plano y la recupera al volver.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (state == AppLifecycleState.inactive) {
      _controller = null;
      controller?.dispose();
      if (mounted) setState(() {});
    } else if (state == AppLifecycleState.resumed && controller == null && _cameras.isNotEmpty) {
      _startCamera(_cameras[_cameraIndex]);
    }
  }

  Future<void> _setup() async {
    final granted = await PermissionService.ensure(
        context, Permission.camera, 'La app necesita la cámara para tomar fotos.');
    if (!mounted) return;
    if (!granted) {
      setState(() {
        _permissionDenied = true;
        _initializing = false;
      });
      return;
    }
    try {
      _cameras = await availableCameras();
    } on CameraException catch (e) {
      _error = e.description;
    }
    if (!mounted) return;
    if (_cameras.isEmpty) {
      setState(() => _initializing = false); // simulador: sin cámara
      return;
    }
    await _startCamera(_cameras[_cameraIndex]);
  }

  Future<void> _startCamera(CameraDescription description) async {
    final controller = CameraController(description, ResolutionPreset.high, enableAudio: false);
    try {
      await controller.initialize();
      await controller.setFlashMode(_flash);
      _minZoom = await controller.getMinZoomLevel();
      _maxZoom = (await controller.getMaxZoomLevel()).clamp(1.0, 8.0);
      _zoom = _minZoom;
    } on CameraException catch (e) {
      _error = e.code == 'CameraAccessDenied' ? 'Permiso de cámara denegado.' : e.description;
    }
    if (!mounted) {
      await controller.dispose();
      return;
    }
    setState(() {
      _controller = controller;
      _initializing = false;
    });
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return;
    _cameraIndex = (_cameraIndex + 1) % _cameras.length;
    final old = _controller;
    setState(() => _controller = null);
    await old?.dispose();
    await _startCamera(_cameras[_cameraIndex]);
  }

  Future<void> _cycleFlash() async {
    final next = switch (_flash) {
      FlashMode.auto => FlashMode.always,
      FlashMode.always => FlashMode.off,
      FlashMode.off => FlashMode.torch,
      FlashMode.torch => FlashMode.auto,
    };
    try {
      await _controller?.setFlashMode(next);
      setState(() => _flash = next);
    } on CameraException catch (e) {
      _showSnack('Flash no disponible: ${e.description}');
    }
  }

  void _shutterPressed() {
    if (_countdown != null) {
      _countdownTimer?.cancel();
      setState(() => _countdown = null);
      return;
    }
    if (_timerSeconds == 0) {
      _takePicture();
      return;
    }
    setState(() => _countdown = _timerSeconds);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_countdown! <= 1) {
        t.cancel();
        setState(() => _countdown = null);
        _takePicture();
      } else {
        setState(() => _countdown = _countdown! - 1);
      }
    });
  }

  Future<void> _takePicture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || controller.value.isTakingPicture) return;
    HapticFeedback.mediumImpact();
    setState(() => _shutter = true);
    Future.delayed(const Duration(milliseconds: 120), () {
      if (mounted) setState(() => _shutter = false);
    });
    try {
      final file = await controller.takePicture();
      final bytes = await file.readAsBytes();
      await _save(bytes);
      unawaited(File(file.path).delete().catchError((_) => File(file.path)));
    } on CameraException catch (e) {
      _showSnack('Error al capturar: ${e.description}');
    }
  }

  Future<void> _pickFromLibrary() async {
    final picker = ImagePicker();
    final images = await picker.pickMultiImage(imageQuality: 95);
    for (final x in images) {
      await _save(await x.readAsBytes());
    }
  }

  Future<void> _save(List<int> bytes) async {
    setState(() => _saving = true);
    try {
      final gallery = context.read<GalleryProvider>();
      await gallery.capturePhoto(Uint8List.fromList(bytes), _filter);
      _showSnack('Foto guardada${_filter == PhotoFilter.none ? '' : ' con filtro ${_filter.label}'}');
    } catch (e) {
      _showSnack('No se pudo guardar: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildPreview(),
          // Destello del obturador
          IgnorePointer(
            child: AnimatedOpacity(
              opacity: _shutter ? 0.85 : 0,
              duration: const Duration(milliseconds: 90),
              child: const ColoredBox(color: Colors.white),
            ),
          ),
          if (_countdown != null)
            Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                child: Text('$_countdown',
                    key: ValueKey(_countdown),
                    style: const TextStyle(fontSize: 120, color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          if (_saving) const Center(child: CircularProgressIndicator()),
          SafeArea(
            child: Column(
              children: [
                _topBar(),
                const Spacer(),
                _filterStrip(scheme),
                _bottomBar(scheme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    if (_initializing) return const Center(child: CircularProgressIndicator());
    if (_permissionDenied) {
      return _message(Icons.no_photography, 'Sin acceso a la cámara',
          'Concede el permiso desde los ajustes del sistema. Mientras tanto puedes importar desde la galería.');
    }
    final controller = _controller;
    if (_cameras.isEmpty || controller == null || !controller.value.isInitialized) {
      return _message(Icons.phone_iphone, 'Cámara no disponible',
          _error ?? 'El simulador de iOS no tiene cámara. Usa la galería/fototeca como fuente alternativa; el filtro seleccionado se aplicará al importar.',
          action: FilledButton.icon(
            onPressed: _pickFromLibrary,
            icon: const Icon(Icons.photo_library),
            label: const Text('Elegir de la galería'),
          ));
    }
    return GestureDetector(
      onScaleStart: (_) => _baseZoom = _zoom,
      onScaleUpdate: (d) async {
        final z = (_baseZoom * d.scale).clamp(_minZoom, _maxZoom);
        if ((z - _zoom).abs() < 0.01) return;
        _zoom = z;
        await controller.setZoomLevel(z);
        if (mounted) setState(() {});
      },
      onDoubleTap: _switchCamera,
      child: ClipRect(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: 1000,
            height: 1000 * controller.value.aspectRatio,
            child: ColorFiltered(
              colorFilter: ColorFilter.matrix(_filter.matrix),
              child: CameraPreview(controller),
            ),
          ),
        ),
      ),
    );
  }

  Widget _message(IconData icon, String title, String text, {Widget? action}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 64, color: Colors.white),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
          if (action != null) ...[const SizedBox(height: 16), action],
        ]),
      ),
    );
  }

  Widget _topBar() {
    final flashIcon = switch (_flash) {
      FlashMode.auto => Icons.flash_auto,
      FlashMode.always => Icons.flash_on,
      FlashMode.off => Icons.flash_off,
      FlashMode.torch => Icons.highlight,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Flash',
            onPressed: _controller == null ? null : _cycleFlash,
            icon: Icon(flashIcon, color: _flash == FlashMode.off ? Colors.white : Colors.amber),
          ),
          TextButton.icon(
            onPressed: () => setState(() => _timerSeconds = switch (_timerSeconds) { 0 => 3, 3 => 10, _ => 0 }),
            icon: Icon(Icons.timer, color: _timerSeconds > 0 ? Colors.amber : Colors.white),
            label: Text(_timerSeconds == 0 ? 'Off' : '${_timerSeconds}s',
                style: TextStyle(color: _timerSeconds > 0 ? Colors.amber : Colors.white)),
          ),
          const Spacer(),
          if (_zoom > _minZoom + 0.05)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
              child: Text('${_zoom.toStringAsFixed(1)}x', style: const TextStyle(color: Colors.white)),
            ),
        ],
      ),
    );
  }

  Widget _filterStrip(ColorScheme scheme) {
    return SizedBox(
      height: 76,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: PhotoFilter.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final f = PhotoFilter.values[i];
          final selected = f == _filter;
          return GestureDetector(
            onTap: () => setState(() => _filter = f),
            child: Column(children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: selected ? 46 : 40,
                height: selected ? 46 : 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: selected ? scheme.primary : Colors.white54, width: selected ? 3 : 1),
                ),
                child: ClipOval(
                  child: ColorFiltered(
                    colorFilter: ColorFilter.matrix(f.matrix),
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [Color(0xFF6F1D46), Color(0xFFE0A030), Color(0xFF005B9F)]),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(f.label, style: const TextStyle(color: Colors.white, fontSize: 11)),
            ]),
          );
        },
      ),
    );
  }

  Widget _bottomBar(ColorScheme scheme) {
    final gallery = context.watch<GalleryProvider>();
    final last = gallery.lastPhoto;
    final canShoot = _controller?.value.isInitialized ?? false;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: last == null
                ? const DecoratedBox(decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.all(Radius.circular(10))))
                : FutureBuilder<File?>(
                    future: gallery.thumbnailFor(last),
                    builder: (_, snap) => ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: snap.data == null
                          ? const ColoredBox(color: Colors.white24)
                          : Image.file(snap.data!, fit: BoxFit.cover),
                    ),
                  ),
          ),
          GestureDetector(
            onTap: canShoot ? _shutterPressed : null,
            child: AnimatedScale(
              scale: _shutter ? 0.9 : 1,
              duration: const Duration(milliseconds: 100),
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 5),
                ),
                padding: const EdgeInsets.all(6),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: canShoot ? scheme.primary : Colors.grey,
                  ),
                  child: _countdown != null ? const Icon(Icons.close, color: Colors.white) : null,
                ),
              ),
            ),
          ),
          Column(mainAxisSize: MainAxisSize.min, children: [
            IconButton(
              tooltip: 'Cambiar cámara',
              onPressed: _cameras.length > 1 ? _switchCamera : null,
              icon: const Icon(Icons.cameraswitch, color: Colors.white),
            ),
            IconButton(
              tooltip: 'Importar de la galería',
              onPressed: _pickFromLibrary,
              icon: const Icon(Icons.photo_library_outlined, color: Colors.white),
            ),
          ]),
        ],
      ),
    );
  }
}
