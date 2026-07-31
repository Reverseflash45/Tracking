enum Gender {
  pria('pria', 'Pria'),
  wanita('wanita', 'Wanita');

  const Gender(this.dbValue, this.label);

  final String dbValue;
  final String label;

  static Gender fromDb(String? value) =>
      Gender.values.firstWhere((g) => g.dbValue == value, orElse: () => Gender.pria);
}

/// Faktor pengali TDEE. Angkanya adalah faktor aktivitas Harris-Benedict yang
/// lazim dipakai bersama Mifflin-St Jeor.
enum ActivityLevel {
  sedentari('sedentari', 'Sedentari', 'Kerja duduk, hampir tidak olahraga', 1.2),
  ringan('ringan', 'Ringan', 'Olahraga ringan 1-3 hari/minggu', 1.375),
  sedang('sedang', 'Sedang', 'Olahraga sedang 3-5 hari/minggu', 1.55),
  berat('berat', 'Berat', 'Olahraga berat 6-7 hari/minggu', 1.725),
  sangatBerat('sangat_berat', 'Sangat Berat', 'Pekerjaan fisik atau latihan 2x sehari', 1.9);

  const ActivityLevel(this.dbValue, this.label, this.description, this.factor);

  final String dbValue;
  final String label;
  final String description;
  final double factor;

  static ActivityLevel fromDb(String? value) => ActivityLevel.values
      .firstWhere((a) => a.dbValue == value, orElse: () => ActivityLevel.ringan);
}

enum FitnessGoal {
  cutting('cutting', 'Cutting', 'Turunkan lemak, pertahankan otot'),
  maintenance('maintenance', 'Maintenance', 'Jaga berat badan sekarang'),
  bulking('bulking', 'Bulking', 'Naikkan massa otot'),
  recomposition('recomposition', 'Recomposition', 'Turun lemak sambil naik otot');

  const FitnessGoal(this.dbValue, this.label, this.description);

  final String dbValue;
  final String label;
  final String description;

  static FitnessGoal fromDb(String? value) => FitnessGoal.values
      .firstWhere((g) => g.dbValue == value, orElse: () => FitnessGoal.maintenance);
}

class BodyProfile {
  const BodyProfile({
    required this.heightCm,
    required this.birthDate,
    required this.gender,
    required this.activityLevel,
    required this.goal,
    this.bodyFatPercentage,
    this.targetWeightKg,
    this.targetDate,
  });

  final double heightCm;
  final DateTime birthDate;
  final Gender gender;
  final ActivityLevel activityLevel;
  final FitnessGoal goal;
  final double? bodyFatPercentage;
  final double? targetWeightKg;
  final DateTime? targetDate;

  /// Umur dihitung, bukan disimpan, supaya tidak basi.
  int ageAt(DateTime moment) {
    var age = moment.year - birthDate.year;
    final belumUlangTahun = moment.month < birthDate.month ||
        (moment.month == birthDate.month && moment.day < birthDate.day);
    if (belumUlangTahun) age--;
    return age;
  }

  factory BodyProfile.fromMap(Map<String, dynamic> map) => BodyProfile(
        heightCm: (map['height_cm'] as num).toDouble(),
        birthDate: DateTime.parse(map['birth_date'] as String),
        gender: Gender.fromDb(map['gender'] as String?),
        activityLevel: ActivityLevel.fromDb(map['activity_level'] as String?),
        goal: FitnessGoal.fromDb(map['goal'] as String?),
        bodyFatPercentage: (map['body_fat_percentage'] as num?)?.toDouble(),
        targetWeightKg: (map['target_weight_kg'] as num?)?.toDouble(),
        targetDate: map['target_date'] == null
            ? null
            : DateTime.parse(map['target_date'] as String),
      );

  Map<String, dynamic> toUpsertMap(String userId) => {
        'user_id': userId,
        'height_cm': heightCm,
        'birth_date': birthDate.toIso8601String().substring(0, 10),
        'gender': gender.dbValue,
        'activity_level': activityLevel.dbValue,
        'goal': goal.dbValue,
        'body_fat_percentage': bodyFatPercentage,
        'target_weight_kg': targetWeightKg,
        'target_date': targetDate?.toIso8601String().substring(0, 10),
        'updated_at': DateTime.now().toIso8601String(),
      };
}

class WeightLog {
  const WeightLog({required this.loggedOn, required this.weightKg});

  final DateTime loggedOn;
  final double weightKg;

  factory WeightLog.fromMap(Map<String, dynamic> map) => WeightLog(
        loggedOn: DateTime.parse(map['logged_on'] as String),
        weightKg: (map['weight_kg'] as num).toDouble(),
      );
}
