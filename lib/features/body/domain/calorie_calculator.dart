import 'body_profile.dart';

/// Kategori BMI memakai ambang Asia-Pasifik (WHO/IOTF), bukan ambang WHO umum.
/// Ambang Asia lebih rendah karena pada berat yang sama, populasi Asia
/// cenderung punya persentase lemak tubuh lebih tinggi.
enum BmiCategory {
  kurang('Kurang', 18.5),
  normal('Normal', 23.0),
  berlebih('Berlebih', 25.0),
  obesitas1('Obesitas I', 30.0),
  obesitas2('Obesitas II', double.infinity);

  const BmiCategory(this.label, this.upperBound);

  final String label;

  /// Batas atas eksklusif untuk kategori ini.
  final double upperBound;

  static BmiCategory of(double bmi) =>
      BmiCategory.values.firstWhere((c) => bmi < c.upperBound);
}

/// Batas laju perubahan berat yang masih wajar, dinyatakan sebagai persentase
/// berat badan per minggu. Turun lebih cepat dari ini cenderung ikut membakar
/// otot; naik lebih cepat cenderung jadi lemak.
const double kMaxWeeklyLossPercent = 1.0;
const double kMaxWeeklyGainPercent = 0.5;

class MacroTargets {
  const MacroTargets({
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
  });

  final int proteinG;
  final int carbsG;
  final int fatG;

  int get kcal => proteinG * 4 + carbsG * 4 + fatG * 9;
}

class TargetCheck {
  const TargetCheck({
    required this.weeklyChangeKg,
    required this.realistis,
    this.warning,
  });

  /// Positif = perlu naik, negatif = perlu turun.
  final double weeklyChangeKg;
  final bool realistis;
  final String? warning;
}

class CalorieResult {
  const CalorieResult({
    required this.bmi,
    required this.bmiCategory,
    required this.bmr,
    required this.tdee,
    required this.maintenanceKcal,
    required this.cuttingKcal,
    required this.bulkingKcal,
    required this.recompKcal,
    required this.goalKcal,
    required this.macros,
    required this.waterMl,
    required this.steps,
    required this.sleepHours,
    required this.usedKatchMcArdle,
    this.targetCheck,
  });

  final double bmi;
  final BmiCategory bmiCategory;
  final double bmr;
  final double tdee;

  final int maintenanceKcal;
  final int cuttingKcal;
  final int bulkingKcal;
  final int recompKcal;

  /// Kalori untuk tujuan yang sedang dipilih.
  final int goalKcal;

  final MacroTargets macros;
  final int waterMl;
  final int steps;
  final int sleepHours;

  /// True kalau BMR dihitung dari massa tanpa lemak (persen lemak diisi).
  final bool usedKatchMcArdle;

  final TargetCheck? targetCheck;

  int kcalFor(FitnessGoal goal) => switch (goal) {
        FitnessGoal.cutting => cuttingKcal,
        FitnessGoal.maintenance => maintenanceKcal,
        FitnessGoal.bulking => bulkingKcal,
        FitnessGoal.recomposition => recompKcal,
      };
}

/// Hitung seluruh angka kalori & makro dari profil tubuh.
///
/// [goalOverride] dipakai halaman kalkulator saat user menggeser pemilih tujuan
/// tanpa mengubah profil tersimpan.
CalorieResult calculateCalories({
  required BodyProfile profile,
  required double weightKg,
  required DateTime now,
  FitnessGoal? goalOverride,
}) {
  final goal = goalOverride ?? profile.goal;

  final heightM = profile.heightCm / 100;
  final bmi = weightKg / (heightM * heightM);

  final bodyFat = profile.bodyFatPercentage;
  final usedKatch = bodyFat != null;

  // Katch-McArdle lebih akurat kalau persen lemak diketahui karena memakai
  // massa tanpa lemak, bukan tinggi/umur sebagai perkiraan.
  final bmr = usedKatch
      ? 370 + 21.6 * (weightKg * (1 - bodyFat / 100))
      : _mifflinStJeor(
          weightKg: weightKg,
          heightCm: profile.heightCm,
          age: profile.ageAt(now),
          gender: profile.gender,
        );

  final tdee = bmr * profile.activityLevel.factor;

  // Persentase, bukan +/- 500 kkal flat, supaya defisitnya tidak terlalu
  // ekstrem untuk orang bertubuh kecil.
  final maintenance = tdee.round();
  final cutting = (tdee * 0.80).round();
  final bulking = (tdee * 1.10).round();
  final recomp = (tdee * 0.95).round();

  final goalKcal = switch (goal) {
    FitnessGoal.cutting => cutting,
    FitnessGoal.maintenance => maintenance,
    FitnessGoal.bulking => bulking,
    FitnessGoal.recomposition => recomp,
  };

  return CalorieResult(
    bmi: bmi,
    bmiCategory: BmiCategory.of(bmi),
    bmr: bmr,
    tdee: tdee,
    maintenanceKcal: maintenance,
    cuttingKcal: cutting,
    bulkingKcal: bulking,
    recompKcal: recomp,
    goalKcal: goalKcal,
    macros: _macros(goal: goal, weightKg: weightKg, kcal: goalKcal),
    waterMl: (weightKg * 35).round(),
    steps: switch (goal) {
      FitnessGoal.cutting => 10000,
      FitnessGoal.recomposition => 9000,
      FitnessGoal.maintenance => 8000,
      FitnessGoal.bulking => 7000,
    },
    sleepHours: 8,
    usedKatchMcArdle: usedKatch,
    targetCheck: _checkTarget(profile: profile, weightKg: weightKg, now: now),
  );
}

double _mifflinStJeor({
  required double weightKg,
  required double heightCm,
  required int age,
  required Gender gender,
}) {
  final base = 10 * weightKg + 6.25 * heightCm - 5 * age;
  return gender == Gender.pria ? base + 5 : base - 161;
}

MacroTargets _macros({
  required FitnessGoal goal,
  required double weightKg,
  required int kcal,
}) {
  // Protein dinaikkan saat defisit karena itu yang paling menjaga otot.
  final proteinPerKg = switch (goal) {
    FitnessGoal.cutting => 2.2,
    FitnessGoal.recomposition => 2.0,
    FitnessGoal.bulking => 1.8,
    FitnessGoal.maintenance => 1.8,
  };

  final proteinG = (weightKg * proteinPerKg).round();
  final fatG = (weightKg * 0.8).round();

  // Karbohidrat mengisi sisa kalori. Dijaga tidak negatif untuk kasus ekstrem
  // (berat badan besar dengan target kalori sangat rendah).
  final sisaKcal = kcal - proteinG * 4 - fatG * 9;
  final carbsG = sisaKcal > 0 ? (sisaKcal / 4).round() : 0;

  return MacroTargets(proteinG: proteinG, carbsG: carbsG, fatG: fatG);
}

TargetCheck? _checkTarget({
  required BodyProfile profile,
  required double weightKg,
  required DateTime now,
}) {
  final target = profile.targetWeightKg;
  final deadline = profile.targetDate;
  if (target == null || deadline == null) return null;

  final hari = deadline.difference(DateTime(now.year, now.month, now.day)).inDays;
  if (hari <= 0) {
    return const TargetCheck(
      weeklyChangeKg: 0,
      realistis: false,
      warning: 'Tanggal targetnya sudah lewat. Perbarui dulu targetmu.',
    );
  }

  final minggu = hari / 7;
  final selisih = target - weightKg;
  final perMinggu = selisih / minggu;

  final batasTurun = weightKg * kMaxWeeklyLossPercent / 100;
  final batasNaik = weightKg * kMaxWeeklyGainPercent / 100;

  if (perMinggu < -batasTurun) {
    return TargetCheck(
      weeklyChangeKg: perMinggu,
      realistis: false,
      warning: 'Targetmu butuh turun ${perMinggu.abs().toStringAsFixed(2)} kg/minggu. '
          'Batas amannya sekitar ${batasTurun.toStringAsFixed(2)} kg/minggu — '
          'lebih cepat dari itu biasanya ikut membakar otot. Panjangkan targetnya.',
    );
  }

  if (perMinggu > batasNaik) {
    return TargetCheck(
      weeklyChangeKg: perMinggu,
      realistis: false,
      warning: 'Targetmu butuh naik ${perMinggu.toStringAsFixed(2)} kg/minggu. '
          'Batas wajarnya sekitar ${batasNaik.toStringAsFixed(2)} kg/minggu — '
          'lebih cepat dari itu kebanyakan jadi lemak. Panjangkan targetnya.',
    );
  }

  return TargetCheck(weeklyChangeKg: perMinggu, realistis: true);
}
