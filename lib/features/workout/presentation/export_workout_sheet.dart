import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../run/data/run_repository.dart';
import '../data/models/workout_session.dart';
import '../domain/workout_export.dart';
import 'workout_providers.dart';

const _color = AppColors.workout;

Future<void> showEksporWorkoutSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _EksporWorkoutSheet(),
  );
}

enum _Rentang {
  pekan('7 hari'),
  bulan('30 hari'),
  kuartal('3 bulan'),
  tahunIni('Tahun ini'),
  semua('Semua'),
  pilih('Pilih tanggal');

  const _Rentang(this.label);
  final String label;
}

class _EksporWorkoutSheet extends ConsumerStatefulWidget {
  const _EksporWorkoutSheet();

  @override
  ConsumerState<_EksporWorkoutSheet> createState() => _EksporWorkoutSheetState();
}

class _EksporWorkoutSheetState extends ConsumerState<_EksporWorkoutSheet> {
  _Rentang _rentang = _Rentang.bulan;
  DateTimeRange? _pilihan;
  bool _denganLari = true;

  DateTime get _hariIni {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTimeRange _rentangAktif(List<WorkoutSession> sesi, List<RunLog> lari) {
    final akhir = _hariIni;
    return switch (_rentang) {
      _Rentang.pekan => DateTimeRange(start: akhir.subtract(const Duration(days: 6)), end: akhir),
      _Rentang.bulan => DateTimeRange(start: akhir.subtract(const Duration(days: 29)), end: akhir),
      _Rentang.kuartal => DateTimeRange(start: DateTime(akhir.year, akhir.month - 3, akhir.day + 1), end: akhir),
      _Rentang.tahunIni => DateTimeRange(start: DateTime(akhir.year), end: akhir),
      _Rentang.semua => DateTimeRange(start: _palingAwal(sesi, lari) ?? akhir, end: akhir),
      _Rentang.pilih => _pilihan ?? DateTimeRange(start: akhir.subtract(const Duration(days: 29)), end: akhir),
    };
  }

  DateTime? _palingAwal(List<WorkoutSession> sesi, List<RunLog> lari) {
    DateTime? awal;
    for (final d in [for (final s in sesi) s.sessionDate, for (final r in lari) r.startedAt]) {
      if (awal == null || d.isBefore(awal)) awal = d;
    }
    return awal == null ? null : DateTime(awal.year, awal.month, awal.day);
  }

  Future<void> _pilihTanggal(List<WorkoutSession> sesi, List<RunLog> lari) async {
    final hasil = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: _hariIni,
      initialDateRange: _rentangAktif(sesi, lari),
      helpText: 'Rentang ekspor',
      saveText: 'Pakai',
    );
    if (hasil != null) {
      setState(() {
        _pilihan = hasil;
        _rentang = _Rentang.pilih;
      });
    }
  }

  String _teks(List<WorkoutSession> sesi, List<RunLog> lari) {
    final r = _rentangAktif(sesi, lari);
    return eksporWorkoutTxt(
      sessions: sesi,
      runs: _denganLari ? lari : const [],
      dari: r.start,
      sampai: r.end,
      dibuat: DateTime.now(),
    );
  }

  Future<void> _bagikan(List<WorkoutSession> sesi, List<RunLog> lari) async {
    final r = _rentangAktif(sesi, lari);
    final nama = namaBerkasEkspor(r.start, r.end);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(utf8.encode(_teks(sesi, lari)), mimeType: 'text/plain', name: nama)],
        // Nama di XFile.fromData diabaikan di luar web; ini yang menentukan
        // nama berkas yang diterima aplikasi tujuan.
        fileNameOverrides: [nama],
        subject: 'Riwayat workout',
        downloadFallbackEnabled: true,
      ),
    );
  }

  Future<void> _salin(List<WorkoutSession> sesi, List<RunLog> lari) async {
    await Clipboard.setData(ClipboardData(text: _teks(sesi, lari)));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Riwayat workout disalin')));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final sesiAsync = ref.watch(workoutSessionsProvider);
    final sesi = sesiAsync.value ?? const <WorkoutSession>[];
    final lari = ref.watch(runsProvider).value ?? const <RunLog>[];

    final r = _rentangAktif(sesi, lari);
    bool masuk(DateTime d) {
      final h = DateTime(d.year, d.month, d.day);
      return !h.isBefore(r.start) && !h.isAfter(r.end);
    }

    final jumlahSesi = sesi.where((s) => masuk(s.sessionDate)).length;
    final jumlahLari = _denganLari ? lari.where((x) => masuk(x.startedAt)).length : 0;
    final kosong = jumlahSesi + jumlahLari == 0;
    final tanggal = DateFormat('d MMM yyyy', 'id_ID');

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
          const Text('Ekspor riwayat workout', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 4),
          Text(
            'Berkas teks biasa — mudah dibaca, ditempel ke chat, atau dicetak.',
            style: TextStyle(fontSize: 12.5, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              for (final pilihan in _Rentang.values)
                ChoiceChip(
                  label: Text(pilihan.label),
                  selected: _rentang == pilihan,
                  onSelected: (_) => pilihan == _Rentang.pilih
                      ? _pilihTanggal(sesi, lari)
                      : setState(() => _rentang = pilihan),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${tanggal.format(r.start)} – ${tanggal.format(r.end)}',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          Text(
            sesiAsync.isLoading
                ? 'Memuat...'
                : '$jumlahSesi sesi latihan${_denganLari ? ' · $jumlahLari lari' : ''}',
            style: TextStyle(fontSize: 12.5, color: colorScheme.onSurfaceVariant),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Sertakan lari', style: TextStyle(fontSize: 14)),
            activeThumbColor: _color,
            value: _denganLari,
            onChanged: (v) => setState(() => _denganLari = v),
          ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton.icon(
            onPressed: kosong ? null : () => _bagikan(sesi, lari),
            style: FilledButton.styleFrom(backgroundColor: _color),
            icon: const Icon(Icons.ios_share, size: 18),
            label: const Text('Simpan / bagikan .txt'),
          ),
          TextButton.icon(
            onPressed: kosong ? null : () => _salin(sesi, lari),
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Salin teksnya'),
          ),
          if (kosong && !sesiAsync.isLoading)
            Text(
              'Tidak ada latihan di rentang ini.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
            ),
        ],
      ),
    );
  }
}
