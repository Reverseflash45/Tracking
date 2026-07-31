import '../data/models/exercise_entry.dart';
import '../data/models/workout_session.dart';
import 'bodyweight_progression.dart';

/// Kenaikan beban standar untuk latihan beban. 2.5 kg adalah lompatan terkecil
/// yang umum tersedia di gym (2 keping 1.25 kg).
const double kWeightIncrementKg = 2.5;

/// Rentang rep target latihan beban. Selama rep masih di bawah [kRepMax],
/// naikkan rep dulu; begitu tembus, baru bebannya yang naik dan rep balik ke
/// [kRepMin].
const int kRepMin = 8;
const int kRepMax = 12;

/// Rentang rep latihan bodyweight. Batas atasnya lebih tinggi daripada latihan
/// beban karena menaikkan kesulitan gerakan itu lompatan besar — lebih baik
/// mengumpulkan rep dulu sebelum pindah variasi.
const int kBodyweightRepMin = 8;
const int kBodyweightRepMax = 15;

/// Rentang tahanan isometrik dalam detik.
const int kHoldMinSeconds = 30;
const int kHoldMaxSeconds = 60;
const int kHoldIncrementSeconds = 5;

enum OverloadAdvice {
  /// Rep tembus batas atas: saatnya menambah beban.
  naikBeban,

  /// Rep tembus batas atas dan latihannya bodyweight: naik ke variasi lebih sulit.
  naikVariasi,

  /// Masih di dalam rentang: tambah satu rep.
  naikRep,

  /// Tahanan isometrik ditambah.
  naikDurasi,

  /// Belum sampai target bawah: mantapkan dulu di level yang sama.
  pertahankan,
}

class OverloadSuggestion {
  const OverloadSuggestion({
    required this.exerciseName,
    required this.type,
    required this.advice,
    required this.reason,
    required this.lastLabel,
    required this.targetLabel,
    this.targetExerciseName,
    this.targetWeight,
    this.targetSets,
    this.targetReps,
    this.targetSeconds,
    this.targetLevel,
  });

  final String exerciseName;
  final ExerciseType type;
  final OverloadAdvice advice;
  final String reason;

  /// Ringkasan sesi terakhir, mis. "40 kg x 3x8" atau "Plank 45 detik".
  final String lastLabel;

  /// Ringkasan target berikutnya, format sama dengan [lastLabel].
  final String targetLabel;

  /// Nama latihan yang disarankan — berbeda dari [exerciseName] kalau
  /// sarannya naik ke variasi bodyweight berikutnya.
  final String? targetExerciseName;

  final double? targetWeight;
  final int? targetSets;
  final int? targetReps;
  final int? targetSeconds;
  final int? targetLevel;
}

String formatWeight(double value) =>
    value == value.roundToDouble() ? value.round().toString() : value.toString();

/// Saran beban/rep/variasi berikutnya untuk [exerciseName].
///
/// Aturannya bercabang per [ExerciseType]: latihan beban memakai double
/// progression (naik rep dulu, lalu kg), bodyweight naik ke variasi yang lebih
/// sulit setelah repnya banyak, dan isometrik menambah durasi tahanan.
///
/// Mengembalikan `null` kalau latihan itu belum pernah dicatat, catatan
/// terakhirnya tidak lengkap, atau tipenya cardio (progresinya tidak dimodelkan).
OverloadSuggestion? suggestOverload(String exerciseName, List<WorkoutSession> sessions) {
  final target = exerciseName.trim().toLowerCase();
  if (target.isEmpty) return null;

  // Urutkan menurun supaya entri pertama yang cocok adalah yang terbaru.
  // `sessions` dari repository memang sudah menurun, tapi jangan bergantung
  // pada urutan pemanggil.
  final sorted = [...sessions]..sort((a, b) => b.sessionDate.compareTo(a.sessionDate));

  final history = <ExerciseEntry>[];
  for (final session in sorted) {
    for (final exercise in session.exercises) {
      if (exercise.type == ExerciseType.cardio) continue;
      if (exercise.exerciseName.trim().toLowerCase() != target) continue;
      if (!_lengkap(exercise)) continue;
      history.add(exercise);
    }
  }

  if (history.isEmpty) return null;

  final last = history.first;
  final mandek = _duaSesiIdentik(history);

  return switch (last.type) {
    ExerciseType.beban => _saranBeban(last, mandek),
    ExerciseType.bodyweight => _saranBodyweight(last, mandek),
    ExerciseType.isometrik => _saranIsometrik(last, mandek),
    ExerciseType.cardio => null,
  };
}

bool _lengkap(ExerciseEntry entry) => switch (entry.type) {
      ExerciseType.beban => entry.weightKg != null && entry.sets != null && entry.reps != null,
      ExerciseType.bodyweight => entry.sets != null && entry.reps != null,
      ExerciseType.isometrik => entry.durationSeconds != null && entry.sets != null,
      ExerciseType.cardio => false,
    };

bool _duaSesiIdentik(List<ExerciseEntry> history) {
  if (history.length < 2) return false;
  final a = history[0];
  final b = history[1];
  return a.weightKg == b.weightKg &&
      a.sets == b.sets &&
      a.reps == b.reps &&
      a.durationSeconds == b.durationSeconds;
}

String _tambahCatatanMandek(String reason, bool mandek) =>
    mandek ? '$reason Sudah 2 sesi di angka yang sama.' : reason;

OverloadSuggestion _saranBeban(ExerciseEntry last, bool mandek) {
  final weight = last.weightKg!;
  final sets = last.sets!;
  final reps = last.reps!;

  final double targetWeight;
  final int targetReps;
  final OverloadAdvice advice;
  final String reason;

  if (reps >= kRepMax) {
    targetWeight = weight + kWeightIncrementKg;
    targetReps = kRepMin;
    advice = OverloadAdvice.naikBeban;
    reason = 'Rep sudah tembus $kRepMax, saatnya naik beban.';
  } else if (reps < kRepMin) {
    targetWeight = weight;
    targetReps = kRepMin;
    advice = OverloadAdvice.pertahankan;
    reason = 'Kejar dulu $kRepMin rep di beban ini sebelum nambah.';
  } else {
    targetWeight = weight;
    targetReps = reps + 1;
    advice = OverloadAdvice.naikRep;
    reason = 'Tambah 1 rep dulu, beban tetap.';
  }

  return OverloadSuggestion(
    exerciseName: last.exerciseName,
    type: ExerciseType.beban,
    advice: advice,
    reason: _tambahCatatanMandek(reason, mandek),
    lastLabel: '${formatWeight(weight)} kg x ${sets}x$reps',
    targetLabel: '${formatWeight(targetWeight)} kg x ${sets}x$targetReps',
    targetWeight: targetWeight,
    targetSets: sets,
    targetReps: targetReps,
  );
}

OverloadSuggestion _saranBodyweight(ExerciseEntry last, bool mandek) {
  final sets = last.sets!;
  final reps = last.reps!;
  final ladder = ladderFor(last.exerciseName);

  // Level tersimpan bisa tertinggal kalau user mengetik nama variasi langsung,
  // jadi nama latihan yang menang kalau keduanya berbeda.
  final level = ladder == null
      ? last.progressionLevel
      : (levelOf(ladder, last.exerciseName) ?? last.progressionLevel);

  final lastLabel = '${last.exerciseName} ${sets}x$reps';

  if (reps >= kBodyweightRepMax) {
    final bisaNaik = ladder != null && !ladder.isLast(level);
    if (bisaNaik) {
      final next = ladder.stepAt(level + 1);
      return OverloadSuggestion(
        exerciseName: last.exerciseName,
        type: ExerciseType.bodyweight,
        advice: OverloadAdvice.naikVariasi,
        reason: _tambahCatatanMandek(
          'Rep sudah tembus $kBodyweightRepMax. Naik ke ${next.name}'
          '${next.cue != null ? " - ${next.cue}" : ""}.',
          mandek,
        ),
        lastLabel: lastLabel,
        targetLabel: '${next.name} ${sets}x$kBodyweightRepMin',
        targetExerciseName: next.name,
        targetSets: sets,
        targetReps: kBodyweightRepMin,
        targetLevel: level + 1,
      );
    }

    // Sudah di puncak tangga (atau tidak punya tangga): lanjut tambah rep.
    return OverloadSuggestion(
      exerciseName: last.exerciseName,
      type: ExerciseType.bodyweight,
      advice: OverloadAdvice.naikRep,
      reason: _tambahCatatanMandek(
        ladder == null
            ? 'Belum ada tangga variasi untuk latihan ini, tambah rep saja.'
            : 'Sudah di variasi tersulit. Tambah rep atau beban tambahan.',
        mandek,
      ),
      lastLabel: lastLabel,
      targetLabel: '${last.exerciseName} ${sets}x${reps + 1}',
      targetExerciseName: last.exerciseName,
      targetSets: sets,
      targetReps: reps + 1,
      targetLevel: level,
    );
  }

  if (reps < kBodyweightRepMin) {
    return OverloadSuggestion(
      exerciseName: last.exerciseName,
      type: ExerciseType.bodyweight,
      advice: OverloadAdvice.pertahankan,
      reason: _tambahCatatanMandek(
        'Kejar dulu $kBodyweightRepMin rep di variasi ini.',
        mandek,
      ),
      lastLabel: lastLabel,
      targetLabel: '${last.exerciseName} ${sets}x$kBodyweightRepMin',
      targetExerciseName: last.exerciseName,
      targetSets: sets,
      targetReps: kBodyweightRepMin,
      targetLevel: level,
    );
  }

  return OverloadSuggestion(
    exerciseName: last.exerciseName,
    type: ExerciseType.bodyweight,
    advice: OverloadAdvice.naikRep,
    reason: _tambahCatatanMandek('Tambah 1 rep dulu sebelum naik variasi.', mandek),
    lastLabel: lastLabel,
    targetLabel: '${last.exerciseName} ${sets}x${reps + 1}',
    targetExerciseName: last.exerciseName,
    targetSets: sets,
    targetReps: reps + 1,
    targetLevel: level,
  );
}

OverloadSuggestion _saranIsometrik(ExerciseEntry last, bool mandek) {
  final sets = last.sets!;
  final seconds = last.durationSeconds!;
  final ladder = ladderFor(last.exerciseName);
  final level = ladder == null
      ? last.progressionLevel
      : (levelOf(ladder, last.exerciseName) ?? last.progressionLevel);

  final lastLabel = '${last.exerciseName} ${sets}x$seconds detik';

  if (seconds >= kHoldMaxSeconds) {
    final bisaNaik = ladder != null && !ladder.isLast(level);
    if (bisaNaik) {
      final next = ladder.stepAt(level + 1);
      return OverloadSuggestion(
        exerciseName: last.exerciseName,
        type: ExerciseType.isometrik,
        advice: OverloadAdvice.naikVariasi,
        reason: _tambahCatatanMandek(
          'Tahan sudah $kHoldMaxSeconds detik. Naik ke ${next.name}'
          '${next.cue != null ? " - ${next.cue}" : ""}.',
          mandek,
        ),
        lastLabel: lastLabel,
        targetLabel: '${next.name} ${sets}x$kHoldMinSeconds detik',
        targetExerciseName: next.name,
        targetSets: sets,
        targetSeconds: kHoldMinSeconds,
        targetLevel: level + 1,
      );
    }

    return OverloadSuggestion(
      exerciseName: last.exerciseName,
      type: ExerciseType.isometrik,
      advice: OverloadAdvice.naikDurasi,
      reason: _tambahCatatanMandek(
        ladder == null
            ? 'Belum ada tangga variasi untuk latihan ini, tambah durasi saja.'
            : 'Sudah di variasi tersulit. Tambah durasi tahanan.',
        mandek,
      ),
      lastLabel: lastLabel,
      targetLabel: '${last.exerciseName} ${sets}x${seconds + kHoldIncrementSeconds} detik',
      targetExerciseName: last.exerciseName,
      targetSets: sets,
      targetSeconds: seconds + kHoldIncrementSeconds,
      targetLevel: level,
    );
  }

  return OverloadSuggestion(
    exerciseName: last.exerciseName,
    type: ExerciseType.isometrik,
    advice: OverloadAdvice.naikDurasi,
    reason: _tambahCatatanMandek(
      'Tambah $kHoldIncrementSeconds detik sampai tembus $kHoldMaxSeconds detik.',
      mandek,
    ),
    lastLabel: lastLabel,
    targetLabel: '${last.exerciseName} ${sets}x${seconds + kHoldIncrementSeconds} detik',
    targetExerciseName: last.exerciseName,
    targetSets: sets,
    targetSeconds: seconds + kHoldIncrementSeconds,
    targetLevel: level,
  );
}
