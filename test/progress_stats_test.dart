import 'package:flutter_test/flutter_test.dart';
import 'package:tracking/features/body/domain/body_profile.dart';
import 'package:tracking/features/nutrition/domain/food_log.dart';
import 'package:tracking/features/progress/domain/progress_stats.dart';
import 'package:tracking/features/workout/data/models/exercise_entry.dart';
import 'package:tracking/features/workout/data/models/workout_session.dart';

final _now = DateTime(2026, 7, 31);

DateTime _daysAgo(int days) => _now.subtract(Duration(days: days));

WeightLog _weight(int daysAgo, double kg) =>
    WeightLog(loggedOn: _daysAgo(daysAgo), weightKg: kg);

FoodLog _food(
  int daysAgo, {
  double calories = 500,
  double protein = 30,
  double carbs = 60,
  double fat = 15,
}) {
  final date = _daysAgo(daysAgo);
  return FoodLog(
    id: '$daysAgo-$calories',
    loggedOn: date,
    loggedAt: date,
    name: 'Makanan',
    meal: Meal.makanSiang,
    calories: calories,
    proteinG: protein,
    carbsG: carbs,
    fatG: fat,
  );
}

WorkoutSession _session(int daysAgo, {List<ExerciseEntry> exercises = const []}) {
  final date = _daysAgo(daysAgo);
  return WorkoutSession(
    id: '$daysAgo',
    userId: 'u',
    sessionDate: date,
    createdAt: date,
    exercises: exercises,
  );
}

ExerciseEntry _entry({
  ExerciseType type = ExerciseType.beban,
  double? weight,
  int? sets,
  int? reps,
}) {
  return ExerciseEntry(
    id: 'e',
    sessionId: 's',
    userId: 'u',
    exerciseName: 'Bench Press',
    type: type,
    weightKg: weight,
    sets: sets,
    reps: reps,
  );
}

ProgressStats _stats({
  StatsPeriod period = StatsPeriod.bulan,
  List<WeightLog> weights = const [],
  List<FoodLog> foods = const [],
  List<WorkoutSession> sessions = const [],
  double? target,
}) {
  return computeProgressStats(
    period: period,
    now: _now,
    weights: weights,
    foods: foods,
    sessions: sessions,
    targetWeightKg: target,
  );
}

void main() {
  group('rentang periode', () {
    test('hanya menghitung data di dalam periode', () {
      final stats = _stats(
        period: StatsPeriod.minggu,
        weights: [_weight(2, 70), _weight(20, 75)],
        foods: [_food(1), _food(20)],
        sessions: [_session(3), _session(20)],
      );

      expect(stats.weight.points, hasLength(1));
      expect(stats.nutrition.daysLogged, 1);
      expect(stats.workout.totalSessions, 1);
    });

    test('hari ini termasuk di dalam periode', () {
      final stats = _stats(period: StatsPeriod.minggu, weights: [_weight(0, 70)]);
      expect(stats.weight.points, hasLength(1));
    });

    test('periode 7 hari mencakup tepat 7 hari termasuk hari ini', () {
      final stats = _stats(
        period: StatsPeriod.minggu,
        weights: [_weight(6, 70), _weight(7, 71)],
      );
      expect(stats.weight.points, hasLength(1));
      expect(stats.weight.points.first.value, 70);
    });

    test('semua kosong ditandai kosong', () {
      expect(_stats().kosong, isTrue);
    });
  });

  group('berat badan', () {
    test('perubahan dihitung dari catatan pertama ke terakhir', () {
      final stats = _stats(weights: [_weight(20, 75), _weight(10, 73), _weight(1, 72)]);

      expect(stats.weight.startWeight, 75);
      expect(stats.weight.currentWeight, 72);
      expect(stats.weight.change, -3);
    });

    test('titik diurutkan terlama dulu meski input acak', () {
      final stats = _stats(weights: [_weight(1, 72), _weight(20, 75), _weight(10, 73)]);

      expect([for (final p in stats.weight.points) p.value], [75, 73, 72]);
    });

    test('satu catatan berarti perubahan nol', () {
      final stats = _stats(weights: [_weight(1, 72)]);
      expect(stats.weight.change, 0);
    });

    test('persentase target dihitung dari jarak awal ke target', () {
      // Awal 80, target 70, sekarang 75 -> setengah jalan.
      final stats = _stats(weights: [_weight(20, 80), _weight(1, 75)], target: 70);

      expect(stats.weight.targetProgressPercent, closeTo(50, 0.01));
    });

    test('persentase target dibatasi 0-100', () {
      // Sudah melewati target: 80 -> 65 dengan target 70.
      final lewat = _stats(weights: [_weight(20, 80), _weight(1, 65)], target: 70);
      expect(lewat.weight.targetProgressPercent, 100);

      // Bergerak menjauh dari target.
      final mundur = _stats(weights: [_weight(20, 80), _weight(1, 85)], target: 70);
      expect(mundur.weight.targetProgressPercent, 0);
    });

    test('persentase null kalau target belum diisi atau sama dengan berat awal', () {
      expect(_stats(weights: [_weight(1, 75)]).weight.targetProgressPercent, isNull);
      expect(
        _stats(weights: [_weight(1, 70)], target: 70).weight.targetProgressPercent,
        isNull,
      );
    });
  });

  group('nutrisi', () {
    test('menjumlahkan per hari lalu dirata-rata', () {
      final stats = _stats(
        foods: [
          _food(1, calories: 400, protein: 20),
          _food(1, calories: 600, protein: 40),
          _food(2, calories: 500, protein: 30),
        ],
      );

      expect(stats.nutrition.daysLogged, 2);
      // Hari pertama 1000, hari kedua 500 -> rata-rata 750.
      expect(stats.nutrition.avgCalories, 750);
      expect(stats.nutrition.avgProtein, 45);
    });

    test('rata-rata dibagi hari yang tercatat, bukan panjang periode', () {
      // Satu hari tercatat 2000 kkal dalam periode 30 hari: rata-ratanya 2000,
      // bukan 2000/30. Hari yang lupa dicatat bukan berarti nol asupan.
      final stats = _stats(foods: [_food(1, calories: 2000)]);

      expect(stats.nutrition.daysLogged, 1);
      expect(stats.nutrition.avgCalories, 2000);
    });

    test('titik grafik diurutkan menurut tanggal', () {
      final stats = _stats(
        foods: [_food(1, calories: 100), _food(5, calories: 200), _food(3, calories: 300)],
      );

      expect(
        [for (final p in stats.nutrition.calories) p.value],
        [200, 300, 100],
      );
    });

    test('tanpa catatan ditandai kosong tanpa membagi nol', () {
      final stats = _stats();
      expect(stats.nutrition.kosong, isTrue);
      expect(stats.nutrition.avgCalories, 0);
    });
  });

  group('latihan', () {
    test('total set, rep, dan volume dijumlahkan', () {
      final stats = _stats(
        sessions: [
          _session(1, exercises: [_entry(weight: 40, sets: 3, reps: 10)]),
          _session(2, exercises: [_entry(weight: 50, sets: 4, reps: 8)]),
        ],
      );

      expect(stats.workout.totalSessions, 2);
      expect(stats.workout.totalSets, 7);
      // Rep dihitung per set: 3x10 + 4x8 = 62.
      expect(stats.workout.totalReps, 62);
      // Volume: 40*3*10 + 50*4*8 = 1200 + 1600.
      expect(stats.workout.totalVolume, 2800);
    });

    test('cardio menambah set tapi tidak menambah rep', () {
      final stats = _stats(
        sessions: [
          _session(1, exercises: [_entry(type: ExerciseType.cardio, sets: 2)]),
        ],
      );

      expect(stats.workout.totalSets, 2);
      expect(stats.workout.totalReps, 0);
    });

    test('bodyweight tanpa beban tidak menambah volume tapi menambah rep', () {
      final stats = _stats(
        sessions: [
          _session(1, exercises: [_entry(type: ExerciseType.bodyweight, sets: 3, reps: 12)]),
        ],
      );

      expect(stats.workout.totalReps, 36);
      expect(stats.workout.totalVolume, 0);
    });

    test('sesi dikelompokkan per minggu dari awal periode', () {
      final stats = _stats(
        period: StatsPeriod.bulan,
        sessions: [
          // Periode 30 hari dimulai 29 hari lalu; minggu 0 = hari ke-29..23.
          _session(29),
          _session(25),
          _session(1),
        ],
      );

      expect(stats.workout.weeklySessions.first.value, 2);
      expect(stats.workout.weeklySessions.last.value, 1);
    });

    test('tanpa sesi ditandai kosong', () {
      expect(_stats().workout.kosong, isTrue);
    });
  });
}
