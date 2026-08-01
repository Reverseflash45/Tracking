import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../../run/data/run_repository.dart';
import '../data/models/exercise_entry.dart';
import '../data/models/workout_session.dart';
import '../data/models/workout_template.dart';
import '../data/rest_day_repository.dart';
import '../data/workout_repository.dart';
import '../domain/exercise_progress.dart';
import '../domain/progressive_overload.dart';
import '../domain/workout_streak.dart';

final workoutSessionsProvider = FutureProvider.autoDispose<List<WorkoutSession>>((ref) async {
  final userId = ref.watch(currentUserProvider)?.id;
  if (userId == null) return const [];
  return ref.watch(workoutRepositoryProvider).fetchSessions(userId);
});

final workoutTemplatesProvider =
    FutureProvider.autoDispose<List<WorkoutTemplate>>((ref) async {
  final userId = ref.watch(currentUserProvider)?.id;
  if (userId == null) return const [];
  return ref.watch(workoutRepositoryProvider).fetchTemplates(userId);
});

/// Streak menghitung semua hari kamu bergerak — sesi angkat beban maupun lari —
/// ditambah hari istirahat yang kamu tandai sendiri sebagai penyambung.
final workoutStreakProvider = Provider.autoDispose<AsyncValue<WorkoutStreak>>((ref) {
  final sessions = ref.watch(workoutSessionsProvider);
  final runs = ref.watch(runsProvider).value ?? const <RunLog>[];
  final restDays = ref.watch(restDaysProvider).value ?? const <RestDay>[];

  return sessions.whenData(
    (list) => calculateStreakFromDates(
      [
        for (final session in list) session.sessionDate,
        for (final run in runs) run.startedAt,
      ],
      restDates: [for (final day in restDays) day.restOn],
    ),
  );
});

/// Hari-hari yang benar-benar ada gerakannya. Sengaja tidak memuat hari
/// istirahat — dipakai untuk mengecek apakah hari ini masih perlu ditandai.
final activeDatesProvider = Provider.autoDispose<List<DateTime>>((ref) {
  final sessions = ref.watch(workoutSessionsProvider).value ?? const <WorkoutSession>[];
  final runs = ref.watch(runsProvider).value ?? const <RunLog>[];
  return [
    for (final session in sessions) session.sessionDate,
    for (final run in runs) run.startedAt,
  ];
});

/// Penanda istirahat untuk hari ini, kalau ada.
final todayRestDayProvider = Provider.autoDispose<RestDay?>((ref) {
  final restDays = ref.watch(restDaysProvider).value ?? const <RestDay>[];
  final today = DateTime.now();
  for (final day in restDays) {
    if (day.restOn.year == today.year &&
        day.restOn.month == today.month &&
        day.restOn.day == today.day) {
      return day;
    }
  }
  return null;
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
        if (exercise.type != ExerciseType.cardio) names.add(exercise.exerciseName);
      }
    }
    return names.toList()..sort();
  });
});

/// Riwayat progres tiap nama latihan, mencakup semua tipe (termasuk cardio).
/// Dipakai halaman Progress Latihan untuk tampilan "Semua" maupun detail.
final exerciseProgressProvider =
    Provider.autoDispose<AsyncValue<List<ExerciseProgress>>>((ref) {
  final sessions = ref.watch(workoutSessionsProvider);
  return sessions.whenData(buildExerciseProgress);
});

/// Saran progressive overload per nama latihan. Key-nya di-lowercase supaya
/// pencocokan dengan teks yang diketik user tidak peduli huruf besar/kecil.
final overloadSuggestionsProvider =
    Provider.autoDispose<AsyncValue<Map<String, OverloadSuggestion>>>((ref) {
  final sessions = ref.watch(workoutSessionsProvider);
  final names = ref.watch(exerciseNamesProvider).value ?? const <String>[];
  return sessions.whenData((list) {
    final suggestions = <String, OverloadSuggestion>{};
    for (final name in names) {
      final suggestion = suggestOverload(name, list);
      if (suggestion != null) suggestions[name.trim().toLowerCase()] = suggestion;
    }
    return suggestions;
  });
});
