import 'package:flutter_test/flutter_test.dart';
import 'package:tracking/features/workout/data/models/exercise_entry.dart';
import 'package:tracking/features/workout/data/models/workout_session.dart';
import 'package:tracking/features/workout/domain/exercise_progress.dart';

ExerciseEntry _entry(
  String name, {
  ExerciseType type = ExerciseType.beban,
  double? weight,
  int? sets,
  int? reps,
  int? holdSeconds,
  int? minutes,
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
    durationMinutes: minutes,
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

ExerciseProgress _find(List<ExerciseProgress> list, String name) =>
    list.firstWhere((p) => p.name.toLowerCase() == name.toLowerCase());

void main() {
  final h1 = DateTime(2026, 7, 20);
  final h2 = DateTime(2026, 7, 25);
  final h3 = DateTime(2026, 7, 30);

  group('metrik per tipe latihan', () {
    test('beban memakai kilogram', () {
      final list = buildExerciseProgress([
        _session(h1, [_entry('Bench Press', weight: 40, sets: 3, reps: 8)]),
        _session(h2, [_entry('Bench Press', weight: 45, sets: 3, reps: 8)]),
      ]);

      final bench = _find(list, 'Bench Press');
      expect(bench.metric, ProgressMetric.beban);
      expect(bench.metric.unit, 'kg');
      expect(bench.latest, 45);
      expect(bench.delta, 5);
    });

    test('bodyweight memakai rep, bukan kilogram', () {
      // Ini kasus yang dulu bikin Push Up muncul di daftar tapi grafiknya kosong.
      final list = buildExerciseProgress([
        _session(h1, [_entry('Push Up', type: ExerciseType.bodyweight, sets: 3, reps: 10)]),
        _session(h2, [_entry('Push Up', type: ExerciseType.bodyweight, sets: 3, reps: 14)]),
      ]);

      final pushUp = _find(list, 'Push Up');
      expect(pushUp.metric, ProgressMetric.rep);
      expect(pushUp.points, hasLength(2));
      expect(pushUp.latest, 14);
      expect(pushUp.delta, 4);
    });

    test('isometrik memakai detik tahanan', () {
      final list = buildExerciseProgress([
        _session(h1, [_entry('Plank', type: ExerciseType.isometrik, sets: 3, holdSeconds: 40)]),
        _session(h2, [_entry('Plank', type: ExerciseType.isometrik, sets: 3, holdSeconds: 55)]),
      ]);

      final plank = _find(list, 'Plank');
      expect(plank.metric, ProgressMetric.tahanan);
      expect(plank.metric.unit, 'detik');
      expect(plank.best, 55);
    });

    test('cardio ikut terhitung dan memakai menit', () {
      final list = buildExerciseProgress([
        _session(h1, [_entry('Lari', type: ExerciseType.cardio, minutes: 20)]),
        _session(h2, [_entry('Lari', type: ExerciseType.cardio, minutes: 30)]),
      ]);

      final lari = _find(list, 'Lari');
      expect(lari.metric, ProgressMetric.durasi);
      expect(lari.latest, 30);
    });
  });

  group('volume', () {
    test('bodyweight tanpa beban tambahan tidak punya volume', () {
      final list = buildExerciseProgress([
        _session(h1, [_entry('Push Up', type: ExerciseType.bodyweight, sets: 3, reps: 10)]),
      ]);

      expect(_find(list, 'Push Up').hasVolume, isFalse);
    });

    test('bodyweight dengan beban tambahan punya volume', () {
      final list = buildExerciseProgress([
        _session(h1, [
          _entry('Dip', type: ExerciseType.bodyweight, weight: 10, sets: 3, reps: 8),
        ]),
      ]);

      expect(_find(list, 'Dip').hasVolume, isTrue);
    });

    test('isometrik tidak punya volume meski ada beban', () {
      final list = buildExerciseProgress([
        _session(h1, [
          _entry('Plank', type: ExerciseType.isometrik, weight: 5, sets: 3, holdSeconds: 40),
        ]),
      ]);

      expect(_find(list, 'Plank').hasVolume, isFalse);
    });
  });

  group('pengumpulan data', () {
    test('titik diurutkan dari sesi terlama meski input acak', () {
      final list = buildExerciseProgress([
        _session(h3, [_entry('Squat', weight: 70, sets: 3, reps: 8)]),
        _session(h1, [_entry('Squat', weight: 60, sets: 3, reps: 8)]),
        _session(h2, [_entry('Squat', weight: 65, sets: 3, reps: 8)]),
      ]);

      final squat = _find(list, 'Squat');
      expect([for (final p in squat.points) p.value], [60, 65, 70]);
      expect(squat.delta, 10);
    });

    test('nama latihan digabung tanpa memandang huruf besar/kecil', () {
      final list = buildExerciseProgress([
        _session(h1, [_entry('bench press', weight: 40, sets: 3, reps: 8)]),
        _session(h2, [_entry('Bench Press', weight: 45, sets: 3, reps: 8)]),
      ]);

      expect(list, hasLength(1));
      // Ejaan terbaru yang dipakai untuk ditampilkan.
      expect(list.first.name, 'Bench Press');
      expect(list.first.sessionCount, 2);
    });

    test('catatan tanpa angka metrik dilewati', () {
      final list = buildExerciseProgress([
        // Beban tanpa kg, bodyweight tanpa rep, isometrik tanpa detik.
        _session(h1, [
          _entry('Bench Press', sets: 3, reps: 8),
          _entry('Push Up', type: ExerciseType.bodyweight, sets: 3),
          _entry('Plank', type: ExerciseType.isometrik, sets: 3),
        ]),
      ]);

      expect(list, isEmpty);
    });

    test('daftar diurutkan dari latihan yang paling baru dicatat', () {
      final list = buildExerciseProgress([
        _session(h1, [_entry('Squat', weight: 60, sets: 3, reps: 8)]),
        _session(h3, [_entry('Bench Press', weight: 40, sets: 3, reps: 8)]),
      ]);

      expect(list.first.name, 'Bench Press');
      expect(list.last.name, 'Squat');
    });

    test('satu sesi tetap muncul dengan delta nol', () {
      final list = buildExerciseProgress([
        _session(h1, [_entry('Row', weight: 30, sets: 3, reps: 10)]),
      ]);

      final row = _find(list, 'Row');
      expect(row.sessionCount, 1);
      expect(row.delta, 0);
      expect(row.best, 30);
    });

    test('tanpa sesi mengembalikan daftar kosong', () {
      expect(buildExerciseProgress(const []), isEmpty);
    });
  });
}
