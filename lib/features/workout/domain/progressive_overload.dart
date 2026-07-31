import '../data/models/exercise_entry.dart';
import '../data/models/workout_session.dart';

/// Kenaikan beban standar untuk latihan beban. 2.5 kg adalah lompatan terkecil
/// yang umum tersedia di gym (2 keping 1.25 kg).
const double kWeightIncrementKg = 2.5;

/// Rentang rep target. Selama rep masih di bawah [kRepMax], naikkan rep dulu;
/// begitu tembus, baru bebannya yang naik dan rep balik ke [kRepMin].
const int kRepMin = 8;
const int kRepMax = 12;

enum OverloadAdvice {
  /// Rep sudah tembus batas atas: saatnya menambah beban.
  naikBeban,

  /// Masih di dalam rentang: tambah satu rep.
  naikRep,

  /// Rep masih di bawah target: mantapkan dulu di beban yang sama.
  pertahankan,
}

class OverloadSuggestion {
  const OverloadSuggestion({
    required this.exerciseName,
    required this.lastWeight,
    required this.lastSets,
    required this.lastReps,
    required this.targetWeight,
    required this.targetSets,
    required this.targetReps,
    required this.advice,
    required this.reason,
  });

  final String exerciseName;
  final double lastWeight;
  final int lastSets;
  final int lastReps;
  final double targetWeight;
  final int targetSets;
  final int targetReps;
  final OverloadAdvice advice;
  final String reason;

  String get lastLabel => '${_formatWeight(lastWeight)} kg x ${lastSets}x$lastReps';
  String get targetLabel => '${_formatWeight(targetWeight)} kg x ${targetSets}x$targetReps';
}

String _formatWeight(double value) =>
    value == value.roundToDouble() ? value.round().toString() : value.toString();

/// Saran beban/rep berikutnya untuk [exerciseName], memakai pola *double
/// progression*: rep dinaikkan dulu sampai batas atas, baru bebannya naik.
///
/// Mengembalikan `null` kalau latihan itu belum pernah dicatat, atau catatan
/// terakhirnya tidak lengkap (mis. cardio, atau berat/set/rep kosong) sehingga
/// tidak ada dasar untuk menghitung.
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
      if (exercise.isCardio) continue;
      if (exercise.exerciseName.trim().toLowerCase() != target) continue;
      if (exercise.weightKg == null || exercise.sets == null || exercise.reps == null) {
        continue;
      }
      history.add(exercise);
    }
  }

  if (history.isEmpty) return null;

  final last = history.first;
  final weight = last.weightKg!;
  final sets = last.sets!;
  final reps = last.reps!;

  final double targetWeight;
  final int targetReps;
  final OverloadAdvice advice;
  final String baseReason;

  if (reps >= kRepMax) {
    targetWeight = weight + kWeightIncrementKg;
    targetReps = kRepMin;
    advice = OverloadAdvice.naikBeban;
    baseReason = 'Rep sudah tembus $kRepMax, saatnya naik beban.';
  } else if (reps < kRepMin) {
    targetWeight = weight;
    targetReps = kRepMin;
    advice = OverloadAdvice.pertahankan;
    baseReason = 'Kejar dulu $kRepMin rep di beban ini sebelum nambah.';
  } else {
    targetWeight = weight;
    targetReps = reps + 1;
    advice = OverloadAdvice.naikRep;
    baseReason = 'Tambah 1 rep dulu, beban tetap.';
  }

  // Kalau dua sesi terakhir identik, kasih tahu supaya user sadar sedang mandek.
  var reason = baseReason;
  if (history.length >= 2) {
    final previous = history[1];
    if (previous.weightKg == weight && previous.sets == sets && previous.reps == reps) {
      reason = '$baseReason Sudah 2 sesi di angka yang sama.';
    }
  }

  return OverloadSuggestion(
    exerciseName: last.exerciseName,
    lastWeight: weight,
    lastSets: sets,
    lastReps: reps,
    targetWeight: targetWeight,
    targetSets: sets,
    targetReps: targetReps,
    advice: advice,
    reason: reason,
  );
}
