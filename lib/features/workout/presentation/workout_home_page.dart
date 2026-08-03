import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/hero_header.dart';
import '../data/models/workout_session.dart';
import '../data/rest_day_repository.dart';
import 'rest_day_card.dart';
import 'workout_providers.dart';

/// Halaman utama Workout: pintu masuk ke semua alat, bukan tempat menumpuk
/// catatan.
///
/// Riwayat dipindah ke halamannya sendiri. Setahun latihan itu bisa 400 baris,
/// dan menaruhnya di bawah tombol-tombol utama membuat semua alat lain
/// tenggelam — kamu harus menggulir melewati ratusan sesi cuma untuk membuka
/// Nutrisi.
class WorkoutHomePage extends ConsumerWidget {
  const WorkoutHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(workoutSessionsProvider).value ?? const <WorkoutSession>[];
    final restDays = ref.watch(restDaysProvider).value ?? const <RestDay>[];
    final streak = ref.watch(workoutStreakProvider).value;

    final now = DateTime.now();
    final bulanIni = sessions
        .where((s) => s.sessionDate.year == now.year && s.sessionDate.month == now.month)
        .length;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/workout/new');
          ref.invalidate(workoutSessionsProvider);
        },
        backgroundColor: AppColors.workout,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Workout'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(workoutSessionsProvider);
          ref.invalidate(restDaysProvider);
        },
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            HeroHeader(
              title: 'Workout',
              subtitle: 'Riwayat latihan dan perkembanganmu',
              color: AppColors.workout,
              trailing: HeroIconButton(
                icon: Icons.show_chart,
                tooltip: 'Lihat progress',
                onPressed: () => context.push('/workout/progress'),
              ),
              stats: [
                HeroStatData(
                  icon: Icons.local_fire_department,
                  value: '${streak?.current ?? 0}',
                  label: 'Streak Aktif',
                ),
                HeroStatData(
                  icon: Icons.emoji_events_outlined,
                  value: '${streak?.best ?? 0}',
                  label: 'Streak Terbaik',
                ),
                HeroStatData(
                  icon: Icons.calendar_month_outlined,
                  value: '$bulanIni',
                  label: 'Bulan Ini',
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.md,
                96,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const RestDayCard(),
                  const SizedBox(height: AppSpacing.sm),
                  const _ProgressCard(),
                  const SizedBox(height: AppSpacing.sm),
                  _RiwayatCard(
                    jumlah: sessions.length + restDays.length,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const _ToolGrid(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pintasan ke alat bantu kebugaran. Ditaruh di sini, bukan di bottom nav,
/// supaya jumlah tab tetap 5 sesuai panduan Material 3.
class _ToolGrid extends StatelessWidget {
  const _ToolGrid();

  static const _tools = [
    _ToolCard(icon: Icons.directions_run, label: 'Lari', route: '/workout/run'),
    _ToolCard(
      icon: Icons.videocam_outlined,
      label: 'Latihan Terpandu',
      route: '/workout/live',
    ),
    _ToolCard(
      icon: Icons.restaurant_menu,
      label: 'Nutrisi',
      route: '/workout/nutrition',
    ),
    _ToolCard(
      icon: Icons.bedtime_outlined,
      label: 'Tidur',
      route: '/workout/sleep',
    ),
    _ToolCard(
      icon: Icons.local_fire_department,
      label: 'Kalkulator Kalori',
      route: '/workout/calories',
    ),
    _ToolCard(
      icon: Icons.accessibility_new,
      label: 'Profil Tubuh',
      route: '/workout/body',
    ),
    _ToolCard(
      icon: Icons.photo_camera_outlined,
      label: 'Foto Progres',
      route: '/workout/photos',
    ),
    _ToolCard(
      icon: Icons.sports_gymnastics,
      label: 'Muscle Builder',
      route: '/workout/muscle',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    // Grid 2 kolom, karena empat kolom bikin label seperti "Muscle Builder"
    // terpotong di layar HP sempit.
    return Column(
      children: [
        for (var i = 0; i < _tools.length; i += 2) ...[
          if (i > 0) const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(child: _tools[i]),
              const SizedBox(width: AppSpacing.sm),
              if (i + 1 < _tools.length)
                Expanded(child: _tools[i + 1])
              else
                const Spacer(),
            ],
          ),
        ],
      ],
    );
  }
}

/// Kartu lebar untuk hal yang isinya ringkasan lintas fitur.
class _WideCard extends StatelessWidget {
  const _WideCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.route,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String route;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(route),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard();

  @override
  Widget build(BuildContext context) => const _WideCard(
        icon: Icons.insights,
        color: AppColors.dashboard,
        title: 'Progres',
        subtitle: 'Grafik berat badan, nutrisi, dan latihan',
        route: '/workout/stats',
      );
}

class _RiwayatCard extends StatelessWidget {
  const _RiwayatCard({required this.jumlah});

  final int jumlah;

  @override
  Widget build(BuildContext context) => _WideCard(
        icon: Icons.history,
        color: AppColors.workout,
        title: 'Riwayat Latihan',
        subtitle: jumlah == 0
            ? 'Belum ada catatan'
            : '$jumlah catatan · bisa disaring per periode & jenis',
        route: '/workout/history',
      );
}

class _ToolCard extends StatelessWidget {
  const _ToolCard({required this.icon, required this.label, required this.route});

  final IconData icon;
  final String label;
  final String route;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(route),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.workout.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: AppColors.workout),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
