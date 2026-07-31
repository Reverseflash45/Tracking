import 'package:flutter_test/flutter_test.dart';
import 'package:tracking/features/body/domain/body_profile.dart';
import 'package:tracking/features/body/domain/calorie_calculator.dart';

final _now = DateTime(2026, 7, 31);

BodyProfile _profile({
  double heightCm = 175,
  Gender gender = Gender.pria,
  int age = 25,
  double? bodyFat,
  ActivityLevel activity = ActivityLevel.sedentari,
  FitnessGoal goal = FitnessGoal.maintenance,
  double? targetWeightKg,
  DateTime? targetDate,
}) {
  return BodyProfile(
    heightCm: heightCm,
    // Ulang tahun sudah lewat di tahun ini, jadi umurnya pas.
    birthDate: DateTime(_now.year - age, 1, 1),
    gender: gender,
    activityLevel: activity,
    goal: goal,
    bodyFatPercentage: bodyFat,
    targetWeightKg: targetWeightKg,
    targetDate: targetDate,
  );
}

void main() {
  group('ageAt', () {
    test('belum ulang tahun tahun ini -> umur dikurangi satu', () {
      final profile = BodyProfile(
        heightCm: 175,
        birthDate: DateTime(2000, 12, 25),
        gender: Gender.pria,
        activityLevel: ActivityLevel.ringan,
        goal: FitnessGoal.maintenance,
      );
      expect(profile.ageAt(DateTime(2026, 7, 31)), 25);
      expect(profile.ageAt(DateTime(2026, 12, 25)), 26);
    });
  });

  group('BMI', () {
    test('dihitung dari berat dan tinggi', () {
      final result = calculateCalories(
        profile: _profile(heightCm: 170),
        weightKg: 60,
        now: _now,
      );
      // 60 / 1.7^2 = 20.76
      expect(result.bmi, closeTo(20.76, 0.01));
      expect(result.bmiCategory, BmiCategory.normal);
    });

    test('memakai ambang Asia-Pasifik, bukan ambang internasional', () {
      // BMI 24 masuk "Berlebih" di ambang Asia (>=23), padahal masih normal
      // di ambang WHO internasional (<25).
      final result = calculateCalories(
        profile: _profile(heightCm: 170),
        weightKg: 69.4,
        now: _now,
      );
      expect(result.bmi, closeTo(24.0, 0.1));
      expect(result.bmiCategory, BmiCategory.berlebih);
    });

    test('batas tiap kategori', () {
      expect(BmiCategory.of(17.0), BmiCategory.kurang);
      expect(BmiCategory.of(18.5), BmiCategory.normal);
      expect(BmiCategory.of(22.9), BmiCategory.normal);
      expect(BmiCategory.of(23.0), BmiCategory.berlebih);
      expect(BmiCategory.of(25.0), BmiCategory.obesitas1);
      expect(BmiCategory.of(30.0), BmiCategory.obesitas2);
    });
  });

  group('BMR', () {
    test('Mifflin-St Jeor untuk pria', () {
      final result = calculateCalories(
        profile: _profile(heightCm: 175, gender: Gender.pria, age: 25),
        weightKg: 70,
        now: _now,
      );
      // 10*70 + 6.25*175 - 5*25 + 5 = 700 + 1093.75 - 125 + 5 = 1673.75
      expect(result.bmr, closeTo(1673.75, 0.01));
      expect(result.usedKatchMcArdle, isFalse);
    });

    test('Mifflin-St Jeor untuk wanita berbeda 166 kkal dari pria', () {
      final pria = calculateCalories(
        profile: _profile(gender: Gender.pria),
        weightKg: 70,
        now: _now,
      );
      final wanita = calculateCalories(
        profile: _profile(gender: Gender.wanita),
        weightKg: 70,
        now: _now,
      );
      expect(pria.bmr - wanita.bmr, closeTo(166, 0.01));
    });

    test('Katch-McArdle dipakai kalau persen lemak diisi', () {
      final result = calculateCalories(
        profile: _profile(bodyFat: 20),
        weightKg: 70,
        now: _now,
      );
      // LBM = 70 * 0.8 = 56 -> 370 + 21.6*56 = 1579.6
      expect(result.bmr, closeTo(1579.6, 0.01));
      expect(result.usedKatchMcArdle, isTrue);
    });
  });

  group('TDEE', () {
    test('tiap tingkat aktivitas memakai faktornya sendiri', () {
      for (final level in ActivityLevel.values) {
        final result = calculateCalories(
          profile: _profile(activity: level),
          weightKg: 70,
          now: _now,
        );
        expect(result.tdee, closeTo(result.bmr * level.factor, 0.01));
      }
    });

    test('kalori tiap tujuan diturunkan dari TDEE', () {
      final result = calculateCalories(
        profile: _profile(activity: ActivityLevel.sedang),
        weightKg: 70,
        now: _now,
      );
      expect(result.maintenanceKcal, result.tdee.round());
      expect(result.cuttingKcal, (result.tdee * 0.80).round());
      expect(result.bulkingKcal, (result.tdee * 1.10).round());
      expect(result.cuttingKcal, lessThan(result.maintenanceKcal));
      expect(result.bulkingKcal, greaterThan(result.maintenanceKcal));
    });

    test('goalKcal mengikuti tujuan yang dipilih', () {
      final base = _profile();
      final cutting = calculateCalories(
        profile: base,
        weightKg: 70,
        now: _now,
        goalOverride: FitnessGoal.cutting,
      );
      expect(cutting.goalKcal, cutting.cuttingKcal);
    });
  });

  group('Makro', () {
    test('protein lebih tinggi saat cutting daripada bulking', () {
      final cutting = calculateCalories(
        profile: _profile(),
        weightKg: 70,
        now: _now,
        goalOverride: FitnessGoal.cutting,
      );
      final bulking = calculateCalories(
        profile: _profile(),
        weightKg: 70,
        now: _now,
        goalOverride: FitnessGoal.bulking,
      );
      expect(cutting.macros.proteinG, greaterThan(bulking.macros.proteinG));
      expect(cutting.macros.proteinG, (70 * 2.2).round());
    });

    test('total kalori makro mendekati target kalori', () {
      final result = calculateCalories(
        profile: _profile(activity: ActivityLevel.sedang),
        weightKg: 70,
        now: _now,
      );
      // Selisihnya hanya dari pembulatan gram ke bilangan bulat.
      expect((result.macros.kcal - result.goalKcal).abs(), lessThanOrEqualTo(4));
    });

    test('karbohidrat tidak pernah negatif pada kasus ekstrem', () {
      final result = calculateCalories(
        profile: _profile(activity: ActivityLevel.sedentari),
        weightKg: 200,
        now: _now,
        goalOverride: FitnessGoal.cutting,
      );
      expect(result.macros.carbsG, greaterThanOrEqualTo(0));
    });
  });

  group('Target', () {
    test('null kalau target berat atau tanggal belum diisi', () {
      expect(
        calculateCalories(profile: _profile(), weightKg: 70, now: _now).targetCheck,
        isNull,
      );
      expect(
        calculateCalories(
          profile: _profile(targetWeightKg: 65),
          weightKg: 70,
          now: _now,
        ).targetCheck,
        isNull,
      );
    });

    test('target wajar ditandai realistis', () {
      // Turun 5 kg dalam 10 minggu = 0.5 kg/minggu, di bawah batas 0.7 kg.
      final result = calculateCalories(
        profile: _profile(
          targetWeightKg: 65,
          targetDate: _now.add(const Duration(days: 70)),
        ),
        weightKg: 70,
        now: _now,
      );
      expect(result.targetCheck!.realistis, isTrue);
      expect(result.targetCheck!.warning, isNull);
      expect(result.targetCheck!.weeklyChangeKg, closeTo(-0.5, 0.01));
    });

    test('turun terlalu cepat diperingatkan', () {
      // Turun 10 kg dalam 4 minggu = 2.5 kg/minggu.
      final result = calculateCalories(
        profile: _profile(
          targetWeightKg: 60,
          targetDate: _now.add(const Duration(days: 28)),
        ),
        weightKg: 70,
        now: _now,
      );
      expect(result.targetCheck!.realistis, isFalse);
      expect(result.targetCheck!.warning, contains('turun'));
    });

    test('naik terlalu cepat diperingatkan', () {
      // Naik 5 kg dalam 4 minggu = 1.25 kg/minggu, jauh di atas batas 0.35 kg.
      final result = calculateCalories(
        profile: _profile(
          targetWeightKg: 75,
          targetDate: _now.add(const Duration(days: 28)),
        ),
        weightKg: 70,
        now: _now,
      );
      expect(result.targetCheck!.realistis, isFalse);
      expect(result.targetCheck!.warning, contains('naik'));
    });

    test('tanggal target yang sudah lewat diperingatkan', () {
      final result = calculateCalories(
        profile: _profile(
          targetWeightKg: 65,
          targetDate: _now.subtract(const Duration(days: 1)),
        ),
        weightKg: 70,
        now: _now,
      );
      expect(result.targetCheck!.realistis, isFalse);
      expect(result.targetCheck!.warning, contains('sudah lewat'));
    });
  });

  group('Target harian lain', () {
    test('air 35 ml per kg', () {
      final result = calculateCalories(profile: _profile(), weightKg: 70, now: _now);
      expect(result.waterMl, 2450);
    });

    test('target langkah menyesuaikan tujuan', () {
      int steps(FitnessGoal goal) => calculateCalories(
            profile: _profile(),
            weightKg: 70,
            now: _now,
            goalOverride: goal,
          ).steps;

      expect(steps(FitnessGoal.cutting), greaterThan(steps(FitnessGoal.bulking)));
    });
  });
}
