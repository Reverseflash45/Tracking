import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/hero_header.dart';
import '../data/models/exercise_entry.dart';
import '../data/models/workout_session.dart';
import '../data/rest_day_repository.dart';
import '../data/workout_repository.dart';
import 'rest_day_card.dart';
import 'workout_providers.dart';

final _weekDayFormat = DateFormat('EEEE', 'id_ID');
final _monthFormat = DateFormat('MMM', 'id_ID');
final _volumeFormat = NumberFormat.decimalPattern('id_ID');

/// Pintasan ke alat bantu kebugaran. Ditaruh di sini, bukan di bottom nav,
/// supaya jumlah tab tetap 5 sesuai panduan Material 3.
class _ToolShortcuts extends StatelessWidget {
  const _ToolShortcuts();

  static const _tools = [
    _ToolCard(
      icon: Icons.directions_run,
      label: 'Lari',
      route: '/workout/run',
    ),
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
      icon: Icons.sports_gymnastics,
      label: 'Muscle Builder',
      route: '/workout/muscle',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    // Progres dibuat selebar layar karena isinya ringkasan lintas fitur —
    // sisanya grid 2x2, karena empat kolom bikin label seperti "Muscle
    // Builder" terpotong di layar HP sempit.
    return Column(
      children: [
        const _ProgressCard(),
        const SizedBox(height: AppSpacing.sm),
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

class _ProgressCard extends StatelessWidget {
  const _ProgressCard();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/workout/stats'),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.dashboard.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.insights, size: 20, color: AppColors.dashboard),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Progres',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Grafik berat badan, nutrisi, dan latihan',
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
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11, height: 1.2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ringkasan satu latihan menyesuaikan tipenya: beban punya kg, bodyweight
/// hanya set x rep, isometrik dalam detik, cardio dalam menit.
String _exerciseSummary(ExerciseEntry exercise) {
  final setsReps = '${exercise.sets ?? 0}x${exercise.reps ?? 0}';
  return switch (exercise.type) {
    ExerciseType.cardio => '${exercise.durationMinutes ?? 0} menit',
    ExerciseType.isometrik => '${exercise.sets ?? 0}x${exercise.durationSeconds ?? 0} detik',
    ExerciseType.bodyweight =>
      exercise.weightKg != null && exercise.weightKg! > 0
          ? '+${exercise.weightKg} kg  ·  $setsReps'
          : setsReps,
    ExerciseType.beban => '${exercise.weightKg ?? 0} kg  ·  $setsReps',
  };
}

class WorkoutHistoryPage extends ConsumerWidget {
  const WorkoutHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(workoutSessionsProvider);
    final sessions = sessionsAsync.value ?? const <WorkoutSession>[];
    final restDays = ref.watch(restDaysProvider).value ?? const <RestDay>[];
    final streak = ref.watch(workoutStreakProvider).value;

    final now = DateTime.now();
    final thisMonth = sessions
        .where((s) => s.sessionDate.year == now.year && s.sessionDate.month == now.month)
        .length;

    // Riwayat menggabungkan sesi dan hari istirahat supaya urutan tanggalnya
    // utuh — hari istirahat yang tersembunyi tidak bisa kamu batalkan lagi.
    final entries = <({DateTime date, WorkoutSession? session, RestDay? rest})>[
      for (final session in sessions)
        (date: session.sessionDate, session: session, rest: null),
      for (final day in restDays) (date: day.restOn, session: null, rest: day),
    ]..sort((a, b) => b.date.compareTo(a.date));

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
                  value: '$thisMonth',
                  label: 'Bulan Ini',
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.lg, AppSpacing.md, 96),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const RestDayCard(),
                  const SizedBox(height: AppSpacing.sm),
                  const _ToolShortcuts(),
                  const SizedBox(height: AppSpacing.lg),
                  sessionsAsync.when(
                    data: (_) => entries.isEmpty
                        ? const EmptyState(
                            icon: Icons.fitness_center,
                            title: 'Belum ada sesi workout',
                            subtitle: 'Tekan tombol + untuk mencatat latihan',
                            color: AppColors.workout,
                          )
                        : Column(
                            children: [
                              for (final entry in entries)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                                  child: entry.session != null
                                      ? _SessionCard(session: entry.session!)
                                      : _RestDayTile(restDay: entry.rest!),
                                ),
                            ],
                          ),
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (error, stackTrace) => EmptyState(
                      icon: Icons.error_outline,
                      title: 'Gagal memuat sesi',
                      subtitle: '$error',
                      color: AppColors.workout,
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

class _SessionCard extends ConsumerWidget {
  const _SessionCard({required this.session});

  final WorkoutSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    final volume = session.exercises.fold<double>(0, (sum, e) => sum + e.volume);
    final cardioMinutes = session.exercises
        .where((e) => e.type == ExerciseType.cardio)
        .fold<int>(0, (sum, e) => sum + (e.durationMinutes ?? 0));

    return Dismissible(
      key: ValueKey(session.id),
      direction: DismissDirection.endToStart,
      background: Container(
        decoration: BoxDecoration(
          color: colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(AppTheme.radius),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Icon(Icons.delete_outline, color: colorScheme.onErrorContainer),
      ),
      confirmDismiss: (_) => showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Hapus sesi?'),
          content: const Text('Sesi workout ini beserta semua latihannya akan dihapus.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hapus')),
          ],
        ),
      ),
      onDismissed: (_) async {
        await ref.read(workoutRepositoryProvider).deleteSession(session.id);
        ref.invalidate(workoutSessionsProvider);
      },
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
            childrenPadding: const EdgeInsets.only(bottom: AppSpacing.sm),
            leading: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.workout.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${session.sessionDate.day}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                      color: AppColors.workout,
                      height: 1.1,
                    ),
                  ),
                  Text(
                    _monthFormat.format(session.sessionDate),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.workout,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            title: Text(
              _weekDayFormat.format(session.sessionDate),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  _StatPill(
                    icon: Icons.fitness_center,
                    label: '${session.exercises.length} latihan',
                  ),
                  if (volume > 0)
                    _StatPill(
                      icon: Icons.scale_outlined,
                      label: '${_volumeFormat.format(volume.round())} kg',
                    ),
                  if (cardioMinutes > 0)
                    _StatPill(icon: Icons.directions_run, label: '$cardioMinutes menit'),
                ],
              ),
            ),
            children: [
              for (final exercise in session.exercises)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppColors.workout,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          exercise.exerciseName,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                      Text(
                        _exerciseSummary(exercise),
                        style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              if (session.notes != null && session.notes!.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.sm,
                    AppSpacing.md,
                    0,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.sticky_note_2_outlined,
                        size: 14,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          session.notes!,
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.sm, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () async {
                        await context.push('/workout/new?from=${session.id}');
                        ref.invalidate(workoutSessionsProvider);
                      },
                      icon: const Icon(Icons.replay, size: 18, color: AppColors.workout),
                      label: const Text('Ulangi', style: TextStyle(color: AppColors.workout)),
                    ),
                    TextButton.icon(
                      onPressed: () => context.push('/workout/${session.id}/edit'),
                      icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.workout),
                      label: const Text('Edit', style: TextStyle(color: AppColors.workout)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Baris riwayat untuk hari istirahat.
///
/// Sengaja dibuat lebih ramping dan berwarna lain dari kartu sesi — sekilas
/// harus kelihatan bahwa hari ini tidak ada latihannya.
class _RestDayTile extends ConsumerWidget {
  const _RestDayTile({required this.restDay});

  final RestDay restDay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return Dismissible(
      key: ValueKey('rest-${restDay.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        decoration: BoxDecoration(
          color: colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(AppTheme.radius),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Icon(Icons.delete_outline, color: colorScheme.onErrorContainer),
      ),
      onDismissed: (_) async {
        await ref.read(restDayRepositoryProvider).deleteRestDay(restDay.id);
        ref.invalidate(restDaysProvider);
      },
      child: Card(
        margin: EdgeInsets.zero,
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 10,
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.statusInProgress.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${restDay.restOn.day}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: AppColors.statusInProgress,
                        height: 1.1,
                      ),
                    ),
                    Text(
                      _monthFormat.format(restDay.restOn),
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: AppColors.statusInProgress,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _weekDayFormat.format(restDay.restOn),
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      restDay.note?.trim().isNotEmpty == true
                          ? restDay.note!
                          : 'Hari istirahat',
                      style: TextStyle(fontSize: 11.5, color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.bedtime_outlined,
                size: 17,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(fontSize: 12, color: color)),
      ],
    );
  }
}
