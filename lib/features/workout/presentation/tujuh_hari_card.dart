import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../data/istirahat_otomatis_service.dart';
import '../data/rest_day_repository.dart';
import '../domain/istirahat_otomatis.dart';
import 'workout_providers.dart';

const Color _warnaLatihan = AppColors.workout;
const Color _warnaIstirahat = AppColors.statusInProgress;

final _hariPendek = DateFormat('E', 'id_ID');
final _tanggalPanjang = DateFormat('EEEE, d MMMM', 'id_ID');

String _kunciTanggal(DateTime d) => d.toIso8601String().substring(0, 10);

/// Strip tujuh hari terakhir: latihan, istirahat, atau kosong. Ketuk satu hari
/// untuk mencatat latihan yang terlupa di hari itu, atau mengubah tanda
/// istirahatnya.
class TujuhHariCard extends ConsumerWidget {
  const TujuhHariCard({super.key});

  Future<void> _pilih(BuildContext context, WidgetRef ref, DateTime hari, StatusHari status) async {
    final restDays = ref.read(restDaysProvider).value ?? const <RestDay>[];
    RestDay? tanda;
    for (final r in restDays) {
      if (_kunciTanggal(r.restOn) == _kunciTanggal(hari)) tanda = r;
    }

    final aksi = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
              child: Text(
                _tanggalPanjang.format(hari),
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.fitness_center, color: _warnaLatihan),
              title: Text(status == StatusHari.latihan ? 'Tambah sesi lain' : 'Catat latihan di hari ini'),
              subtitle: status == StatusHari.latihan
                  ? null
                  : const Text('Untuk latihan yang lupa kamu catat'),
              onTap: () => Navigator.pop(context, 'catat'),
            ),
            if (status == StatusHari.latihan)
              ListTile(
                leading: const Icon(Icons.history, color: _warnaLatihan),
                title: const Text('Lihat atau edit sesinya'),
                onTap: () => Navigator.pop(context, 'riwayat'),
              ),
            if (tanda != null && status != StatusHari.latihan)
              ListTile(
                leading: const Icon(Icons.close, color: _warnaIstirahat),
                title: const Text('Hapus tanda istirahat'),
                onTap: () => Navigator.pop(context, 'hapus'),
              ),
            if (tanda == null && status == StatusHari.kosong)
              ListTile(
                leading: const Icon(Icons.bedtime_outlined, color: _warnaIstirahat),
                title: const Text('Tandai istirahat'),
                onTap: () => Navigator.pop(context, 'istirahat'),
              ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
    if (aksi == null || !context.mounted) return;

    final userId = ref.read(currentUserProvider)?.id;
    final repo = ref.read(restDayRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    try {
      switch (aksi) {
        case 'catat':
          await context.push('/workout/new?tanggal=${_kunciTanggal(hari)}');
        case 'riwayat':
          await context.push('/workout/history');
        case 'hapus':
          await repo.deleteRestDay(tanda!.id);
          ref.invalidate(restDaysProvider);
        case 'istirahat':
          if (userId == null) return;
          await repo.addRestDay(userId: userId, date: hari);
          ref.invalidate(restDaysProvider);
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Gagal menyimpan: $e')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final aktif = ref.watch(activeDatesProvider);
    final restDays = ref.watch(restDaysProvider).value ?? const <RestDay>[];
    final otomatis = ref.watch(istirahatOtomatisProvider);

    final hari = statusHarian(
      aktif: aktif,
      istirahat: {for (final r in restDays) r.restOn: r.note},
      now: DateTime.now(),
    );

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('7 hari terakhir', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
            const SizedBox(height: 2),
            Text(
              'Lupa mencatat? Ketuk harinya.',
              style: TextStyle(fontSize: 11.5, color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                for (final (tanggal, status) in hari)
                  Expanded(
                    child: _Hari(
                      tanggal: tanggal,
                      status: status,
                      hariIni: tanggal == hari.last.$1,
                      onTap: () => _pilih(context, ref, tanggal, status),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: otomatis,
              onChanged: (v) => ref.read(istirahatOtomatisProvider.notifier).setAktif(v),
              activeThumbColor: _warnaIstirahat,
              title: const Text('Hari tanpa latihan otomatis jadi istirahat', style: TextStyle(fontSize: 12.5)),
              subtitle: Text(
                'Diisi keesokan harinya. Streak tetap putus setelah '
                '2 hari istirahat berturut-turut.',
                style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Hari extends StatelessWidget {
  const _Hari({required this.tanggal, required this.status, required this.hariIni, required this.onTap});

  final DateTime tanggal;
  final StatusHari status;
  final bool hariIni;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final (ikon, warna, isi, label) = switch (status) {
      StatusHari.latihan => (Icons.check, Colors.white, _warnaLatihan, 'latihan'),
      StatusHari.istirahat => (Icons.bedtime, Colors.white, _warnaIstirahat, 'istirahat'),
      StatusHari.istirahatOtomatis => (
          Icons.bedtime_outlined,
          _warnaIstirahat,
          _warnaIstirahat.withValues(alpha: 0.16),
          'istirahat otomatis',
        ),
      StatusHari.kosong => (null, null, colorScheme.surfaceContainerHighest, 'belum ada catatan'),
    };

    return Semantics(
      button: true,
      label: '${_tanggalPanjang.format(tanggal)}, $label',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              Text(
                _hariPendek.format(tanggal),
                maxLines: 1,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: hariIni ? FontWeight.w800 : FontWeight.w500,
                  color: hariIni ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: isi,
                  shape: BoxShape.circle,
                  border: hariIni ? Border.all(color: colorScheme.onSurface, width: 1.5) : null,
                ),
                child: ikon == null ? null : Icon(ikon, size: 16, color: warna),
              ),
              const SizedBox(height: 2),
              Text(
                '${tanggal.day}',
                style: TextStyle(fontSize: 10.5, color: colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
