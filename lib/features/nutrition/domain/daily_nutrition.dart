import 'food_log.dart';

/// Ukuran satu gelas air, dipakai tombol tambah cepat.
const int kGlassMl = 250;

/// Patokan minum harian, dipakai untuk menilai "cukup" atau "kurang".
///
/// Dua liter itu anjuran umum, bukan hitungan untuk tubuhmu — kebutuhan
/// sebenarnya bergantung berat badan dan aktivitas. Halaman Kalkulator Kalori
/// menghitung angka yang lebih pas (35 ml per kg); yang ini dipakai di tempat
/// yang tidak punya profil tubuh untuk disandarkan.
const int kTargetAirMl = 2000;

DateTime _dayKey(DateTime date) => DateTime(date.year, date.month, date.day);

/// Total asupan satu hari, sudah dikelompokkan per waktu makan.
class DailyNutrition {
  DailyNutrition({
    required this.date,
    required this.foods,
    required this.waterMl,
  });

  final DateTime date;
  final List<FoodLog> foods;
  final int waterMl;

  double get calories => foods.fold(0, (sum, f) => sum + f.calories);
  double get proteinG => foods.fold(0, (sum, f) => sum + f.proteinG);
  double get carbsG => foods.fold(0, (sum, f) => sum + f.carbsG);
  double get fatG => foods.fold(0, (sum, f) => sum + f.fatG);

  /// Nutrisi opsional: null kalau tidak satu pun catatan hari itu mengisinya,
  /// supaya tidak menampilkan "0 g serat" padahal sebenarnya tidak diketahui.
  double? get fiberG => _optionalSum((f) => f.fiberG);
  double? get sugarG => _optionalSum((f) => f.sugarG);
  double? get sodiumMg => _optionalSum((f) => f.sodiumMg);

  double? _optionalSum(double? Function(FoodLog) pick) {
    var ada = false;
    var total = 0.0;
    for (final food in foods) {
      final value = pick(food);
      if (value != null) {
        ada = true;
        total += value;
      }
    }
    return ada ? total : null;
  }

  bool get kosong => foods.isEmpty && waterMl == 0;

  List<FoodLog> forMeal(Meal meal) {
    final list = foods.where((f) => f.meal == meal).toList()
      ..sort((a, b) => a.loggedAt.compareTo(b.loggedAt));
    return list;
  }

  double caloriesForMeal(Meal meal) =>
      forMeal(meal).fold(0, (sum, f) => sum + f.calories);
}

/// Ambil asupan pada [date] dari seluruh riwayat.
DailyNutrition nutritionForDay({
  required DateTime date,
  required List<FoodLog> foods,
  required List<WaterLog> waters,
}) {
  final key = _dayKey(date);
  return DailyNutrition(
    date: key,
    foods: foods.where((f) => _dayKey(f.loggedOn) == key).toList(),
    waterMl: waters
        .where((w) => _dayKey(w.loggedOn) == key)
        .fold(0, (sum, w) => sum + w.ml),
  );
}

/// Makanan yang sering dicatat, dipakai sebagai tombol isi cepat supaya tidak
/// perlu mengetik ulang angka yang sama tiap hari.
class FrequentFood {
  const FrequentFood({
    required this.name,
    required this.timesLogged,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    this.servingGrams,
    this.fiberG,
    this.sugarG,
    this.sodiumMg,
  });

  final String name;
  final int timesLogged;
  final double calories;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final double? servingGrams;
  final double? fiberG;
  final double? sugarG;
  final double? sodiumMg;
}

/// Urutkan makanan menurut seberapa sering dicatat.
///
/// Angka gizinya diambil dari catatan **terbaru** untuk nama itu, bukan
/// rata-rata, supaya kalau user mengoreksi kalorinya, koreksi itu yang dipakai
/// lain kali.
List<FrequentFood> frequentFoods(List<FoodLog> foods, {int limit = 8}) {
  final counts = <String, int>{};
  final latest = <String, FoodLog>{};

  for (final food in foods) {
    final key = food.name.trim().toLowerCase();
    if (key.isEmpty) continue;
    counts[key] = (counts[key] ?? 0) + 1;

    final sebelumnya = latest[key];
    if (sebelumnya == null || food.loggedAt.isAfter(sebelumnya.loggedAt)) {
      latest[key] = food;
    }
  }

  final hasil = counts.entries.map((entry) {
    final food = latest[entry.key]!;
    return FrequentFood(
      name: food.name.trim(),
      timesLogged: entry.value,
      calories: food.calories,
      proteinG: food.proteinG,
      carbsG: food.carbsG,
      fatG: food.fatG,
      servingGrams: food.servingGrams,
      fiberG: food.fiberG,
      sugarG: food.sugarG,
      sodiumMg: food.sodiumMg,
    );
  }).toList();

  hasil.sort((a, b) {
    final byCount = b.timesLogged.compareTo(a.timesLogged);
    // Nama diurutkan alfabetis saat jumlahnya sama supaya urutannya stabil.
    return byCount != 0 ? byCount : a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });

  return hasil.take(limit).toList();
}
