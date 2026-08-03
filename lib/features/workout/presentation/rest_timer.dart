import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';

const _color = AppColors.workout;

/// Pilihan cepat yang mencakup rentang umum: superset/isolasi (45-60 detik),
/// compound sedang (90-120), dan angkatan berat (180).
const kRestPresets = [45, 60, 90, 120, 180];

const int kDefaultRestSeconds = 90;
const String _prefsKey = 'rest_timer_seconds';

/// Batas atas supaya nilai dari database atau tombol +15 tidak bisa membuat
/// countdown yang praktis tidak pernah selesai.
const int _maxRestSeconds = 60 * 30;

/// Timer istirahat antar set.
///
/// Sengaja dimiliki oleh halaman form workout, bukan provider global: timernya
/// milik sesi yang sedang dicatat. Kalau halamannya ditutup, istirahatnya
/// memang sudah tidak relevan.
class RestTimerController extends ChangeNotifier {
  Timer? _ticker;
  Timer? _autoHide;

  int _total = kDefaultRestSeconds;
  int _remaining = 0;
  bool _running = false;
  bool _finished = false;
  String? _label;

  int get total => _total;
  int get remaining => _remaining;
  bool get running => _running;

  /// True sesaat setelah hitungan mencapai nol, supaya bar bisa menampilkan
  /// penanda "selesai" alih-alih langsung hilang tanpa jejak.
  bool get finished => _finished;

  bool get visible => _running || _finished;

  /// Nama latihan yang sedang diistirahatkan, kalau timernya dimulai dari kartu.
  String? get label => _label;

  double get progress => _total == 0 ? 0 : (_total - _remaining) / _total;

  /// Durasi terakhir yang dipakai, diingat lintas sesi lewat SharedPreferences.
  static Future<int> loadLastDuration() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt(_prefsKey);
    if (saved == null) return kDefaultRestSeconds;
    return saved.clamp(1, _maxRestSeconds);
  }

  static Future<void> _saveLastDuration(int seconds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefsKey, seconds);
  }

  void start(int seconds, {String? label}) {
    final clamped = seconds.clamp(1, _maxRestSeconds);
    _autoHide?.cancel();
    _ticker?.cancel();

    _total = clamped;
    _remaining = clamped;
    _running = true;
    _finished = false;
    _label = label;
    notifyListeners();

    unawaited(_saveLastDuration(clamped));
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (_remaining <= 1) {
      _finish();
      return;
    }
    _remaining -= 1;
    notifyListeners();
  }

  void _finish() {
    _ticker?.cancel();
    _ticker = null;
    _remaining = 0;
    _running = false;
    _finished = true;
    notifyListeners();

    unawaited(_alert());
    // Bar penanda selesai menghilang sendiri supaya tidak menutupi form
    // kalau user sudah keburu lanjut ke set berikutnya.
    _autoHide = Timer(const Duration(seconds: 8), stop);
  }

  /// Getar plus bunyi, diulang tiga kali. Satu getaran pendek gampang terlewat
  /// kalau HP-nya ditaruh di lantai gym.
  Future<void> _alert() async {
    for (var i = 0; i < 3; i++) {
      if (i > 0) await Future<void>.delayed(const Duration(milliseconds: 400));
      await HapticFeedback.heavyImpact();
      await SystemSound.play(SystemSoundType.alert);
    }
  }

  /// Tambah/kurangi waktu saat timer berjalan. Total ikut naik supaya bar
  /// progresnya tidak melompat mundur.
  void adjust(int delta) {
    if (!_running) return;
    final next = (_remaining + delta).clamp(1, _maxRestSeconds);
    if (next > _total) _total = next;
    _remaining = next;
    notifyListeners();
  }

  void stop() {
    _ticker?.cancel();
    _ticker = null;
    _autoHide?.cancel();
    _autoHide = null;
    _running = false;
    _finished = false;
    _label = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _autoHide?.cancel();
    super.dispose();
  }
}

String formatRest(int seconds) {
  final minutes = seconds ~/ 60;
  final rest = seconds % 60;
  if (minutes == 0) return '${rest}d';
  if (rest == 0) return '${minutes}m';
  return '${minutes}m ${rest}d';
}

String _clock(int seconds) {
  final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
  final rest = (seconds % 60).toString().padLeft(2, '0');
  return '$minutes:$rest';
}

/// Bar countdown yang muncul di atas tombol simpan saat timer berjalan.
class RestTimerBar extends StatelessWidget {
  const RestTimerBar({super.key, required this.controller});

  final RestTimerController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (!controller.visible) return const SizedBox.shrink();

        final colorScheme = Theme.of(context).colorScheme;
        final done = controller.finished;

        return Material(
          color: colorScheme.surface,
          child: Container(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.sm,
              AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: (done ? AppColors.dashboard : _color).withValues(alpha: 0.10),
              border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(
                      done ? Icons.check_circle : Icons.timer_outlined,
                      size: 20,
                      color: done ? AppColors.dashboard : _color,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            done ? 'Istirahat selesai' : _clock(controller.remaining),
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: done ? 14 : 20,
                              height: 1.1,
                              fontFeatures: const [FontFeature.tabularFigures()],
                              color: done ? AppColors.dashboard : _color,
                            ),
                          ),
                          Text(
                            controller.label ?? (done ? 'Lanjut set berikutnya' : 'Istirahat'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!done) ...[
                      _AdjustButton(label: '-15', onPressed: () => controller.adjust(-15)),
                      const SizedBox(width: 4),
                      _AdjustButton(label: '+15', onPressed: () => controller.adjust(15)),
                    ],
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      tooltip: done ? 'Tutup' : 'Hentikan istirahat',
                      onPressed: controller.stop,
                    ),
                  ],
                ),
                if (!done) ...[
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: controller.progress,
                      minHeight: 4,
                      backgroundColor: _color.withValues(alpha: 0.15),
                      valueColor: const AlwaysStoppedAnimation(_color),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AdjustButton extends StatelessWidget {
  const _AdjustButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: _color,
          side: BorderSide(color: _color.withValues(alpha: 0.4)),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

/// Sheet pengatur durasi sebelum timer dimulai. Mengembalikan detik yang
/// dipilih, atau null kalau dibatalkan.
Future<int?> showRestPicker(
  BuildContext context, {
  required int initialSeconds,
  String? exerciseName,
}) {
  return showModalBottomSheet<int>(
    context: context,
    showDragHandle: true,
    builder: (context) => _RestPickerSheet(
      initialSeconds: initialSeconds,
      exerciseName: exerciseName,
    ),
  );
}

class _RestPickerSheet extends StatefulWidget {
  const _RestPickerSheet({required this.initialSeconds, this.exerciseName});

  final int initialSeconds;
  final String? exerciseName;

  @override
  State<_RestPickerSheet> createState() => _RestPickerSheetState();
}

class _RestPickerSheetState extends State<_RestPickerSheet> {
  late int _seconds = widget.initialSeconds.clamp(15, _maxRestSeconds);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        MediaQuery.of(context).padding.bottom + AppSpacing.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.timer_outlined, size: 18, color: _color),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Istirahat',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    if (widget.exerciseName != null && widget.exerciseName!.isNotEmpty)
                      Text(
                        widget.exerciseName!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Center(
            child: Text(
              _clock(_seconds),
              style: const TextStyle(
                fontSize: 44,
                fontWeight: FontWeight.w900,
                color: _color,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _AdjustButton(
                label: '-15',
                onPressed: () => setState(() => _seconds = (_seconds - 15).clamp(15, _maxRestSeconds)),
              ),
              const SizedBox(width: AppSpacing.sm),
              _AdjustButton(
                label: '+15',
                onPressed: () => setState(() => _seconds = (_seconds + 15).clamp(15, _maxRestSeconds)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final preset in kRestPresets)
                ChoiceChip(
                  label: Text(formatRest(preset)),
                  selected: _seconds == preset,
                  onSelected: (_) => setState(() => _seconds = preset),
                  selectedColor: _color.withValues(alpha: 0.18),
                  labelStyle: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _seconds == preset ? _color : colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(_seconds),
            style: FilledButton.styleFrom(
              backgroundColor: _color,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: const Icon(Icons.play_arrow),
            label: const Text('Mulai Istirahat'),
          ),
        ],
      ),
    );
  }
}
