import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/domain/achievements.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/hero_header.dart';
import '../../../core/widgets/section_header.dart';
import '../../academic/data/models/class_schedule.dart';
import '../../academic/data/models/task.dart';
import '../../academic/presentation/academic_providers.dart';
import '../../profile/data/profile_repository.dart';
import '../../workout/presentation/workout_providers.dart';

final _deadlineFormat = DateFormat('d MMM, HH:mm', 'id_ID');
final _dayFormat = DateFormat('EEEE, d MMMM y', 'id_ID');

const _academicColor = AppColors.academic;
const _deadlineColor = AppColors.deadline;
const _workoutColor = AppColors.workout;

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
          ref.invalidate(profileProvider);
        },
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const _HeroHeader(),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _AchievementsRow(),
                  const SectionHeader(
                    title: 'Jadwal Hari Ini',
                    icon: Icons.school_outlined,
                    color: _academicColor,
                  ),
                  const _TodayScheduleCard(),
                  const SizedBox(height: AppSpacing.md),
                  const SectionHeader(
                    title: 'Deadline Terdekat',
                    icon: Icons.alarm,
                    color: _deadlineColor,
                  ),
                  const _UpcomingDeadlinesCard(),
                  const SizedBox(height: AppSpacing.md),
                  const SectionHeader(
                    title: 'Workout Hari Ini',
                    icon: Icons.fitness_center,
                    color: _workoutColor,
                  ),
                  const _TodayWorkoutCard(),
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
    final profile = ref.watch(profileProvider).value;
    final fullName = profile?.fullName;
    final displayName = (fullName != null && fullName.trim().isNotEmpty)
        ? fullName.trim().split(' ').first
        : (user?.email?.split('@').first ?? 'Mahasiswa');
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';
    final avatarUrl = profile?.avatarUrl;

    final workoutStreak = ref.watch(workoutStreakProvider).value?.current ?? 0;
    final deadlineStreak = ref.watch(deadlineStreakProvider).value?.current ?? 0;
    final doneToday = ref.watch(tasksProvider).value?.where((t) {
          final completed = t.completedAt;
          final now = DateTime.now();
          return completed != null &&
              completed.year == now.year &&
              completed.month == now.month &&
              completed.day == now.day;
        }).length ??
        0;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        MediaQuery.of(context).padding.top + AppSpacing.md,
        AppSpacing.md,
        AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: HeroHeader.gradientFor(AppColors.dashboard),
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.white.withValues(alpha: 0.25),
                backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                child: avatarUrl == null
                    ? Text(
                        initial,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Halo, $displayName!',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _dayFormat.format(DateTime.now()),
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: HeroStat(
                  data: HeroStatData(
                    icon: Icons.local_fire_department,
                    value: '$workoutStreak',
                    label: 'Streak Workout',
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: HeroStat(
                  data: HeroStatData(
                    icon: Icons.bolt,
                    value: '$deadlineStreak',
                    label: 'Streak Deadline',
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: HeroStat(
                  data: HeroStatData(
                    icon: Icons.task_alt,
                    value: '$doneToday',
                    label: 'Selesai Hari Ini',
                  ),
                ),
              ),
            ],
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
                color: _academicColor,
                compact: true,
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final ClassSchedule schedule in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Row(
                        children: [
                          const Icon(Icons.access_time, size: 18, color: _academicColor),
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
                color: _deadlineColor,
                compact: true,
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final AcademicTask task in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Row(
                        children: [
                          const Icon(Icons.alarm, size: 18, color: _deadlineColor),
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
                color: _workoutColor,
                compact: true,
              )
            : Row(
                children: [
                  const Icon(Icons.check_circle, color: _workoutColor),
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
