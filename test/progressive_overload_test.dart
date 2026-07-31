import 'package:flutter_test/flutter_test.dart';
import 'package:tracking/features/workout/data/models/exercise_entry.dart';
import 'package:tracking/features/workout/data/models/workout_session.dart';
import 'package:tracking/features/workout/domain/progressive_overload.dart';

ExerciseEntry _entry(
  String name, {
  double? weight,
  int? sets,
  int? reps,
  bool isCardio = false,
}) {
  return ExerciseEntry(
    id: 'e',
    sessionId: 's',
    userId: 'u',
    exerciseName: name,
    weightKg: weight,
    sets: sets,
    reps: reps,
    isCardio: isCardio,
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

  group('suggestOverload', () {
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

      expect(result!.lastWeight, 35);
      expect(result.lastReps, 8);
    });

    test('dua sesi identik ditandai sedang mandek', () {
      final sessions = [
        _session(hariIni, [_entry('Curl', weight: 15, sets: 3, reps: 10)]),
        _session(kemarin, [_entry('Curl', weight: 15, sets: 3, reps: 10)]),
      ];

      final result = suggestOverload('Curl', sessions);

      expect(result!.reason, contains('2 sesi'));
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
        suggestOverload('Bench Press', [_session(hariIni, [_entry('Squat', weight: 60, sets: 3, reps: 8)])]),
        isNull,
      );
    });

    test('null kalau catatan terakhir cardio atau datanya tidak lengkap', () {
      final cardio = [
        _session(hariIni, [_entry('Lari', isCardio: true)]),
      ];
      expect(suggestOverload('Lari', cardio), isNull);

      final tanpaBeban = [
        _session(hariIni, [_entry('Plank', sets: 3, reps: 10)]),
      ];
      expect(suggestOverload('Plank', tanpaBeban), isNull);
    });

    test('melewati entri tidak lengkap dan memakai entri lengkap terbaru', () {
      final sessions = [
        _session(hariIni, [_entry('Press', sets: 3, reps: 10)]), // berat kosong
        _session(kemarin, [_entry('Press', weight: 25, sets: 3, reps: 12)]),
      ];

      final result = suggestOverload('Press', sessions);

      expect(result, isNotNull);
      expect(result!.lastWeight, 25);
      expect(result.advice, OverloadAdvice.naikBeban);
    });
  });
}
