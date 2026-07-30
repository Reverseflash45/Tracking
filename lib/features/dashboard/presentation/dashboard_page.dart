import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/domain/achievements.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/stat_tile.dart';
import '../../academic/data/models/class_schedule.dart';
import '../../academic/data/models/task.dart';
import '../../academic/presentation/academic_providers.dart';
import '../../profile/data/profile_repository.dart';
import '../../workout/presentation/workout_providers.dart';

final _deadlineFormat = DateFormat('d MMM, HH:mm', 'id_ID');
final _dayFormat = DateFormat('EEEE, d MMMM y', 'id_ID');

const double _statOverlap = 44;

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(classSchedulesProvider);
          ref.invalidate(tasksProvider);
          ref.invalidate(workoutSessionsProvider);
          ref.invalidate(profileFullNameProvider);
        },
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                const _HeroHeader(),
                Positioned(
                  left: AppSpacing.md,
                  right: AppSpacing.md,
                  bottom: -_statOverlap,
                  child: const _StreakAndStatsRow(),
                ),
              ],
            ),
            const SizedBox(height: _statOverlap + AppSpacing.lg),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _AchievementsRow(),
                  const SectionHeader(title: 'Jadwal Hari Ini'),
                  const _TodayScheduleCard(),
                  const SizedBox(height: AppSpacing.md),
                  const SectionHeader(title: 'Deadline Terdekat'),
                  const _UpcomingDeadlinesCard(),
                  const SizedBox(height: AppSpacing.md),
                  const SectionHeader(title: 'Workout Hari Ini'),
                  const _TodayWorkoutCard(),
                  const SizedBox(height: AppSpacing.lg),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroHeader extends ConsumerWidget {
  const _HeroHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final fullName = ref.watch(profileFullNameProvider).value;
    final displayName = (fullName != null && fullName.trim().isNotEmpty)
        ? fullName.trim().split(' ').first
        : (user?.email?.split('@').first ?? 'Mahasiswa');
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        MediaQuery.of(context).padding.top + AppSpacing.md,
        AppSpacing.md,
        AppSpacing.lg + _statOverlap,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colorScheme.primary, colorScheme.tertiary],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: Colors.white.withValues(alpha: 0.25),
            child: Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 20,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Halo, $displayName!',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _dayFormat.format(DateTime.now()),
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StreakAndStatsRow extends ConsumerWidget {
  const _StreakAndStatsRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workoutStreak = ref.watch(workoutStreakProvider);
    final deadlineStreak = ref.watch(deadlineStreakProvider);
    final tasksAsync = ref.watch(tasksProvider);

    final doneToday = tasksAsync.value?.where((t) {
          final completed = t.completedAt;
          final now = DateTime.now();
          return completed != null &&
              completed.year == now.year &&
              completed.month == now.month &&
              completed.day == now.day;
        }).length ??
        0;

    return SizedBox(
      height: _statOverlap * 2,
      child: Row(
        children: [
          Expanded(
            child: StatTile(
              icon: Icons.local_fire_department,
              value: '${workoutStreak.value?.current ?? 0}',
              label: 'Streak Workout',
              color: Colors.deepOrange,
              fill: true,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: StatTile(
              icon: Icons.bolt,
              value: '${deadlineStreak.value?.current ?? 0}',
              label: 'Streak Deadline',
              color: Colors.indigo,
              fill: true,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: StatTile(
              icon: Icons.task_alt,
              value: '$doneToday',
              label: 'Selesai Hari Ini',
              color: Colors.teal,
              fill: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _AchievementsRow extends ConsumerWidget {
  const _AchievementsRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workoutStreak = ref.watch(workoutStreakProvider).value?.current ?? 0;
    final deadlineStreak = ref.watch(deadlineStreakProvider).value?.current ?? 0;
    final achievements = computeAchievements(
      workoutStreak: workoutStreak,
      deadlineStreak: deadlineStreak,
    );

    if (achievements.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          for (final achievement in achievements)
            Chip(
              avatar: Icon(achievement.icon, size: 18, color: Theme.of(context).colorScheme.primary),
              label: Text(achievement.label),
            ),
        ],
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  const _DashboardCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(child: Padding(padding: const EdgeInsets.all(AppSpacing.md), child: child));
  }
}

class _TodayScheduleCard extends ConsumerWidget {
  const _TodayScheduleCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schedules = ref.watch(todaySchedulesProvider);
    return _DashboardCard(
      child: schedules.when(
        data: (items) => items.isEmpty
            ? const EmptyState(
                icon: Icons.school_outlined,
                title: 'Tidak ada jadwal hari ini',
                subtitle: 'Nikmati waktu luangmu!',
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final ClassSchedule schedule in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Row(
                        children: [
                          Icon(Icons.access_time,
                              size: 18, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text('${schedule.timeRangeLabel} - ${schedule.courseName}'
                                '${schedule.room != null ? " (${schedule.room})" : ""}'),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
        loading: () => const LinearProgressIndicator(),
        error: (error, stackTrace) => Text('Gagal memuat: $error'),
      ),
    );
  }
}

class _UpcomingDeadlinesCard extends ConsumerWidget {
  const _UpcomingDeadlinesCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deadlines = ref.watch(upcomingDeadlinesProvider);
    return _DashboardCard(
      child: deadlines.when(
        data: (items) => items.isEmpty
            ? const EmptyState(
                icon: Icons.celebration_outlined,
                title: 'Tidak ada deadline mendatang',
                subtitle: 'Mantap, semua tugas aman!',
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final AcademicTask task in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Row(
                        children: [
                          Icon(Icons.alarm, size: 18, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text('${task.title} - ${_deadlineFormat.format(task.deadline)}'),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
        loading: () => const LinearProgressIndicator(),
        error: (error, stackTrace) => Text('Gagal memuat: $error'),
      ),
    );
  }
}

class _TodayWorkoutCard extends ConsumerWidget {
  const _TodayWorkoutCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(todayWorkoutSessionProvider);
    return _DashboardCard(
      child: session.when(
        data: (data) => data == null
            ? const EmptyState(
                icon: Icons.fitness_center,
                title: 'Belum ada sesi workout hari ini',
              )
            : Row(
                children: [
                  Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text('${data.exercises.length} latihan tercatat'
                        '${data.notes != null ? " - ${data.notes}" : ""}'),
                  ),
                ],
              ),
        loading: () => const LinearProgressIndicator(),
        error: (error, stackTrace) => Text('Gagal memuat: $error'),
      ),
    );
  }
}
