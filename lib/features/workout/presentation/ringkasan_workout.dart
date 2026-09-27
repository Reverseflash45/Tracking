import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/hero_header.dart';
import '../data/models/workout_session.dart';
import '../data/rest_day_repository.dart';
import 'workout_providers.dart';

DateTime _tgl(DateTime d) => DateTime(d.year, d.month, d.day);

/// Kartu teal berisi streak dan tujuh hari pekan ini.
///
/// Streak adalah angka yang paling memotivasi di tab ini, jadi ia yang dapat
/// bidang berwarna — bukan tiga kotak statistik yang sama besar.
class KartuStreak extends ConsumerWidget {
  const KartuStreak({super.key});

  static const _singkat = ['S', 'S', 'R', 'K', 'J', 'S', 'M'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streak = ref.watch(workoutStreakProvider).value;
    final aktif = {for (final d in ref.watch(activeDatesProvider)) _tgl(d)};
    final istirahat = {
      for (final r in ref.watch(restDaysProvider).value ?? const <RestDay>[]) _tgl(r.restOn),
    };
    final hariIni = _tgl(DateTime.now());
    // Tujuh hari terakhir sampai hari ini, bukan pekan kalender: di hari
    // Senin pekan kalender masih kosong padahal streak-nya sedang jalan.
    final awal = hariIni.subtract(const Duration(days: 6));
    final sekarang = streak?.current ?? 0;

    return Material(
      color: AppColors.workout,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/workout/history'),
        child: Stack(
          children: [
            Positioned(
              right: -20,
              top: -18,
              child: Icon(
                Icons.local_fire_department_rounded,
                size: 140,
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'STREAK LATIHAN',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.9,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '$sekarang',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 44,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                          letterSpacing: -1.5,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'hari beruntun',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Rekor terbaikmu ${streak?.best ?? 0} hari',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      for (var i = 0; i < 7; i++)
                        Expanded(
                          child: Builder(
                            builder: (context) {
                              final hari = awal.add(Duration(days: i));
                              final latihan = aktif.contains(hari);
                              final rehat = istirahat.contains(hari);
                              final nanti = hari.isAfter(hariIni);
                              final ini = hari == hariIni;
                              return Column(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: latihan
                                          ? Colors.white
                                          : Colors.white.withValues(alpha: nanti ? 0.08 : 0.18),
                                      border: ini && !latihan
                                          ? Border.all(color: Colors.white, width: 2)
                                          : null,
                                    ),
                                    child: Icon(
                                      latihan
                                          ? Icons.check_rounded
                                          : rehat
                                          ? Icons.bedtime_rounded
                                          : null,
                                      size: 18,
                                      color: latihan ? AppColors.workout : Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    _singkat[hari.weekday - 1],
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: ini ? 1 : 0.75),
                                      fontSize: 11.5,
                                      fontWeight: ini ? FontWeight.w800 : FontWeight.w600,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                    ],
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

/// Peta panas 16 minggu terakhir, gaya kontribusi GitHub: satu kotak per
/// hari, makin pekat makin banyak gerakan yang dicatat.
class HeatmapLatihan extends ConsumerWidget {
  const HeatmapLatihan({super.key});

  static const _minggu = 16;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final sesi = ref.watch(workoutSessionsProvider).value ?? const <WorkoutSession>[];
    final lari = ref.watch(activeDatesProvider);

    final skor = <DateTime, int>{};
    for (final s in sesi) {
      final d = _tgl(s.sessionDate);
      skor[d] = (skor[d] ?? 0) + (s.exercises.isEmpty ? 1 : s.exercises.length);
    }
    for (final d in lari) {
      final t = _tgl(d);
      skor[t] = (skor[t] ?? 0) == 0 ? 2 : skor[t]!;
    }

    final hariIni = _tgl(DateTime.now());
    final seninIni = hariIni.subtract(Duration(days: hariIni.weekday - 1));
    final awal = seninIni.subtract(const Duration(days: 7 * (_minggu - 1)));
    final hariAktif = skor.keys.where((d) => !d.isBefore(awal) && !d.isAfter(hariIni)).length;

    Color warna(int n) {
      if (n <= 0) return colorScheme.surfaceContainerHigh;
      if (n <= 2) return AppColors.workout.withValues(alpha: 0.35);
      if (n <= 4) return AppColors.workout.withValues(alpha: 0.65);
      return AppColors.workout;
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '16 minggu terakhir',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                ),
                Text(
                  '$hariAktif hari aktif',
                  style: TextStyle(fontSize: 12.5, color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, c) {
                const jarak = 3.0;
                const lebarLabel = 16.0;
                final sisi = ((c.maxWidth - lebarLabel - jarak * (_minggu - 1)) / _minggu).clamp(
                  6.0,
                  18.0,
                );
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: lebarLabel,
                      child: Column(
                        children: [
                          for (var r = 0; r < 7; r++)
                            SizedBox(
                              height: sisi + jarak,
                              child: Text(
                                r == 0
                                    ? 'S'
                                    : r == 2
                                    ? 'R'
                                    : r == 4
                                    ? 'J'
                                    : '',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  height: 1,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    for (var w = 0; w < _minggu; w++)
                      Padding(
                        padding: EdgeInsets.only(right: w == _minggu - 1 ? 0 : jarak),
                        child: Column(
                          children: [
                            for (var r = 0; r < 7; r++)
                              Builder(
                                builder: (context) {
                                  final hari = awal.add(Duration(days: w * 7 + r));
                                  final nanti = hari.isAfter(hariIni);
                                  return Container(
                                    width: sisi,
                                    height: sisi,
                                    margin: const EdgeInsets.only(bottom: jarak),
                                    decoration: BoxDecoration(
                                      color: nanti ? Colors.transparent : warna(skor[hari] ?? 0),
                                      borderRadius: BorderRadius.circular(3),
                                      border: hari == hariIni
                                          ? Border.all(color: colorScheme.onSurface, width: 1.2)
                                          : null,
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Sedikit',
                  style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                ),
                const SizedBox(width: 6),
                for (final n in [0, 1, 3, 5])
                  Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.only(right: 3),
                    decoration: BoxDecoration(
                      color: warna(n),
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                const SizedBox(width: 3),
                Text(
                  'Banyak',
                  style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Tiga angka bulan ini: sesi, set, dan volume angkat.
class StatistikBulanWorkout extends ConsumerWidget {
  const StatistikBulanWorkout({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sesi = ref.watch(workoutSessionsProvider).value ?? const <WorkoutSession>[];
    final n = DateTime.now();
    final bulanIni = sesi
        .where((s) => s.sessionDate.year == n.year && s.sessionDate.month == n.month)
        .toList();
    final set = bulanIni.fold<int>(
      0,
      (a, s) => a + s.exercises.fold<int>(0, (b, e) => b + (e.sets ?? 0)),
    );
    final volume = bulanIni.fold<double>(
      0,
      (a, s) => a + s.exercises.fold<double>(0, (b, e) => b + e.volume),
    );
    final volumeTeks = volume >= 1000
        ? '${NumberFormat('#,##0.0', 'id_ID').format(volume / 1000)} t'
        : '${volume.round()} kg';

    return KartuStatistik(
      stats: [
        HeroStatData(icon: Icons.event, value: '${bulanIni.length}', label: 'Sesi bulan ini'),
        HeroStatData(icon: Icons.repeat, value: '$set', label: 'Total set'),
        HeroStatData(icon: Icons.fitness_center, value: volumeTeks, label: 'Volume angkat'),
      ],
    );
  }
}

/// Sesi terakhir dengan tombol "Ulangi" — cara tercepat mencatat latihan yang
/// sama seperti kemarin.
class KartuSesiTerakhir extends ConsumerWidget {
  const KartuSesiTerakhir({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final sesi = [...ref.watch(workoutSessionsProvider).value ?? const <WorkoutSession>[]]
      ..sort((a, b) => b.sessionDate.compareTo(a.sessionDate));
    if (sesi.isEmpty) return const SizedBox.shrink();
    final s = sesi.first;
    final selisih = _tgl(DateTime.now()).difference(_tgl(s.sessionDate)).inDays;
    final kapan = selisih == 0
        ? 'Hari ini'
        : selisih == 1
        ? 'Kemarin'
        : '$selisih hari lalu';
    final gerakan = s.exercises.map((e) => e.exerciseName).toList();

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.workout.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.fitness_center_rounded, color: AppColors.workout),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sesi terakhir · $kapan',
                    style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    s.notes?.trim().isNotEmpty == true
                        ? s.notes!.trim()
                        : '${gerakan.length} gerakan',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  if (gerakan.isNotEmpty)
                    Text(
                      gerakan.take(3).join(', ') + (gerakan.length > 3 ? ', …' : ''),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5, color: colorScheme.onSurfaceVariant),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonalIcon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.workout.withValues(alpha: 0.14),
                foregroundColor: AppColors.workout,
                minimumSize: const Size(0, 40),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              onPressed: () async {
                await context.push('/workout/new?from=${s.id}');
                ref.invalidate(workoutSessionsProvider);
              },
              icon: const Icon(Icons.replay_rounded, size: 18),
              label: const Text('Ulangi'),
            ),
          ],
        ),
      ),
    );
  }
}
