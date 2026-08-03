import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../data/rest_day_repository.dart';
import '../domain/workout_streak.dart';
import 'workout_providers.dart';

const Color _restColor = AppColors.statusInProgress;

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Kartu penanda hari istirahat.
///
/// Menyampaikan tiga hal yang berbeda tergantung keadaan hari ini, dan tidak
/// pernah menjanjikan streak selamat kalau memang tidak.
class RestDayCard extends ConsumerStatefulWidget {
  const RestDayCard({super.key});

  @override
  ConsumerState<RestDayCard> createState() => _RestDayCardState();
}

class _RestDayCardState extends ConsumerState<RestDayCard> {
  bool _sibuk = false;

  Future<void> _jalankan(Future<void> Function() aksi) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _sibuk = true);
    try {
      await aksi();
      ref.invalidate(restDaysProvider);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Gagal menyimpan: $e')));
    } finally {
      if (mounted) setState(() => _sibuk = false);
    }
  }

  Future<void> _tandai() async {
    final userId = ref.read(currentUserProvider)?.id;
    if (userId == null) return;
    await _jalankan(
      () => ref.read(restDayRepositoryProvider).addRestDay(
            userId: userId,
            date: DateTime.now(),
          ),
    );
  }

  Future<void> _batalkan(RestDay restDay) =>
      _jalankan(() => ref.read(restDayRepositoryProvider).deleteRestDay(restDay.id));

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final restToday = ref.watch(todayRestDayProvider);
    final activeDates = ref.watch(activeDatesProvider);
    final restDates = [
      for (final day in ref.watch(restDaysProvider).value ?? const <RestDay>[])
        day.restOn,
    ];
    final streak = ref.watch(workoutStreakProvider).value;

    final today = DateTime.now();
    final sudahBergerak = activeDates.any((date) => _sameDay(date, today));

    // Jatah dihitung sampai kemarin kalau hari ini belum ditandai, supaya
    // pertanyaannya jadi "kalau ditandai sekarang, masih nyambung tidak?".
    final terpakai = consecutiveRestDays(
      restDates: restDates,
      activeDates: activeDates,
      now: restToday != null ? today : today.subtract(const Duration(days: 1)),
    );
    final sisa = kMaxConsecutiveRestDays - terpakai;

    final (icon, judul, pesan, warna) = _isi(
      sudahBergerak: sudahBergerak,
      ditandai: restToday != null,
      sisa: sisa,
      streakMati: (streak?.current ?? 0) == 0,
    );

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 20, color: warna),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        judul,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        pesan,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // Angka streak di header memuat hari istirahat. Rinciannya
            // disebut di sini supaya tidak terbaca sebagai jumlah hari latihan.
            if (streak != null && streak.restInCurrent > 0) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Streak ${streak.current} hari — ${streak.activeInCurrent} hari '
                'latihan, ${streak.restInCurrent} hari istirahat.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  fontStyle: FontStyle.italic,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (!sudahBergerak) ...[
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerRight,
                child: restToday != null
                    ? TextButton.icon(
                        onPressed: _sibuk ? null : () => _batalkan(restToday),
                        icon: const Icon(Icons.undo, size: 16),
                        label: const Text('Batalkan'),
                      )
                    : FilledButton.tonalIcon(
                        onPressed: _sibuk ? null : _tandai,
                        style: FilledButton.styleFrom(
                          backgroundColor: _restColor.withValues(alpha: 0.14),
                          foregroundColor: _restColor,
                        ),
                        icon: const Icon(Icons.bedtime_outlined, size: 16),
                        label: const Text('Tandai Istirahat'),
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Isi kartu untuk tiap keadaan. Dipisah supaya urutan syaratnya kelihatan
  /// utuh dan tidak tersebar di tengah widget.
  (IconData, String, String, Color) _isi({
    required bool sudahBergerak,
    required bool ditandai,
    required int sisa,
    required bool streakMati,
  }) {
    if (sudahBergerak) {
      return (
        Icons.check_circle_outline,
        'Hari ini sudah bergerak',
        'Tidak perlu ditandai istirahat — apinya sudah aman hari ini.',
        AppColors.statusDone,
      );
    }

    if (ditandai) {
      // Menandai istirahat tidak selalu menyelamatkan apa pun — kalau rantainya
      // sudah putus sebelum hari ini, tandanya cuma catatan.
      if (streakMati) {
        return (
          Icons.bedtime,
          'Hari ini ditandai istirahat',
          'Tapi streak-nya sudah mati sebelum hari ini, jadi tanda ini tidak '
              'menyambung apa-apa. Yang menyalakannya lagi cuma latihan.',
          AppColors.priorityMedium,
        );
      }
      return (
        Icons.bedtime,
        'Hari ini ditandai istirahat',
        sisa > 0
            ? 'Streak tetap jalan. Sisa jatah $sisa hari lagi sebelum harus '
                'bergerak.'
            : 'Streak tetap jalan, tapi jatahnya habis. Besok harus bergerak '
                'atau rantainya putus.',
        _restColor,
      );
    }

    if (streakMati) {
      return (
        Icons.info_outline,
        'Streak sedang mati',
        'Hari istirahat cuma menyambung rantai yang masih hidup — dia tidak '
            'bisa menyalakannya lagi. Yang bisa cuma latihan.',
        AppColors.priorityMedium,
      );
    }

    if (sisa <= 0) {
      return (
        Icons.local_fire_department_outlined,
        'Jatah istirahat habis',
        'Sudah $kMaxConsecutiveRestDays hari istirahat berturut-turut. '
            'Menandai hari ini tidak akan menahan streak — hari ini harus ada '
            'gerakannya.',
        AppColors.priorityHigh,
      );
    }

    return (
      Icons.bedtime_outlined,
      'Belum ada catatan hari ini',
      'Kalau memang sedang pemulihan, tandai hari istirahat supaya streak-nya '
          'tidak putus. Jatahnya $sisa hari berturut-turut.',
      _restColor,
    );
  }
}
