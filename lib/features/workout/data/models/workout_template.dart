import 'exercise_entry.dart';

/// Satu latihan di dalam template. Bentuknya mirip [ExerciseEntry] tapi tanpa
/// sesi dan tanpa tanggal — template itu rencana, bukan catatan.
class TemplateExercise {
  const TemplateExercise({
    required this.exerciseName,
    this.type = ExerciseType.beban,
    this.weightKg,
    this.sets,
    this.reps,
    this.durationMinutes,
    this.durationSeconds,
    this.progressionLevel = 0,
    this.restSeconds,
    this.notes,
  });

  final String exerciseName;
  final ExerciseType type;
  final double? weightKg;
  final int? sets;
  final int? reps;
  final int? durationMinutes;
  final int? durationSeconds;
  final int progressionLevel;

  /// Lama istirahat antar set. Null berarti pakai bawaan rest timer.
  final int? restSeconds;

  final String? notes;

  factory TemplateExercise.fromMap(Map<String, dynamic> map) => TemplateExercise(
        exerciseName: map['exercise_name'] as String,
        type: ExerciseType.fromDb(map['exercise_type'] as String?),
        weightKg: (map['weight_kg'] as num?)?.toDouble(),
        sets: map['sets'] as int?,
        reps: map['reps'] as int?,
        durationMinutes: map['duration_minutes'] as int?,
        durationSeconds: map['duration_seconds'] as int?,
        progressionLevel: map['progression_level'] as int? ?? 0,
        restSeconds: map['rest_seconds'] as int?,
        notes: map['notes'] as String?,
      );

  Map<String, dynamic> toInsertMap({
    required String templateId,
    required String userId,
    required int position,
  }) =>
      {
        'template_id': templateId,
        'user_id': userId,
        'position': position,
        'exercise_name': exerciseName,
        'exercise_type': type.dbValue,
        'weight_kg': weightKg,
        'sets': sets,
        'reps': reps,
        'duration_minutes': durationMinutes,
        'duration_seconds': durationSeconds,
        'progression_level': progressionLevel,
        'rest_seconds': restSeconds,
        'notes': notes,
      };
}

class WorkoutTemplate {
  const WorkoutTemplate({
    required this.id,
    required this.name,
    required this.exercises,
  });

  final String id;
  final String name;
  final List<TemplateExercise> exercises;

  factory WorkoutTemplate.fromMap(Map<String, dynamic> map) {
    final rows = (map['workout_template_exercises'] as List? ?? const [])
        .cast<Map<String, dynamic>>()
        .toList()
      // Supabase tidak menjamin urutan baris relasi, jadi diurutkan di sini.
      ..sort((a, b) => (a['position'] as int? ?? 0).compareTo(b['position'] as int? ?? 0));

    return WorkoutTemplate(
      id: map['id'] as String,
      name: map['name'] as String,
      exercises: rows.map(TemplateExercise.fromMap).toList(),
    );
  }

  /// Ringkasan untuk chip/subtitle, mis. "Bench Press, Incline Press, +2 lagi".
  String get summary {
    if (exercises.isEmpty) return 'Belum ada latihan';
    final names = exercises.map((e) => e.exerciseName).toList();
    if (names.length <= 2) return names.join(', ');
    return '${names.take(2).join(', ')}, +${names.length - 2} lagi';
  }
}
