import 'exercise_entry.dart';

class WorkoutSession {
  const WorkoutSession({
    required this.id,
    required this.userId,
    required this.sessionDate,
    this.notes,
    required this.createdAt,
    this.exercises = const [],
  });

  final String id;
  final String userId;
  final DateTime sessionDate;
  final String? notes;
  final DateTime createdAt;
  final List<ExerciseEntry> exercises;

  factory WorkoutSession.fromMap(Map<String, dynamic> map) => WorkoutSession(
        id: map['id'] as String,
        userId: map['user_id'] as String,
        sessionDate: DateTime.parse(map['session_date'] as String),
        notes: map['notes'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
        exercises: (map['workout_exercises'] as List<dynamic>? ?? [])
            .map((row) => ExerciseEntry.fromMap(row as Map<String, dynamic>))
            .toList(),
      );
}
