import 'package:flutter_test/flutter_test.dart';
import 'package:tracking/features/nutrition/data/food_database.dart';

Map<String, dynamic> _balasan(Map<String, dynamic> nutriments, {
  String? nama = 'Indomie Goreng',
  Map<String, dynamic> extra = const {},
}) =>
    {
      'status': 1,
      'product': {
        'product_name': ?nama,
        'nutriments': nutriments,
        ...extra,
      },
    };

void main() {
  group('parseOpenFoodFacts', () {
    test('produk lengkap terbaca', () {
      final hasil = parseOpenFoodFacts(_balasan(
        {
          'energy-kcal_100g': 450,
          'proteins_100g': 9.5,
          'carbohydrates_100g': 60,
          'fat_100g': 18,
          'fiber_100g': 2,
          'sugars_100g': 5,
        },
        extra: {'brands': 'Indofood, PT Indofood', 'serving_quantity': 85},
      ));

      expect(hasil, isNotNull);
      expect(hasil!.name, 'Indomie Goreng');
      expect(hasil.brand, 'Indofood');
      expect(hasil.servingGrams, 85);
      expect(hasil.per100g.calories, 450);
      expect(hasil.judul, 'Indomie Goreng (Indofood)');
    });

    test('status selain 1 berarti tidak ketemu', () {
      expect(parseOpenFoodFacts({'status': 0}), isNull);
    });

    test('tanpa nama dianggap tidak ketemu', () {
      final hasil = parseOpenFoodFacts(
        _balasan({'energy-kcal_100g': 100}, nama: null),
      );
      expect(hasil, isNull);
    });

    test('tanpa angka kalori dianggap tidak ketemu', () {
      // Form yang terisi nol semua lebih menyesatkan daripada form kosong.
      final hasil = parseOpenFoodFacts(_balasan({'proteins_100g': 5}));
      expect(hasil, isNull);
    });

    test('kilojoule dikonversi ke kkal', () {
      final hasil = parseOpenFoodFacts(_balasan({'energy_100g': 4184}));
      expect(hasil!.per100g.calories, closeTo(1000, 0.5));
    });

    test('kkal menang atas kilojoule kalau keduanya ada', () {
      final hasil = parseOpenFoodFacts(
        _balasan({'energy-kcal_100g': 450, 'energy_100g': 9999}),
      );
      expect(hasil!.per100g.calories, 450);
    });

    test('natrium gram jadi miligram', () {
      final hasil = parseOpenFoodFacts(
        _balasan({'energy-kcal_100g': 100, 'sodium_100g': 1.2}),
      );
      expect(hasil!.per100g.sodiumMg, closeTo(1200, 0.01));
    });

    test('garam dipakai kalau natriumnya tidak ada', () {
      final hasil = parseOpenFoodFacts(
        _balasan({'energy-kcal_100g': 100, 'salt_100g': 2.5}),
      );
      // 2,5 g garam ≈ 1 g natrium.
      expect(hasil!.per100g.sodiumMg, closeTo(1000, 0.01));
    });

    test('gizi yang tidak dilaporkan tetap null, bukan nol', () {
      final hasil = parseOpenFoodFacts(_balasan({'energy-kcal_100g': 100}));
      expect(hasil!.per100g.fiberG, isNull);
      expect(hasil.per100g.sugarG, isNull);
      expect(hasil.per100g.sodiumMg, isNull);
      // Makro utama memang jatuh ke nol — itu yang diisikan ke form dan
      // langsung terlihat salah kalau memang salah.
      expect(hasil.per100g.proteinG, 0);
    });

    test('angka berbentuk teks tetap terbaca', () {
      final hasil = parseOpenFoodFacts(
        _balasan({'energy-kcal_100g': '250', 'proteins_100g': '7.5'}),
      );
      expect(hasil!.per100g.calories, 250);
      expect(hasil.per100g.proteinG, 7.5);
    });

    test('produk tanpa nutriments dianggap tidak ketemu', () {
      final hasil = parseOpenFoodFacts({
        'status': 1,
        'product': {'product_name': 'Sesuatu'},
      });
      expect(hasil, isNull);
    });

    test('nama Indonesia dipakai kalau ada', () {
      final hasil = parseOpenFoodFacts({
        'status': 1,
        'product': {
          'product_name': 'Fried Noodle',
          'product_name_id': 'Mie Goreng',
          'nutriments': {'energy-kcal_100g': 400},
        },
      });
      expect(hasil!.name, 'Mie Goreng');
    });
  });

  group('NutritionPer100g.untukGram', () {
    const gizi = NutritionPer100g(
      calories: 400,
      proteinG: 10,
      carbsG: 50,
      fatG: 16,
      fiberG: 3,
      sodiumMg: 800,
    );

    test('porsi 85 gram diskalakan', () {
      final hasil = gizi.untukGram(85);
      expect(hasil.calories, closeTo(340, 0.001));
      expect(hasil.proteinG, closeTo(8.5, 0.001));
      expect(hasil.sodiumMg, closeTo(680, 0.001));
    });

    test('100 gram tidak berubah', () {
      final hasil = gizi.untukGram(100);
      expect(hasil.calories, 400);
    });

    test('gizi yang null tetap null setelah diskalakan', () {
      final hasil = gizi.untukGram(50);
      expect(hasil.sugarG, isNull);
      expect(hasil.fiberG, closeTo(1.5, 0.001));
    });
  });
}
