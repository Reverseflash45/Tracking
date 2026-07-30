import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_value_view.dart';
import '../data/models/workout_session.dart';
import '../data/workout_repository.dart';
import 'workout_providers.dart';

class WorkoutHistoryPage extends ConsumerWidget {
  const WorkoutHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(workoutSessionsProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Workout Tracker'),
        actions: [
          IconButton(
            icon: const Icon(Icons.show_chart),
            tooltip: 'Progress',
            onPressed: () => context.push('/workout/progress'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await context.push('/workout/new');
          ref.invalidate(workoutSessionsProvider);
        },
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(workoutSessionsProvider),
        child: AsyncValueView<WorkoutSession>(
          value: sessionsAsync,
          emptyIcon: Icons.fitness_center,
          emptyTitle: 'Belum ada sesi workout',
          emptySubtitle: 'Tekan tombol + untuk mencatat latihan',
          data: (sessions) => ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: sessions.length,
            separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final session = sessions[index];
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
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Batal'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Hapus'),
                      ),
                    ],
                  ),
                ),
                onDismissed: (_) async {
                  await ref.read(workoutRepositoryProvider).deleteSession(session.id);
                  ref.invalidate(workoutSessionsProvider);
                },
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: ExpansionTile(
                    leading: CircleAvatar(
                      backgroundColor: colorScheme.primaryContainer,
                      foregroundColor: colorScheme.onPrimaryContainer,
                      child: const Icon(Icons.fitness_center),
                    ),
                    title: Text(
                      session.sessionDate.toString().split(' ').first,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text('${session.exercises.length} latihan'
                        '${session.notes != null ? " - ${session.notes}" : ""}'),
                    children: [
                      for (final exercise in session.exercises)
                        ListTile(
                          title: Text(exercise.exerciseName),
                          subtitle: Text(
                            exercise.isCardio
                                ? 'Cardio - ${exercise.durationMinutes ?? 0} menit'
                                : '${exercise.weightKg ?? 0} kg x ${exercise.sets ?? 0} set x ${exercise.reps ?? 0} rep',
                          ),
                        ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
