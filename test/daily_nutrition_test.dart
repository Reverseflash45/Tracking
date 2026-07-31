import 'package:flutter_test/flutter_test.dart';
import 'package:tracking/features/nutrition/domain/daily_nutrition.dart';
import 'package:tracking/features/nutrition/domain/food_log.dart';

FoodLog _food(
  String name, {
  required DateTime on,
  DateTime? at,
  Meal meal = Meal.camilan,
  double calories = 100,
  double protein = 10,
  double carbs = 20,
  double fat = 5,
  double? fiber,
  double? sugar,
  double? sodium,
  double? serving,
}) {
  return FoodLog(
    id: '$name-${(at ?? on).toIso8601String()}',
    loggedOn: on,
    loggedAt: at ?? on,
    name: name,
    meal: meal,
    calories: calories,
    proteinG: protein,
    carbsG: carbs,
    fatG: fat,
    fiberG: fiber,
    sugarG: sugar,
    sodiumMg: sodium,
    servingGrams: serving,
  );
}

WaterLog _water(DateTime on, int ml) =>
    WaterLog(id: '$on-$ml', loggedOn: on, loggedAt: on, ml: ml);

void main() {
  final hariIni = DateTime(2026, 7, 31);
  final kemarin = DateTime(2026, 7, 30);

  group('Meal.guessFor', () {
    test('menebak waktu makan dari jam', () {
      expect(Meal.guessFor(DateTime(2026, 7, 31, 7)), Meal.sarapan);
      expect(Meal.guessFor(DateTime(2026, 7, 31, 12)), Meal.makanSiang);
      expect(Meal.guessFor(DateTime(2026, 7, 31, 19)), Meal.makanMalam);
      expect(Meal.guessFor(DateTime(2026, 7, 31, 22)), Meal.camilan);
    });
  });

  group('nutritionForDay', () {
    test('menjumlahkan hanya catatan pada tanggal itu', () {
      final result = nutritionForDay(
        date: hariIni,
        foods: [
          _food('Nasi', on: hariIni, calories: 200, protein: 4, carbs: 44, fat: 1),
          _food('Ayam', on: hariIni, calories: 300, protein: 30, carbs: 0, fat: 18),
          _food('Mie', on: kemarin, calories: 500, protein: 10, carbs: 60, fat: 20),
        ],
        waters: [
          _water(hariIni, 250),
          _water(hariIni, 600),
          _water(kemarin, 1000),
        ],
      );

      expect(result.calories, 500);
      expect(result.proteinG, 34);
      expect(result.carbsG, 44);
      expect(result.fatG, 19);
      expect(result.waterMl, 850);
    });

    test('mengabaikan jam saat mencocokkan tanggal', () {
      final result = nutritionForDay(
        date: DateTime(2026, 7, 31, 23, 59),
        foods: [_food('Nasi', on: DateTime(2026, 7, 31, 6), calories: 200)],
        waters: const [],
      );

      expect(result.foods, hasLength(1));
    });

    test('hari tanpa catatan ditandai kosong', () {
      final result = nutritionForDay(date: hariIni, foods: const [], waters: const []);

      expect(result.kosong, isTrue);
      expect(result.calories, 0);
      expect(result.waterMl, 0);
    });

    test('air saja sudah dianggap tidak kosong', () {
      final result = nutritionForDay(
        date: hariIni,
        foods: const [],
        waters: [_water(hariIni, 250)],
      );

      expect(result.kosong, isFalse);
    });
  });

  group('nutrisi opsional', () {
    test('null kalau tidak satu pun catatan mengisinya', () {
      final result = nutritionForDay(
        date: hariIni,
        foods: [_food('Nasi', on: hariIni)],
        waters: const [],
      );

      expect(result.fiberG, isNull);
      expect(result.sugarG, isNull);
      expect(result.sodiumMg, isNull);
    });

    test('menjumlahkan yang terisi saja, tanpa menganggap yang kosong sebagai nol', () {
      final result = nutritionForDay(
        date: hariIni,
        foods: [
          _food('Nasi', on: hariIni, fiber: 2),
          _food('Ayam', on: hariIni), // serat tidak diketahui
          _food('Sayur', on: hariIni, fiber: 5),
        ],
        waters: const [],
      );

      expect(result.fiberG, 7);
    });
  });

  group('pengelompokan waktu makan', () {
    test('memisahkan catatan per waktu makan dan menjumlahkan kalorinya', () {
      final result = nutritionForDay(
        date: hariIni,
        foods: [
          _food('Roti', on: hariIni, meal: Meal.sarapan, calories: 150),
          _food('Nasi', on: hariIni, meal: Meal.makanSiang, calories: 400),
          _food('Ayam', on: hariIni, meal: Meal.makanSiang, calories: 300),
        ],
        waters: const [],
      );

      expect(result.forMeal(Meal.sarapan), hasLength(1));
      expect(result.forMeal(Meal.makanSiang), hasLength(2));
      expect(result.forMeal(Meal.makanMalam), isEmpty);
      expect(result.caloriesForMeal(Meal.makanSiang), 700);
    });

    test('isi satu waktu makan diurutkan menurut jam', () {
      final result = nutritionForDay(
        date: hariIni,
        foods: [
          _food('Kedua', on: hariIni, at: DateTime(2026, 7, 31, 13), meal: Meal.makanSiang),
          _food('Pertama', on: hariIni, at: DateTime(2026, 7, 31, 12), meal: Meal.makanSiang),
        ],
        waters: const [],
      );

      expect(result.forMeal(Meal.makanSiang).first.name, 'Pertama');
    });
  });

  group('frequentFoods', () {
    test('diurutkan dari yang paling sering dicatat', () {
      final foods = [
        _food('Nasi', on: hariIni, at: DateTime(2026, 7, 31, 12)),
        _food('Nasi', on: kemarin, at: DateTime(2026, 7, 30, 12)),
        _food('Nasi', on: kemarin, at: DateTime(2026, 7, 30, 19)),
        _food('Ayam', on: hariIni, at: DateTime(2026, 7, 31, 13)),
      ];

      final result = frequentFoods(foods);

      expect(result.first.name, 'Nasi');
      expect(result.first.timesLogged, 3);
      expect(result.last.name, 'Ayam');
    });

    test('nama digabung tanpa memandang huruf besar/kecil', () {
      final foods = [
        _food('nasi goreng', on: kemarin, at: DateTime(2026, 7, 30)),
        _food('Nasi Goreng', on: hariIni, at: DateTime(2026, 7, 31)),
      ];

      final result = frequentFoods(foods);

      expect(result, hasLength(1));
      expect(result.first.timesLogged, 2);
      // Ejaan dari catatan terbaru yang dipakai.
      expect(result.first.name, 'Nasi Goreng');
    });

    test('angka gizi diambil dari catatan terbaru, bukan rata-rata', () {
      // Supaya koreksi kalori yang terakhir dimasukkan itu yang dipakai lagi.
      final foods = [
        _food('Nasi', on: kemarin, at: DateTime(2026, 7, 30), calories: 200),
        _food('Nasi', on: hariIni, at: DateTime(2026, 7, 31), calories: 350),
      ];

      expect(frequentFoods(foods).first.calories, 350);
    });

    test('menghormati batas jumlah', () {
      final foods = [
        for (var i = 0; i < 12; i++) _food('Makanan $i', on: hariIni),
      ];

      expect(frequentFoods(foods, limit: 5), hasLength(5));
    });

    test('daftar kosong menghasilkan daftar kosong', () {
      expect(frequentFoods(const []), isEmpty);
    });
  });
}
