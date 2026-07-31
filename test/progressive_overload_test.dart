import 'package:flutter_test/flutter_test.dart';
import 'package:tracking/features/workout/data/models/exercise_entry.dart';
import 'package:tracking/features/workout/data/models/workout_session.dart';
import 'package:tracking/features/workout/domain/progressive_overload.dart';

ExerciseEntry _entry(
  String name, {
  ExerciseType type = ExerciseType.beban,
  double? weight,
  int? sets,
  int? reps,
  int? holdSeconds,
  int level = 0,
}) {
  return ExerciseEntry(
    id: 'e',
    sessionId: 's',
    userId: 'u',
    exerciseName: name,
    type: type,
    weightKg: weight,
    sets: sets,
    reps: reps,
    durationSeconds: holdSeconds,
    progressionLevel: level,
  );
}

WorkoutSession _session(DateTime date, List<ExerciseEntry> exercises) {
  return WorkoutSession(
    id: date.toIso8601String(),
    userId: 'u',
    sessionDate: date,
    createdAt: date,
    exercises: exercises,
  );
}

void main() {
  final hariIni = DateTime(2026, 7, 31);
  final kemarin = DateTime(2026, 7, 30);

  group('suggestOverload - latihan beban', () {
    test('rep tembus batas atas -> naik beban, rep balik ke minimum', () {
      final sessions = [
        _session(hariIni, [_entry('Bench Press', weight: 40, sets: 3, reps: 12)]),
      ];

      final result = suggestOverload('Bench Press', sessions);

      expect(result, isNotNull);
      expect(result!.advice, OverloadAdvice.naikBeban);
      expect(result.targetWeight, 42.5);
      expect(result.targetReps, kRepMin);
      expect(result.targetSets, 3);
    });

    test('rep di dalam rentang -> tambah satu rep, beban tetap', () {
      final sessions = [
        _session(hariIni, [_entry('Squat', weight: 60, sets: 3, reps: 9)]),
      ];

      final result = suggestOverload('Squat', sessions);

      expect(result!.advice, OverloadAdvice.naikRep);
      expect(result.targetWeight, 60);
      expect(result.targetReps, 10);
    });

    test('rep di bawah minimum -> pertahankan beban', () {
      final sessions = [
        _session(hariIni, [_entry('Deadlift', weight: 80, sets: 3, reps: 5)]),
      ];

      final result = suggestOverload('Deadlift', sessions);

      expect(result!.advice, OverloadAdvice.pertahankan);
      expect(result.targetWeight, 80);
      expect(result.targetReps, kRepMin);
    });

    test('memakai sesi terbaru meski urutan list acak', () {
      final sessions = [
        _session(kemarin, [_entry('Row', weight: 30, sets: 3, reps: 12)]),
        _session(hariIni, [_entry('Row', weight: 35, sets: 3, reps: 8)]),
      ];

      final result = suggestOverload('Row', sessions);

      expect(result!.lastLabel, contains('35'));
      expect(result.advice, OverloadAdvice.naikRep);
    });

    test('dua sesi identik ditandai sedang mandek', () {
      final sessions = [
        _session(hariIni, [_entry('Curl', weight: 15, sets: 3, reps: 10)]),
        _session(kemarin, [_entry('Curl', weight: 15, sets: 3, reps: 10)]),
      ];

      expect(suggestOverload('Curl', sessions)!.reason, contains('2 sesi'));
    });

    test('pencocokan nama tidak peduli huruf besar/kecil dan spasi', () {
      final sessions = [
        _session(hariIni, [_entry('Bench Press', weight: 40, sets: 3, reps: 9)]),
      ];

      expect(suggestOverload('  bench press  ', sessions), isNotNull);
    });

    test('null kalau belum ada riwayat', () {
      expect(suggestOverload('Bench Press', const []), isNull);
      expect(
        suggestOverload(
          'Bench Press',
          [_session(hariIni, [_entry('Squat', weight: 60, sets: 3, reps: 8)])],
        ),
        isNull,
      );
    });

    test('null kalau cardio atau datanya tidak lengkap', () {
      expect(
        suggestOverload('Lari', [_session(hariIni, [_entry('Lari', type: ExerciseType.cardio)])]),
        isNull,
      );
      expect(
        suggestOverload('Press', [_session(hariIni, [_entry('Press', sets: 3, reps: 10)])]),
        isNull,
      );
    });

    test('melewati entri tidak lengkap dan memakai entri lengkap terbaru', () {
      final sessions = [
        _session(hariIni, [_entry('Press', sets: 3, reps: 10)]), // berat kosong
        _session(kemarin, [_entry('Press', weight: 25, sets: 3, reps: 12)]),
      ];

      final result = suggestOverload('Press', sessions);

      expect(result, isNotNull);
      expect(result!.advice, OverloadAdvice.naikBeban);
      expect(result.targetWeight, 27.5);
    });
  });

  group('suggestOverload - bodyweight', () {
    ExerciseEntry bw(String name, int reps, {int sets = 3}) =>
        _entry(name, type: ExerciseType.bodyweight, sets: sets, reps: reps);

    test('rep tembus batas atas -> naik ke variasi berikutnya, rep balik ke minimum', () {
      final sessions = [
        _session(hariIni, [bw('Knee Push Up', kBodyweightRepMax)]),
      ];

      final result = suggestOverload('Knee Push Up', sessions);

      expect(result!.advice, OverloadAdvice.naikVariasi);
      expect(result.targetExerciseName, 'Push Up');
      expect(result.targetReps, kBodyweightRepMin);
      expect(result.targetLevel, 3);
    });

    test('rep di dalam rentang -> tambah rep, variasi tetap', () {
      final sessions = [
        _session(hariIni, [bw('Push Up', 10)]),
      ];

      final result = suggestOverload('Push Up', sessions);

      expect(result!.advice, OverloadAdvice.naikRep);
      expect(result.targetExerciseName, 'Push Up');
      expect(result.targetReps, 11);
    });

    test('rep di bawah minimum -> pertahankan variasi', () {
      final sessions = [
        _session(hariIni, [bw('Pull Up', 4)]),
      ];

      final result = suggestOverload('Pull Up', sessions);

      expect(result!.advice, OverloadAdvice.pertahankan);
      expect(result.targetReps, kBodyweightRepMin);
    });

    test('di puncak tangga -> tetap tambah rep, tidak naik variasi', () {
      final sessions = [
        _session(hariIni, [bw('One Arm Push Up', 20)]),
      ];

      final result = suggestOverload('One Arm Push Up', sessions);

      expect(result!.advice, OverloadAdvice.naikRep);
      expect(result.targetReps, 21);
      expect(result.reason, contains('tersulit'));
    });

    test('latihan tanpa tangga tetap dapat saran tambah rep', () {
      final sessions = [
        _session(hariIni, [bw('Gerakan Aneh', 20)]),
      ];

      final result = suggestOverload('Gerakan Aneh', sessions);

      expect(result!.advice, OverloadAdvice.naikRep);
      expect(result.reason, contains('Belum ada tangga'));
    });

    test('bodyweight tidak butuh kolom berat untuk dianggap lengkap', () {
      final sessions = [
        _session(hariIni, [bw('Push Up', 12)]),
      ];

      expect(suggestOverload('Push Up', sessions), isNotNull);
    });
  });

  group('suggestOverload - isometrik', () {
    ExerciseEntry iso(String name, int seconds) =>
        _entry(name, type: ExerciseType.isometrik, sets: 3, holdSeconds: seconds);

    test('tahanan di bawah batas -> tambah detik', () {
      final sessions = [
        _session(hariIni, [iso('Plank', 40)]),
      ];

      final result = suggestOverload('Plank', sessions);

      expect(result!.advice, OverloadAdvice.naikDurasi);
      expect(result.targetSeconds, 45);
    });

    test('tahanan tembus batas atas -> naik variasi, durasi balik ke minimum', () {
      final sessions = [
        _session(hariIni, [iso('Plank', kHoldMaxSeconds)]),
      ];

      final result = suggestOverload('Plank', sessions);

      expect(result!.advice, OverloadAdvice.naikVariasi);
      expect(result.targetExerciseName, 'Long Lever Plank');
      expect(result.targetSeconds, kHoldMinSeconds);
    });

    test('di puncak tangga isometrik -> tambah durasi saja', () {
      final sessions = [
        _session(hariIni, [iso('RKC Plank', 90)]),
      ];

      final result = suggestOverload('RKC Plank', sessions);

      expect(result!.advice, OverloadAdvice.naikDurasi);
      expect(result.targetSeconds, 95);
    });
  });
}
