class ExerciseEntry {
  const ExerciseEntry({
    required this.id,
    required this.sessionId,
    required this.userId,
    required this.exerciseName,
    this.weightKg,
    this.sets,
    this.reps,
    this.durationMinutes,
    this.isCardio = false,
    this.notes,
  });

  final String id;
  final String sessionId;
  final String userId;
  final String exerciseName;
  final double? weightKg;
  final int? sets;
  final int? reps;
  final int? durationMinutes;
  final bool isCardio;
  final String? notes;

  /// Total beban x set x rep, dipakai untuk grafik volume latihan.
  double get volume => (weightKg ?? 0) * (sets ?? 0) * (reps ?? 0);

  factory ExerciseEntry.fromMap(Map<String, dynamic> map) => ExerciseEntry(
        id: map['id'] as String,
        sessionId: map['session_id'] as String,
        userId: map['user_id'] as String,
        exerciseName: map['exercise_name'] as String,
        weightKg: (map['weight_kg'] as num?)?.toDouble(),
        sets: map['sets'] as int?,
        reps: map['reps'] as int?,
        durationMinutes: map['duration_minutes'] as int?,
        isCardio: map['is_cardio'] as bool? ?? false,
        notes: map['notes'] as String?,
      );

  Map<String, dynamic> toInsertMap({required String sessionId, required String userId}) => {
        'session_id': sessionId,
        'user_id': userId,
        'exercise_name': exerciseName,
        'weight_kg': weightKg,
        'sets': sets,
        'reps': reps,
        'duration_minutes': durationMinutes,
        'is_cardio': isCardio,
        'notes': notes,
      };
}
