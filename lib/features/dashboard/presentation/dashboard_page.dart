import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../academic/data/models/class_schedule.dart';
import '../../academic/data/models/task.dart';
import '../../academic/presentation/academic_providers.dart';
import '../../workout/presentation/workout_providers.dart';

final _deadlineFormat = DateFormat('d MMM, HH:mm', 'id_ID');

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(classSchedulesProvider);
          ref.invalidate(tasksProvider);
          ref.invalidate(workoutSessionsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: const [
            _TodayScheduleCard(),
            SizedBox(height: 12),
            _UpcomingDeadlinesCard(),
            SizedBox(height: 12),
            _TodayWorkoutCard(),
            SizedBox(height: 12),
            _TasksSummaryCard(),
          ],
        ),
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  const _DashboardCard({required this.title, required this.icon, required this.child});

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _TodayScheduleCard extends ConsumerWidget {
  const _TodayScheduleCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schedules = ref.watch(todaySchedulesProvider);
    return _DashboardCard(
      title: 'Jadwal Hari Ini',
      icon: Icons.school_outlined,
      child: schedules.when(
        data: (items) => items.isEmpty
            ? const Text('Tidak ada jadwal kuliah hari ini.')
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final ClassSchedule schedule in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('${schedule.timeRangeLabel} · ${schedule.courseName}'
                          '${schedule.room != null ? " (${schedule.room})" : ""}'),
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
      title: 'Deadline Terdekat',
      icon: Icons.alarm,
      child: deadlines.when(
        data: (items) => items.isEmpty
            ? const Text('Tidak ada deadline mendatang. Mantap!')
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final AcademicTask task in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('${task.title} · ${_deadlineFormat.format(task.deadline)}'),
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
      title: 'Workout Hari Ini',
      icon: Icons.fitness_center,
      child: session.when(
        data: (data) => data == null
            ? const Text('Belum ada sesi workout tercatat hari ini.')
            : Text('${data.exercises.length} latihan tercatat'
                '${data.notes != null ? " · ${data.notes}" : ""}'),
        loading: () => const LinearProgressIndicator(),
        error: (error, stackTrace) => Text('Gagal memuat: $error'),
      ),
    );
  }
}

class _TasksSummaryCard extends ConsumerWidget {
  const _TasksSummaryCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(tasksProvider);
    return _DashboardCard(
      title: 'Ringkasan Tugas',
      icon: Icons.checklist,
      child: tasksAsync.when(
        data: (tasks) {
          final unfinished = tasks.where((task) => !task.isDone).length;
          final overdue = tasks
              .where((task) => !task.isDone && task.deadline.isBefore(DateTime.now()))
              .length;
          return Text('$unfinished tugas belum selesai'
              '${overdue > 0 ? " · $overdue terlambat" : ""}');
        },
        loading: () => const LinearProgressIndicator(),
        error: (error, stackTrace) => Text('Gagal memuat: $error'),
      ),
    );
  }
}
