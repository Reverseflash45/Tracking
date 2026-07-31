import 'package:flutter/material.dart';

enum Meal {
  sarapan('sarapan', 'Sarapan', Icons.free_breakfast_outlined),
  makanSiang('makan_siang', 'Makan Siang', Icons.lunch_dining_outlined),
  makanMalam('makan_malam', 'Makan Malam', Icons.dinner_dining_outlined),
  camilan('camilan', 'Camilan', Icons.cookie_outlined);

  const Meal(this.dbValue, this.label, this.icon);

  final String dbValue;
  final String label;
  final IconData icon;

  static Meal fromDb(String? value) =>
      Meal.values.firstWhere((m) => m.dbValue == value, orElse: () => Meal.camilan);

  /// Tebakan waktu makan berdasarkan jam, dipakai sebagai nilai awal form
  /// supaya user jarang perlu mengubahnya.
  static Meal guessFor(DateTime moment) {
    final hour = moment.hour;
    if (hour < 10) return Meal.sarapan;
    if (hour < 15) return Meal.makanSiang;
    if (hour < 21) return Meal.makanMalam;
    return Meal.camilan;
  }
}

class FoodLog {
  const FoodLog({
    required this.id,
    required this.loggedOn,
    required this.loggedAt,
    required this.name,
    required this.meal,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    this.servingGrams,
    this.fiberG,
    this.sugarG,
    this.sodiumMg,
    this.confidencePercent,
  });

  final String id;
  final DateTime loggedOn;
  final DateTime loggedAt;
  final String name;
  final Meal meal;

  final double calories;
  final double proteinG;
  final double carbsG;
  final double fatG;

  final double? servingGrams;
  final double? fiberG;
  final double? sugarG;
  final double? sodiumMg;

  /// Diisi Food Scanner nanti. Null berarti dicatat manual.
  final double? confidencePercent;

  factory FoodLog.fromMap(Map<String, dynamic> map) => FoodLog(
        id: map['id'] as String,
        loggedOn: DateTime.parse(map['logged_on'] as String),
        loggedAt: DateTime.parse(map['logged_at'] as String),
        name: map['name'] as String,
        meal: Meal.fromDb(map['meal'] as String?),
        calories: (map['calories'] as num).toDouble(),
        proteinG: (map['protein_g'] as num?)?.toDouble() ?? 0,
        carbsG: (map['carbs_g'] as num?)?.toDouble() ?? 0,
        fatG: (map['fat_g'] as num?)?.toDouble() ?? 0,
        servingGrams: (map['serving_grams'] as num?)?.toDouble(),
        fiberG: (map['fiber_g'] as num?)?.toDouble(),
        sugarG: (map['sugar_g'] as num?)?.toDouble(),
        sodiumMg: (map['sodium_mg'] as num?)?.toDouble(),
        confidencePercent: (map['confidence_percent'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toInsertMap({required String userId, required DateTime date}) => {
        'user_id': userId,
        'logged_on': date.toIso8601String().substring(0, 10),
        'name': name,
        'meal': meal.dbValue,
        'calories': calories,
        'protein_g': proteinG,
        'carbs_g': carbsG,
        'fat_g': fatG,
        'serving_grams': servingGrams,
        'fiber_g': fiberG,
        'sugar_g': sugarG,
        'sodium_mg': sodiumMg,
        'confidence_percent': confidencePercent,
      };

  /// Field yang boleh diubah saat mengedit catatan. `logged_on` sengaja tidak
  /// ikut: mengoreksi angka kalori tidak boleh memindahkan makanannya ke hari
  /// lain dan mengacaukan rekap harian yang sudah terlanjur dilihat.
  Map<String, dynamic> toUpdateMap() => {
        'name': name,
        'meal': meal.dbValue,
        'calories': calories,
        'protein_g': proteinG,
        'carbs_g': carbsG,
        'fat_g': fatG,
        'serving_grams': servingGrams,
        'fiber_g': fiberG,
        'sugar_g': sugarG,
        'sodium_mg': sodiumMg,
        // Angka yang sudah dikoreksi manual bukan lagi hasil scan.
        'confidence_percent': null,
      };
}

class WaterLog {
  const WaterLog({
    required this.id,
    required this.loggedOn,
    required this.loggedAt,
    required this.ml,
  });

  final String id;
  final DateTime loggedOn;
  final DateTime loggedAt;
  final int ml;

  factory WaterLog.fromMap(Map<String, dynamic> map) => WaterLog(
        id: map['id'] as String,
        loggedOn: DateTime.parse(map['logged_on'] as String),
        loggedAt: DateTime.parse(map['logged_at'] as String),
        ml: map['ml'] as int,
      );
}
