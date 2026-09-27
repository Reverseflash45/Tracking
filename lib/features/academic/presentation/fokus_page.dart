import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../data/models/task.dart';
import 'academic_providers.dart';
import 'task_tile.dart';

/// Jumlah sesi fokus yang sudah selesai per tugas selama app terbuka.
/// Sengaja tidak disimpan ke server: ini penyemangat sesaat, bukan catatan.
final _sesiSelesai = <String, int>{};

enum _Mode { fokus, istirahat }

/// Mode fokus ala Pomodoro untuk satu tugas: hitung mundur dalam cincin
/// besar, lalu tawaran istirahat atau menandai tugasnya selesai.
///
/// Waktunya dihitung dari jam akhir, bukan dari jumlah detak — jadi tetap
/// benar walaupun app sempat ke latar belakang.
class FokusPage extends ConsumerStatefulWidget {
  const FokusPage({super.key, required this.taskId});

  final String taskId;

  @override
  ConsumerState<FokusPage> createState() => _FokusPageState();
}

class _FokusPageState extends ConsumerState<FokusPage> {
  static const _pilihanMenit = [15, 25, 50];

  int _menit = 25;
  _Mode _mode = _Mode.fokus;
  DateTime? _akhir;
  Duration _sisa = const Duration(minutes: 25);
  Timer? _detak;

  bool get _jalan => _akhir != null;
  Duration get _total => Duration(minutes: _mode == _Mode.fokus ? _menit : 5);

  @override
  void dispose() {
    _detak?.cancel();
    super.dispose();
  }

  void _mulai() {
    HapticFeedback.selectionClick();
    setState(() => _akhir = DateTime.now().add(_sisa));
    _detak?.cancel();
    _detak = Timer.periodic(const Duration(milliseconds: 250), (_) => _tik());
  }

  void _jeda() {
    _detak?.cancel();
    setState(() {
      _sisa = _akhir!.difference(DateTime.now());
      _akhir = null;
    });
  }

  void _ulang() {
    _detak?.cancel();
    setState(() {
      _akhir = null;
      _sisa = _total;
    });
  }

  void _tik() {
    final sisa = _akhir!.difference(DateTime.now());
    if (sisa <= Duration.zero) {
      _detak?.cancel();
      setState(() {
        _akhir = null;
        _sisa = Duration.zero;
      });
      _selesai();
      return;
    }
    setState(() => _sisa = sisa);
  }

  Future<void> _selesai() async {
    HapticFeedback.heavyImpact();
    SystemSound.play(SystemSoundType.alert);
    if (_mode == _Mode.istirahat) {
      setState(() {
        _mode = _Mode.fokus;
        _sisa = _total;
      });
      return;
    }
    _sesiSelesai[widget.taskId] = (_sesiSelesai[widget.taskId] ?? 0) + 1;
    if (!mounted) return;
    final pilihan = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.celebration_rounded, color: AppColors.deadline, size: 32),
        title: const Text('Sesi fokus selesai'),
        content: const Text('Istirahat lima menit dulu, atau tugasnya sudah beres?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'beres'),
            child: const Text('Tugas selesai'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'istirahat'),
            child: const Text('Istirahat 5 menit'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (pilihan == 'beres') {
      await ubahStatusTugas(context, ref, widget.taskId, TaskStatus.done);
      if (mounted) context.pop();
      return;
    }
    setState(() {
      _mode = pilihan == 'istirahat' ? _Mode.istirahat : _Mode.fokus;
      _sisa = _total;
    });
    if (pilihan == 'istirahat') _mulai();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tugas = ref
        .watch(tasksTampilProvider)
        .value
        ?.where((t) => t.id == widget.taskId)
        .firstOrNull;
    final warna = _mode == _Mode.fokus ? AppColors.deadline : AppColors.workout;
    final rasio = _total.inMilliseconds == 0
        ? 0.0
        : 1 - _sisa.inMilliseconds / _total.inMilliseconds;
    final menit = _sisa.inMinutes.toString().padLeft(2, '0');
    final detik = (_sisa.inSeconds % 60).toString().padLeft(2, '0');
    final sesi = _sesiSelesai[widget.taskId] ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(_mode == _Mode.fokus ? 'Mode fokus' : 'Istirahat'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            children: [
              if (tugas != null) ...[
                Text(
                  tugas.title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, height: 1.25),
                ),
                const SizedBox(height: 4),
                Text(
                  [tugas.courseName ?? 'Tugas pribadi', countdownLabel(tugas.deadline)].join(' · '),
                  style: TextStyle(fontSize: 13.5, color: colorScheme.onSurfaceVariant),
                ),
              ],
              const Spacer(),
              SizedBox.square(
                dimension: 260,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CustomPaint(
                      painter: _Cincin(
                        rasio: rasio.clamp(0.0, 1.0),
                        warna: warna,
                        jalur: warna.withValues(alpha: 0.14),
                      ),
                    ),
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$menit:$detik',
                            style: const TextStyle(
                              fontSize: 58,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -2,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                          Text(
                            _mode == _Mode.fokus
                                ? (sesi == 0 ? 'Sesi pertama' : 'Sesi ke-${sesi + 1}')
                                : 'Tarik napas, minum air',
                            style: TextStyle(
                              fontSize: 14,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              if (_mode == _Mode.fokus)
                SegmentedButton<int>(
                  segments: [
                    for (final m in _pilihanMenit) ButtonSegment(value: m, label: Text('$m mnt')),
                  ],
                  selected: {_menit},
                  showSelectedIcon: false,
                  onSelectionChanged: _jalan
                      ? null
                      : (s) => setState(() {
                          _menit = s.first;
                          _sisa = _total;
                        }),
                ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton.filledTonal(
                    tooltip: 'Ulang',
                    iconSize: 26,
                    onPressed: _ulang,
                    icon: const Icon(Icons.restart_alt_rounded),
                  ),
                  const SizedBox(width: 24),
                  SizedBox.square(
                    dimension: 84,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: warna,
                        foregroundColor: Colors.white,
                        shape: const CircleBorder(),
                        padding: EdgeInsets.zero,
                      ),
                      onPressed: _sisa <= Duration.zero ? null : (_jalan ? _jeda : _mulai),
                      child: Icon(
                        _jalan ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        size: 44,
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  IconButton.filledTonal(
                    tooltip: 'Lewati',
                    iconSize: 26,
                    onPressed: () {
                      _detak?.cancel();
                      setState(() {
                        _akhir = null;
                        _sisa = Duration.zero;
                      });
                      _selesai();
                    },
                    icon: const Icon(Icons.skip_next_rounded),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Cincin extends CustomPainter {
  _Cincin({required this.rasio, required this.warna, required this.jalur});

  final double rasio;
  final Color warna;
  final Color jalur;

  @override
  void paint(Canvas canvas, Size size) {
    const tebal = 16.0;
    final pusat = size.center(Offset.zero);
    final jari = size.shortestSide / 2 - tebal / 2;
    final kuas = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = tebal
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(pusat, jari, kuas..color = jalur);
    if (rasio > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: pusat, radius: jari),
        -math.pi / 2,
        2 * math.pi * rasio,
        false,
        kuas..color = warna,
      );
    }
  }

  @override
  bool shouldRepaint(_Cincin old) => old.rasio != rasio || old.warna != warna;
}
