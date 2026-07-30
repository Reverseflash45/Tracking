import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../data/models/workout_session.dart';
import '../data/workout_repository.dart';
import '../domain/workout_streak.dart';

final workoutSessionsProvider = FutureProvider.autoDispose<List<WorkoutSession>>((ref) async {
  final userId = ref.watch(currentUserProvider)?.id;
  if (userId == null) return const [];
  return ref.watch(workoutRepositoryProvider).fetchSessions(userId);
});

final workoutStreakProvider = Provider.autoDispose<AsyncValue<WorkoutStreak>>((ref) {
  final sessions = ref.watch(workoutSessionsProvider);
  return sessions.whenData(calculateWorkoutStreak);
});

final todayWorkoutSessionProvider = Provider.autoDispose<AsyncValue<WorkoutSession?>>((ref) {
  final sessions = ref.watch(workoutSessionsProvider);
  final today = DateTime.now();
  return sessions.whenData(
    (list) => list.cast<WorkoutSession?>().firstWhere(
          (session) =>
              session!.sessionDate.year == today.year &&
              session.sessionDate.month == today.month &&
              session.sessionDate.day == today.day,
          orElse: () => null,
        ),
  );
});

/// Nama-nama exercise unik yang pernah dicatat, dipakai untuk grafik progres.
final exerciseNamesProvider = Provider.autoDispose<AsyncValue<List<String>>>((ref) {
  final sessions = ref.watch(workoutSessionsProvider);
  return sessions.whenData((list) {
    final names = <String>{};
    for (final session in list) {
      for (final exercise in session.exercises) {
        if (!exercise.isCardio) names.add(exercise.exerciseName);
      }
    }
    return names.toList()..sort();
  });
});
