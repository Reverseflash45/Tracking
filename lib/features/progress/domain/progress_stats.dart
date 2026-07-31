import '../../body/domain/body_profile.dart';
import '../../nutrition/domain/food_log.dart';
import '../../workout/data/models/workout_session.dart';

enum StatsPeriod {
  minggu('7 Hari', 7),
  bulan('30 Hari', 30),
  tigaBulan('90 Hari', 90);

  const StatsPeriod(this.label, this.days);

  final String label;
  final int days;
}

DateTime _dayKey(DateTime date) => DateTime(date.year, date.month, date.day);

class DailyPoint {
  const DailyPoint(this.date, this.value);

  final DateTime date;
  final double value;
}

class WeightProgress {
  const WeightProgress({
    required this.points,
    required this.targetWeightKg,
  });

  /// Catatan berat di dalam periode, terlama dulu.
  final List<DailyPoint> points;
  final double? targetWeightKg;

  bool get kosong => points.isEmpty;

  double? get startWeight => points.isEmpty ? null : points.first.value;
  double? get currentWeight => points.isEmpty ? null : points.last.value;

  /// Perubahan berat sepanjang periode. Negatif berarti turun.
  double get change => points.length < 2 ? 0 : points.last.value - points.first.value;

  /// Seberapa jauh perjalanan dari berat awal menuju target, 0-100.
  ///
  /// Null kalau target belum diisi, atau kalau berat awal sudah sama dengan
  /// target (tidak ada jarak yang bisa dipersenkan).
  double? get targetProgressPercent {
    final target = targetWeightKg;
    final start = startWeight;
    final current = currentWeight;
    if (target == null || start == null || current == null) return null;

    final jarakAwal = target - start;
    if (jarakAwal.abs() < 0.01) return null;

    final sudahDitempuh = current - start;
    final persen = (sudahDitempuh / jarakAwal) * 100;
    return persen.clamp(0, 100).toDouble();
  }
}

class NutritionTrend {
  const NutritionTrend({
    required this.calories,
    required this.protein,
    required this.avgCalories,
    required this.avgProtein,
    required this.avgCarbs,
    required this.avgFat,
    required this.daysLogged,
  });

  /// Total per hari, hanya hari yang ada catatannya.
  final List<DailyPoint> calories;
  final List<DailyPoint> protein;

  /// Rata-rata dihitung dari hari yang tercatat saja, bukan dibagi seluruh
  /// panjang periode — hari yang lupa dicatat bukan berarti nol asupan.
  final double avgCalories;
  final double avgProtein;
  final double avgCarbs;
  final double avgFat;

  final int daysLogged;

  bool get kosong => daysLogged == 0;
}

class WorkoutTrend {
  const WorkoutTrend({
    required this.weeklySessions,
    required this.totalSessions,
    required this.totalSets,
    required this.totalReps,
    required this.totalVolume,
  });

  /// Jumlah sesi per minggu, dimulai dari minggu terlama dalam periode.
  final List<DailyPoint> weeklySessions;

  final int totalSessions;
  final int totalSets;
  final int totalReps;
  final double totalVolume;

  bool get kosong => totalSessions == 0;
}

class ProgressStats {
  const ProgressStats({
    required this.period,
    required this.since,
    required this.weight,
    required this.nutrition,
    required this.workout,
  });

  final StatsPeriod period;
  final DateTime since;
  final WeightProgress weight;
  final NutritionTrend nutrition;
  final WorkoutTrend workout;

  bool get kosong => weight.kosong && nutrition.kosong && workout.kosong;
}

ProgressStats computeProgressStats({
  required StatsPeriod period,
  required DateTime now,
  required List<WeightLog> weights,
  required List<FoodLog> foods,
  required List<WorkoutSession> sessions,
  double? targetWeightKg,
}) {
  final today = _dayKey(now);
  final since = today.subtract(Duration(days: period.days - 1));

  bool didalam(DateTime date) {
    final key = _dayKey(date);
    return !key.isBefore(since) && !key.isAfter(today);
  }

  return ProgressStats(
    period: period,
    since: since,
    weight: _weightProgress(weights, didalam, targetWeightKg),
    nutrition: _nutritionTrend(foods, didalam),
    workout: _workoutTrend(sessions, didalam, since),
  );
}

WeightProgress _weightProgress(
  List<WeightLog> weights,
  bool Function(DateTime) didalam,
  double? targetWeightKg,
) {
  final dalamPeriode = weights.where((w) => didalam(w.loggedOn)).toList()
    ..sort((a, b) => a.loggedOn.compareTo(b.loggedOn));

  return WeightProgress(
    points: [for (final w in dalamPeriode) DailyPoint(_dayKey(w.loggedOn), w.weightKg)],
    targetWeightKg: targetWeightKg,
  );
}

NutritionTrend _nutritionTrend(List<FoodLog> foods, bool Function(DateTime) didalam) {
  final perHari = <DateTime, List<FoodLog>>{};
  for (final food in foods) {
    if (!didalam(food.loggedOn)) continue;
    perHari.putIfAbsent(_dayKey(food.loggedOn), () => []).add(food);
  }

  if (perHari.isEmpty) {
    return const NutritionTrend(
      calories: [],
      protein: [],
      avgCalories: 0,
      avgProtein: 0,
      avgCarbs: 0,
      avgFat: 0,
      daysLogged: 0,
    );
  }

  final tanggal = perHari.keys.toList()..sort();

  final calories = <DailyPoint>[];
  final protein = <DailyPoint>[];
  var totalKcal = 0.0;
  var totalProtein = 0.0;
  var totalCarbs = 0.0;
  var totalFat = 0.0;

  for (final date in tanggal) {
    final list = perHari[date]!;
    final kcal = list.fold<double>(0, (sum, f) => sum + f.calories);
    final p = list.fold<double>(0, (sum, f) => sum + f.proteinG);

    calories.add(DailyPoint(date, kcal));
    protein.add(DailyPoint(date, p));

    totalKcal += kcal;
    totalProtein += p;
    totalCarbs += list.fold<double>(0, (sum, f) => sum + f.carbsG);
    totalFat += list.fold<double>(0, (sum, f) => sum + f.fatG);
  }

  final hari = tanggal.length;
  return NutritionTrend(
    calories: calories,
    protein: protein,
    avgCalories: totalKcal / hari,
    avgProtein: totalProtein / hari,
    avgCarbs: totalCarbs / hari,
    avgFat: totalFat / hari,
    daysLogged: hari,
  );
}

WorkoutTrend _workoutTrend(
  List<WorkoutSession> sessions,
  bool Function(DateTime) didalam,
  DateTime since,
) {
  final dalamPeriode = sessions.where((s) => didalam(s.sessionDate)).toList()
    ..sort((a, b) => a.sessionDate.compareTo(b.sessionDate));

  var totalSets = 0;
  var totalReps = 0;
  var totalVolume = 0.0;

  for (final session in dalamPeriode) {
    for (final exercise in session.exercises) {
      final sets = exercise.sets ?? 0;
      totalSets += sets;
      // Rep dihitung per set: 3 set x 10 rep = 30 repetisi.
      if (exercise.type.pakaiRep) totalReps += sets * (exercise.reps ?? 0);
      totalVolume += exercise.volume;
    }
  }

  // Kelompokkan per minggu dihitung dari awal periode, bukan dari hari Senin,
  // supaya kolom terakhir selalu berisi minggu berjalan yang utuh.
  final perMinggu = <int, int>{};
  for (final session in dalamPeriode) {
    final selisihHari = _dayKey(session.sessionDate).difference(since).inDays;
    final minggu = selisihHari ~/ 7;
    perMinggu[minggu] = (perMinggu[minggu] ?? 0) + 1;
  }

  final weekly = <DailyPoint>[];
  if (perMinggu.isNotEmpty) {
    final maxMinggu = perMinggu.keys.reduce((a, b) => a > b ? a : b);
    for (var i = 0; i <= maxMinggu; i++) {
      weekly.add(DailyPoint(
        since.add(Duration(days: i * 7)),
        (perMinggu[i] ?? 0).toDouble(),
      ));
    }
  }

  return WorkoutTrend(
    weeklySessions: weekly,
    totalSessions: dalamPeriode.length,
    totalSets: totalSets,
    totalReps: totalReps,
    totalVolume: totalVolume,
  );
}
