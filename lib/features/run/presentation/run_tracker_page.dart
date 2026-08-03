import 'dart:async';

import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../../core/offline/pending_writes.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/hero_header.dart';
import '../../../core/widgets/section_header.dart';
import '../data/run_repository.dart';
import '../domain/geo.dart';
import '../domain/run_stats.dart';

const _color = AppColors.workout;

/// Lokasi hanya tersedia di ponsel. Di web browser bisa saja memberi koordinat,
/// tapi tanpa foreground service pelacakannya berhenti begitu tab tidak aktif —
/// jadi lebih jujur menyatakan fiturnya khusus HP.
bool get runTrackingSupported {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
}

enum _TrackerState { siap, berjalan, jeda }

class RunTrackerPage extends ConsumerStatefulWidget {
  const RunTrackerPage({super.key});

  @override
  ConsumerState<RunTrackerPage> createState() => _RunTrackerPageState();
}

class _RunTrackerPageState extends ConsumerState<RunTrackerPage> {
  final RunRecorder _recorder = RunRecorder();

  /// Hanya berjalan saat status `berjalan`, jadi waktu jeda tidak ikut terhitung
  /// dan pace-mu tidak rusak gara-gara berhenti di lampu merah.
  final Stopwatch _clock = Stopwatch();

  StreamSubscription<Position>? _subscription;
  Timer? _ticker;

  _TrackerState _state = _TrackerState.siap;
  DateTime? _startedAt;
  double? _lastAccuracy;
  String? _error;
  bool _saving = false;
  bool _busy = false;

  @override
  void dispose() {
    _subscription?.cancel();
    _ticker?.cancel();
    super.dispose();
  }

  int get _elapsedSeconds => _clock.elapsed.inSeconds;

  /// Meminta izin lokasi sekaligus memastikan GPS-nya menyala.
  ///
  /// Dua hal berbeda yang sering tertukar: izin diberikan user, layanan lokasi
  /// dinyalakan di setelan sistem. Punya izin tapi GPS mati tetap tidak dapat
  /// koordinat apa pun.
  Future<String?> _ensureReady() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return 'GPS belum aktif. Nyalakan lokasi di setelan HP.';
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      return 'Izin lokasi ditolak.';
    }
    if (permission == LocationPermission.deniedForever) {
      return 'Izin lokasi diblokir permanen. Aktifkan lewat Pengaturan aplikasi.';
    }
    return null;
  }

  LocationSettings get _settings {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        // Penyaringan sesungguhnya ada di RunRecorder; di sini sengaja longgar
        // supaya titik yang berguna tidak dibuang sebelum sempat dinilai.
        distanceFilter: 0,
        intervalDuration: const Duration(seconds: 1),
        // Tanpa foreground service, Android mencekik update lokasi begitu layar
        // mati — justru kondisi normal saat lari.
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Merekam lari',
          notificationText: 'Tracking berjalan di latar belakang',
          notificationChannelName: 'Perekaman lari',
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 0,
    );
  }

  Future<void> _start() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    final problem = await _ensureReady();
    if (!mounted) return;
    if (problem != null) {
      setState(() {
        _error = problem;
        _busy = false;
      });
      return;
    }

    _startedAt = DateTime.now();
    _clock.start();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });

    _subscription = Geolocator.getPositionStream(locationSettings: _settings)
        .listen(_onPosition, onError: _onStreamError);

    setState(() {
      _state = _TrackerState.berjalan;
      _busy = false;
    });
  }

  void _onPosition(Position position) {
    if (_state != _TrackerState.berjalan) return;

    final hasil = _recorder.add(
      lat: position.latitude,
      lng: position.longitude,
      accuracy: position.accuracy,
      elapsedMs: _clock.elapsedMilliseconds,
    );

    setState(() {
      _lastAccuracy = position.accuracy;
      // Rebuild untuk menyegarkan jarak; hasilnya sendiri sudah tersimpan di
      // dalam recorder.
      if (hasil.isAccepted) {}
    });
  }

  void _onStreamError(Object error) {
    if (!mounted) return;
    setState(() => _error = 'Sinyal lokasi bermasalah: $error');
  }

  void _pause() {
    _clock.stop();
    setState(() => _state = _TrackerState.jeda);
  }

  void _resume() {
    // Perpindahan selama jeda bukan bagian dari lari.
    _recorder.markGap();
    _clock.start();
    setState(() => _state = _TrackerState.berjalan);
  }

  Future<void> _finish() async {
    final startedAt = _startedAt;
    if (startedAt == null) return;

    _clock.stop();
    await _subscription?.cancel();
    _subscription = null;
    _ticker?.cancel();
    _ticker = null;

    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);

    if (_recorder.distanceMeters < 10) {
      final buang = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Jarak terlalu pendek'),
          content: const Text(
            'Belum ada perpindahan yang terekam. Simpan lari sepanjang ini '
            'tidak banyak gunanya — buang saja?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Tetap simpan'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Buang'),
            ),
          ],
        ),
      );
      if (buang == true) {
        if (mounted) context.pop();
        return;
      }
    }

    final userId = ref.read(currentUserProvider)?.id;
    if (userId == null) return;

    setState(() => _saving = true);
    try {
      final terkirim = await ref.read(runRepositoryProvider).addRun(
            userId: userId,
            run: RunLog(
              id: '',
              startedAt: startedAt,
              durationSeconds: _elapsedSeconds,
              distanceMeters: _recorder.distanceMeters,
              route: _recorder.points,
            ),
            queue: ref.read(pendingWriteQueueProvider),
          );
      ref.invalidate(runsProvider);
      ref.invalidate(pendingWritesProvider);
      if (!terkirim) {
        // Larinya tersimpan di HP, bukan hilang. Ini harus dikatakan, bukan
        // dibiarkan terlihat seperti berhasil terkirim.
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Tidak ada sinyal — larimu disimpan di HP dan '
                'dikirim otomatis nanti.'),
            duration: Duration(seconds: 5),
          ),
        );
      }
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Gagal menyimpan: $e';
        });
      }
    }
  }

  Future<bool> _confirmLeave() async {
    if (_state == _TrackerState.siap) return true;

    final keluar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hentikan perekaman?'),
        content: const Text('Lari yang belum disimpan akan hilang.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Lanjut lari'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Buang'),
          ),
        ],
      ),
    );
    return keluar ?? false;
  }

  @override
  Widget build(BuildContext context) {
    if (!runTrackingSupported) {
      return Scaffold(
        appBar: AppBar(title: const Text('Lari')),
        body: const Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: EmptyState(
            icon: Icons.phone_android,
            title: 'Hanya bisa di HP',
            subtitle: 'Perekaman lari butuh GPS dan layanan latar belakang '
                'yang tidak tersedia di browser.',
            color: _color,
          ),
        ),
      );
    }

    final pace = paceSecondsPerKm(
      distanceMeters: _recorder.distanceMeters,
      seconds: _elapsedSeconds,
    );

    return PopScope(
      canPop: _state == _TrackerState.siap,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmLeave() && context.mounted) context.pop();
      },
      child: Scaffold(
        body: ListView(
          padding: EdgeInsets.zero,
          children: [
            HeroHeader.sub(
              title: 'Lari',
              subtitle: switch (_state) {
                _TrackerState.siap => 'Tekan mulai saat kamu siap berangkat',
                _TrackerState.berjalan => 'Sedang merekam',
                _TrackerState.jeda => 'Dijeda — waktu berhenti berjalan',
              },
              color: _color,
              leading: HeroIconButton(
                icon: Icons.arrow_back,
                tooltip: 'Kembali',
                onPressed: () async {
                  if (await _confirmLeave() && context.mounted) context.pop();
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_error != null) ...[
                    Card(
                      color: Theme.of(context).colorScheme.errorContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 18,
                              color: Theme.of(context).colorScheme.onErrorContainer,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                _error!,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Theme.of(context).colorScheme.onErrorContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  _BigStat(
                    value: formatDistance(_recorder.distanceMeters),
                    label: 'Jarak',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: _SmallStat(
                          value: formatDuration(_elapsedSeconds),
                          label: 'Waktu Bergerak',
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _SmallStat(
                          value: pace == null ? '-' : '${formatPace(pace)} /km',
                          label: 'Pace',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _SignalCard(
                    accuracy: _lastAccuracy,
                    points: _recorder.points.length,
                    running: _state == _TrackerState.berjalan,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _Controls(
                    state: _state,
                    busy: _busy,
                    saving: _saving,
                    onStart: _start,
                    onPause: _pause,
                    onResume: _resume,
                    onFinish: _finish,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const SectionHeader(
                    title: 'Catatan',
                    icon: Icons.info_outline,
                    color: _color,
                  ),
                  Text(
                    'Waktu berhenti tidak dihitung, jadi jeda di lampu merah '
                    'tidak merusak pace-mu. Titik GPS dengan ketidakpastian di '
                    'atas 30 meter dibuang, dan perpindahan di bawah 5 meter '
                    'dianggap goyangan sinyal — tanpa itu berdiri diam pun bisa '
                    'terhitung menempuh ratusan meter.\n\n'
                    'Elevasi sengaja tidak dicatat: ketinggian dari GPS meleset '
                    '10-15 meter, jadi "total tanjakan" darinya hanya karangan.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BigStat extends StatelessWidget {
  const _BigStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 46,
                fontWeight: FontWeight.w900,
                color: _color,
                height: 1,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SmallStat extends StatelessWidget {
  const _SmallStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Menunjukkan kualitas sinyal, supaya saat jaraknya tidak bertambah kamu tahu
/// penyebabnya sinyal buruk — bukan aplikasinya rusak.
class _SignalCard extends StatelessWidget {
  const _SignalCard({
    required this.accuracy,
    required this.points,
    required this.running,
  });

  final double? accuracy;
  final int points;
  final bool running;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final acc = accuracy;

    final (Color color, String label) = switch (acc) {
      null => (colorScheme.onSurfaceVariant, running ? 'Mencari sinyal...' : 'Belum mulai'),
      final a when a <= 10 => (AppColors.statusDone, 'Sinyal bagus'),
      final a when a <= 30 => (AppColors.priorityMedium, 'Sinyal sedang'),
      _ => (AppColors.priorityHigh, 'Sinyal buruk — titik dibuang'),
    };

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Icon(Icons.satellite_alt_outlined, size: 18, color: color),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color),
              ),
            ),
            if (acc != null)
              Text(
                '±${acc.round()} m  ·  $points titik',
                style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
              ),
          ],
        ),
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.state,
    required this.busy,
    required this.saving,
    required this.onStart,
    required this.onPause,
    required this.onResume,
    required this.onFinish,
  });

  final _TrackerState state;
  final bool busy;
  final bool saving;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    if (state == _TrackerState.siap) {
      return FilledButton.icon(
        onPressed: busy ? null : onStart,
        style: FilledButton.styleFrom(
          backgroundColor: _color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        icon: busy
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.play_arrow),
        label: Text(busy ? 'Menyiapkan GPS...' : 'Mulai Lari'),
      );
    }

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: saving
                ? null
                : (state == _TrackerState.berjalan ? onPause : onResume),
            style: OutlinedButton.styleFrom(
              foregroundColor: _color,
              side: const BorderSide(color: _color),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: Icon(state == _TrackerState.berjalan ? Icons.pause : Icons.play_arrow),
            label: Text(state == _TrackerState.berjalan ? 'Jeda' : 'Lanjut'),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: FilledButton.icon(
            onPressed: saving ? null : onFinish,
            style: FilledButton.styleFrom(
              backgroundColor: _color,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: saving
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.stop),
            label: Text(saving ? 'Menyimpan...' : 'Selesai'),
          ),
        ),
      ],
    );
  }
}
