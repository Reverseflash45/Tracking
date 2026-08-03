import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/hero_header.dart';
import '../domain/guided_exercise.dart';
import '../domain/pose_geometry.dart';
import '../domain/rep_counter.dart';
import 'pose_painter.dart';

const _color = AppColors.workout;

/// Fitur ini butuh kamera dan ML Kit, yang keduanya hanya tersedia di ponsel.
/// Di web dan desktop halamannya menjelaskan itu alih-alih gagal saat dibuka.
bool get liveWorkoutSupported {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
}

class LiveWorkoutPage extends StatelessWidget {
  const LiveWorkoutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          HeroHeader.sub(
            title: 'Latihan Terpandu',
            subtitle: 'Kamera menghitung repetisimu',
            color: _color,
            leading: HeroIconButton(
              icon: Icons.arrow_back,
              tooltip: 'Kembali',
              onPressed: () => context.pop(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: liveWorkoutSupported
                ? const _ExercisePicker()
                : const EmptyState(
                    icon: Icons.phone_android,
                    title: 'Hanya bisa di HP',
                    subtitle: 'Fitur ini memakai kamera dan deteksi pose '
                        'on-device, yang tidak tersedia di browser.',
                    color: _color,
                  ),
          ),
        ],
      ),
    );
  }
}

class _ExercisePicker extends StatelessWidget {
  const _ExercisePicker();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          color: _color.withValues(alpha: 0.08),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, size: 18, color: _color),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Sandarkan HP 2-3 meter darimu sampai seluruh badan masuk '
                    'frame. Kamera depan atau belakang sama saja — ganti lewat '
                    'ikon di atas layar. Kalau kerangkanya tampak terbalik, '
                    'tekan ikon balik di sebelahnya.\n\n'
                    'Lima gerakan ini dipilih karena sudutnya terbaca andal '
                    'dari satu kamera; bench press dan pull up tidak masuk '
                    'karena tubuhnya saling menutupi di tengah gerakan.',
                    style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        for (final exercise in guidedExercises)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => _LiveSessionPage(exercise: exercise),
                  ),
                ),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(exercise.icon, size: 18, color: _color),
                ),
                title: Text(
                  exercise.name,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                subtitle: Text(
                  exercise.cue,
                  style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                ),
                trailing: const Icon(Icons.chevron_right),
              ),
            ),
          ),
      ],
    );
  }
}

/// Peta orientasi perangkat ke derajat, dipakai menghitung rotasi gambar.
const _orientationDegrees = {
  DeviceOrientation.portraitUp: 0,
  DeviceOrientation.landscapeLeft: 90,
  DeviceOrientation.portraitDown: 180,
  DeviceOrientation.landscapeRight: 270,
};

class _LiveSessionPage extends StatefulWidget {
  const _LiveSessionPage({required this.exercise});

  final GuidedExercise exercise;

  @override
  State<_LiveSessionPage> createState() => _LiveSessionPageState();
}

/// Preferensi kamera disimpan supaya kamu tidak perlu mengatur ulang tiap sesi
/// — cara menyandarkan HP biasanya sama terus.
const _prefsLens = 'live_camera_lens';
const _prefsMirror = 'live_camera_mirror';

class _LiveSessionPageState extends State<_LiveSessionPage> with WidgetsBindingObserver {
  CameraController? _controller;
  CameraDescription? _camera;
  PoseDetector? _detector;
  late final RepCounter _counter = widget.exercise.newCounter();

  List<CameraDescription> _cameras = const [];

  /// Arah lensa yang diminta. Dibaca dari preferensi, jatuh ke belakang kalau
  /// belum pernah diatur.
  CameraLensDirection _lens = CameraLensDirection.back;

  /// Apakah koordinat titik perlu dibalik horizontal supaya kerangkanya
  /// menempel di badan.
  ///
  /// Sengaja tombol, bukan ditebak dari arah lensa: `CameraPreview` tidak
  /// mencerminkan apa pun di sisi Dart, jadi tercermin atau tidaknya preview
  /// kamera depan ditentukan lapisan native dan berbeda antar perangkat.
  bool _mirror = false;

  /// Frame diproses satu per satu. Tanpa ini, antrean frame menumpuk lebih
  /// cepat daripada bisa dihabiskan dan aplikasinya kehabisan memori.
  bool _busy = false;

  Pose? _pose;
  Size _imageSize = Size.zero;
  bool _visible = false;
  List<String> _warnings = const [];
  String? _lastFeedback;
  String? _error;
  bool _starting = true;

  final Stopwatch _clock = Stopwatch();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _restorePreferences().then((_) => _start());
  }

  Future<void> _restorePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final lens = prefs.getString(_prefsLens);
    if (!mounted) return;
    _lens = lens == 'front' ? CameraLensDirection.front : CameraLensDirection.back;
    _mirror = prefs.getBool(_prefsMirror) ?? false;
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsLens,
      _lens == CameraLensDirection.front ? 'front' : 'back',
    );
    await prefs.setBool(_prefsMirror, _mirror);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Kamera harus dilepas saat aplikasi ke belakang, kalau tidak sistem
    // merebutnya paksa dan preview-nya hitam saat kembali.
    if (state == AppLifecycleState.inactive) {
      _stop();
    } else if (state == AppLifecycleState.resumed && _controller == null) {
      _start();
    }
  }

  Future<void> _start() async {
    try {
      final cameras = await availableCameras();
      if (!mounted) return;
      if (cameras.isEmpty) {
        setState(() {
          _error = 'Tidak ada kamera yang terdeteksi di perangkat ini.';
          _starting = false;
        });
        return;
      }

      _cameras = cameras;

      // Pakai lensa yang kamu pilih terakhir kali; kalau perangkatnya tidak
      // punya, ambil apa pun yang ada daripada gagal total.
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == _lens,
        orElse: () => cameras.first,
      );
      _lens = camera.lensDirection;

      final controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
        // NV21 bisa langsung dimakan ML Kit tanpa konversi manual antar plane.
        imageFormatGroup: ImageFormatGroup.nv21,
      );

      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }

      if (!controller.supportsImageStreaming()) {
        await controller.dispose();
        setState(() {
          _error = 'Perangkat ini tidak mendukung analisis frame kamera.';
          _starting = false;
        });
        return;
      }

      _detector = PoseDetector(
        options: PoseDetectorOptions(
          // Model base, bukan accurate: accurate dirancang untuk foto diam dan
          // terlalu lambat untuk menghitung repetisi secara langsung.
          model: PoseDetectionModel.base,
          mode: PoseDetectionMode.stream,
        ),
      );

      _camera = camera;
      _controller = controller;
      _clock.start();
      setState(() => _starting = false);

      await controller.startImageStream(_onFrame);
    } on CameraException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.code == 'CameraAccessDenied'
            ? 'Izin kamera ditolak. Aktifkan lewat Pengaturan aplikasi.'
            : 'Kamera gagal dibuka: ${e.description ?? e.code}';
        _starting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal memulai: $e';
        _starting = false;
      });
    }
  }

  Future<void> _stop() async {
    _clock.stop();
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      if (controller.value.isStreamingImages) {
        await controller.stopImageStream().catchError((_) {});
      }
      await controller.dispose();
    }
    await _detector?.close();
    _detector = null;
  }

  InputImage? _toInputImage(CameraImage image) {
    final camera = _camera;
    final controller = _controller;
    if (camera == null || controller == null) return null;

    final compensation = _orientationDegrees[controller.value.deviceOrientation] ?? 0;
    final int rotationDegrees;
    if (camera.lensDirection == CameraLensDirection.front) {
      rotationDegrees = (camera.sensorOrientation + compensation) % 360;
    } else {
      rotationDegrees = (camera.sensorOrientation - compensation + 360) % 360;
    }

    final rotation = InputImageRotationValue.fromRawValue(rotationDegrees);
    if (rotation == null) return null;

    // Dicek lewat `group`, bukan lewat konstanta angka di `format.raw`, karena
    // `raw` bertipe dynamic dan nilainya berbeda antara Android dan iOS.
    // NV21 datang sebagai satu plane, persis bentuk yang diminta ML Kit.
    if (image.format.group != ImageFormatGroup.nv21 || image.planes.length != 1) {
      return null;
    }
    final plane = image.planes.first;

    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: InputImageFormat.nv21,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  Future<void> _onFrame(CameraImage image) async {
    if (_busy || !mounted) return;
    _busy = true;

    try {
      final input = _toInputImage(image);
      final detector = _detector;
      if (input == null || detector == null) return;

      final poses = await detector.processImage(input);
      if (!mounted) return;

      final pose = poses.isEmpty ? null : poses.first;
      _consume(pose, image);
    } catch (_) {
      // Satu frame gagal bukan alasan menghentikan sesi; frame berikutnya
      // biasanya sudah normal lagi.
    } finally {
      _busy = false;
    }
  }

  void _consume(Pose? pose, CameraImage image) {
    // Ukuran gambar sesudah rotasi: potret menukar sisi panjang dan pendek.
    // Diambil di kedua cabang supaya kerangka tetap tergambar saat badanmu
    // baru sebagian masuk frame — justru saat itulah overlay paling berguna
    // untuk membetulkan posisi HP.
    final rotatedSize = Size(image.height.toDouble(), image.width.toDouble());

    if (pose == null || !bodyVisible(pose)) {
      // Jangan biarkan gerakan yang tidak terlihat menyambung jadi repetisi.
      _counter.interrupt();
      setState(() {
        _pose = pose;
        _imageSize = rotatedSize;
        _visible = false;
        _warnings = const [];
      });
      return;
    }

    final reading = readBestSide(pose, widget.exercise.joint);
    RepEvent? event;
    if (reading != null && reading.reliable) {
      event = _counter.update(reading.degrees, nowMs: _clock.elapsedMilliseconds);
    }

    final warnings = widget.exercise.postureWarnings(pose);

    if (event != null) {
      HapticFeedback.selectionClick();
      final depth = widget.exercise.depthWarning(event);
      _lastFeedback = depth ?? (warnings.isNotEmpty ? warnings.first : 'Bagus');
    }

    setState(() {
      _pose = pose;
      _visible = true;
      _warnings = warnings;
      _imageSize = rotatedSize;
    });
  }

  /// True kalau perangkat punya lebih dari satu arah lensa untuk dipilih.
  bool get _canSwitchCamera =>
      _cameras.map((c) => c.lensDirection).toSet().length > 1;

  Future<void> _switchCamera() async {
    if (!_canSwitchCamera) return;

    _lens = _lens == CameraLensDirection.back
        ? CameraLensDirection.front
        : CameraLensDirection.back;

    // Hitungan repetisi sengaja dipertahankan — kamu cuma memindahkan kamera,
    // bukan memulai set baru. Tapi fasenya diputus supaya jeda saat kamera
    // mati tidak tersambung jadi satu repetisi palsu.
    _counter.interrupt();
    setState(() {
      _pose = null;
      _visible = false;
      _warnings = const [];
      _starting = true;
    });

    await _stop();
    unawaited(_savePreferences());
    await _start();
  }

  void _toggleMirror() {
    setState(() => _mirror = !_mirror);
    unawaited(_savePreferences());
  }

  void _reset() {
    setState(() {
      _counter.reset();
      _lastFeedback = null;
    });
  }

  void _finish() {
    Navigator.of(context).pop();
    context.push(
      Uri(
        path: '/workout/new',
        queryParameters: {
          'exercise': widget.exercise.name,
          'type': widget.exercise.type.dbValue,
          'reps': '${_counter.reps}',
        },
      ).toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.exercise.name),
        actions: [
          if (_canSwitchCamera)
            IconButton(
              icon: const Icon(Icons.cameraswitch_outlined),
              tooltip: _lens == CameraLensDirection.back
                  ? 'Pakai kamera depan'
                  : 'Pakai kamera belakang',
              onPressed: _starting ? null : _switchCamera,
            ),
          IconButton(
            icon: Icon(_mirror ? Icons.flip : Icons.flip_outlined),
            tooltip: 'Balik arah kerangka',
            color: _mirror ? _color : null,
            onPressed: _toggleMirror,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Ulang hitungan',
            onPressed: _reset,
          ),
        ],
      ),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: EmptyState(
                  icon: Icons.videocam_off_outlined,
                  title: 'Kamera tidak bisa dipakai',
                  subtitle: _error!,
                  color: _color,
                ),
              ),
            )
          : _starting || controller == null || !controller.value.isInitialized
              ? const Center(child: CircularProgressIndicator(color: _color))
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: controller.value.previewSize?.height ?? 1,
                        height: controller.value.previewSize?.width ?? 1,
                        child: CameraPreview(controller),
                      ),
                    ),
                    CustomPaint(
                      painter: PosePainter(
                        pose: _pose,
                        imageSize: _imageSize,
                        mirror: _mirror,
                        warning: _warnings.isNotEmpty,
                      ),
                    ),
                    _Hud(
                      reps: _counter.reps,
                      angle: _counter.lastAngle,
                      visible: _visible,
                      warnings: _warnings,
                      feedback: _lastFeedback,
                      setup: widget.exercise.setup,
                    ),
                  ],
                ),
      bottomNavigationBar: _error != null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: FilledButton.icon(
                  onPressed: _counter.reps == 0 ? null : _finish,
                  style: FilledButton.styleFrom(
                    backgroundColor: _color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.check),
                  label: Text(
                    _counter.reps == 0
                        ? 'Belum ada repetisi'
                        : 'Simpan ${_counter.reps} rep ke catatan',
                  ),
                ),
              ),
            ),
    );
  }
}

class _Hud extends StatelessWidget {
  const _Hud({
    required this.reps,
    required this.angle,
    required this.visible,
    required this.warnings,
    required this.feedback,
    required this.setup,
  });

  final int reps;
  final double? angle;
  final bool visible;
  final List<String> warnings;
  final String? feedback;
  final String setup;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$reps',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 40,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 5),
                    child: Text(
                      'rep',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ),
                  if (angle != null) ...[
                    const SizedBox(width: 14),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Text(
                        '${angle!.round()}°',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Spacer(),
            if (!visible)
              _Banner(
                icon: Icons.person_search,
                text: 'Badanmu belum terbaca. $setup',
                color: AppColors.priorityMedium,
              )
            else if (warnings.isNotEmpty)
              _Banner(
                icon: Icons.warning_amber_rounded,
                text: warnings.first,
                color: AppColors.priorityHigh,
              )
            else if (feedback != null)
              _Banner(
                icon: Icons.check_circle_outline,
                text: feedback!,
                color: AppColors.statusDone,
              ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.text, required this.color});

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.white),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
