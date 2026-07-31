/// Tipe latihan menentukan field mana yang relevan dan bagaimana progressive
/// overload dihitung. Menggantikan boolean `is_cardio` yang lama.
enum ExerciseType {
  beban('beban', 'Beban'),
  bodyweight('bodyweight', 'Bodyweight'),
  isometrik('isometrik', 'Isometrik'),
  cardio('cardio', 'Cardio');

  const ExerciseType(this.dbValue, this.label);

  final String dbValue;
  final String label;

  static ExerciseType fromDb(String? value) => ExerciseType.values.firstWhere(
        (type) => type.dbValue == value,
        orElse: () => ExerciseType.beban,
      );

  /// Latihan yang dihitung dalam set x rep (bukan durasi).
  bool get pakaiRep => this == ExerciseType.beban || this == ExerciseType.bodyweight;

  /// Latihan yang punya angka beban. Untuk [bodyweight] artinya beban tambahan
  /// opsional (rompi beban / dip belt), bukan beban wajib.
  bool get pakaiBeban => this == ExerciseType.beban || this == ExerciseType.bodyweight;

  /// Latihan yang ikut dihitung ke volume dan grafik progres beban.
  bool get pakaiVolume => this == ExerciseType.beban;
}

class ExerciseEntry {
  const ExerciseEntry({
    required this.id,
    required this.sessionId,
    required this.userId,
    required this.exerciseName,
    this.type = ExerciseType.beban,
    this.weightKg,
    this.sets,
    this.reps,
    this.durationMinutes,
    this.durationSeconds,
    this.progressionLevel = 0,
    this.notes,
  });

  final String id;
  final String sessionId;
  final String userId;
  final String exerciseName;
  final ExerciseType type;

  /// Beban angkatan untuk [ExerciseType.beban]; beban tambahan opsional untuk
  /// [ExerciseType.bodyweight].
  final double? weightKg;

  final int? sets;
  final int? reps;

  /// Durasi cardio.
  final int? durationMinutes;

  /// Lama tahanan untuk latihan isometrik (plank, wall sit).
  final int? durationSeconds;

  /// Posisi di tangga progresi bodyweight (0 = langkah pertama).
  final int progressionLevel;

  final String? notes;

  /// Total beban x set x rep, dipakai untuk grafik volume latihan.
  double get volume => (weightKg ?? 0) * (sets ?? 0) * (reps ?? 0);

  factory ExerciseEntry.fromMap(Map<String, dynamic> map) => ExerciseEntry(
        id: map['id'] as String,
        sessionId: map['session_id'] as String,
        userId: map['user_id'] as String,
        exerciseName: map['exercise_name'] as String,
        type: ExerciseType.fromDb(map['exercise_type'] as String?),
        weightKg: (map['weight_kg'] as num?)?.toDouble(),
        sets: map['sets'] as int?,
        reps: map['reps'] as int?,
        durationMinutes: map['duration_minutes'] as int?,
        durationSeconds: map['duration_seconds'] as int?,
        progressionLevel: map['progression_level'] as int? ?? 0,
        notes: map['notes'] as String?,
      );

  Map<String, dynamic> toInsertMap({required String sessionId, required String userId}) => {
        'session_id': sessionId,
        'user_id': userId,
        'exercise_name': exerciseName,
        'exercise_type': type.dbValue,
        'weight_kg': weightKg,
        'sets': sets,
        'reps': reps,
        'duration_minutes': durationMinutes,
        'duration_seconds': durationSeconds,
        'progression_level': progressionLevel,
        'notes': notes,
      };
}
