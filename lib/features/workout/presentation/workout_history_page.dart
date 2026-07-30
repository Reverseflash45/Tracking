import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/async_value_view.dart';
import '../data/models/workout_session.dart';
import '../data/workout_repository.dart';
import 'workout_providers.dart';

class WorkoutHistoryPage extends ConsumerWidget {
  const WorkoutHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(workoutSessionsProvider);

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
          emptyMessage: 'Belum ada sesi workout.\nTekan + untuk mencatat latihan.',
          data: (sessions) => ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sessions.length,
            itemBuilder: (context, index) {
              final session = sessions[index];
              return Card(
                child: ExpansionTile(
                  title: Text(session.sessionDate.toString().split(' ').first),
                  subtitle: Text('${session.exercises.length} latihan'
                      '${session.notes != null ? " · ${session.notes}" : ""}'),
                  children: [
                    for (final exercise in session.exercises)
                      ListTile(
                        title: Text(exercise.exerciseName),
                        subtitle: Text(
                          exercise.isCardio
                              ? 'Cardio · ${exercise.durationMinutes ?? 0} menit'
                              : '${exercise.weightKg ?? 0} kg × ${exercise.sets ?? 0} set × ${exercise.reps ?? 0} rep',
                        ),
                      ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () async {
                          await ref.read(workoutRepositoryProvider).deleteSession(session.id);
                          ref.invalidate(workoutSessionsProvider);
                        },
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Hapus'),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
