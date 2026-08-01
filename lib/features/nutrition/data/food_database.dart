/// Pencari makanan kemasan lewat barcode.
///
/// Memakai Open Food Facts — basis data terbuka, gratis, tanpa API key, dan
/// tidak butuh proxy server. Karena isinya sumbangan orang banyak, produk
/// Indonesia yang jarang bisa saja belum ada. Itu bukan kegagalan yang perlu
/// disembunyikan: kalau tidak ketemu, formnya tetap terbuka untuk diisi
/// tangan.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;

/// Hasil pencarian satu barcode.
class ScannedProduct {
  const ScannedProduct({
    required this.name,
    required this.per100g,
    this.servingGrams,
    this.brand,
  });

  final String name;
  final String? brand;

  /// Gizi per 100 gram, apa adanya dari sumbernya.
  final NutritionPer100g per100g;

  /// Takaran saji kalau tercantum di kemasan.
  final double? servingGrams;

  String get judul =>
      brand == null || brand!.isEmpty ? name : '$name ($brand)';
}

class NutritionPer100g {
  const NutritionPer100g({
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    this.fiberG,
    this.sugarG,
    this.sodiumMg,
  });

  final double calories;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final double? fiberG;
  final double? sugarG;
  final double? sodiumMg;

  /// Hitung ulang untuk porsi [grams].
  NutritionPer100g untukGram(double grams) {
    final f = grams / 100;
    return NutritionPer100g(
      calories: calories * f,
      proteinG: proteinG * f,
      carbsG: carbsG * f,
      fatG: fatG * f,
      fiberG: fiberG == null ? null : fiberG! * f,
      sugarG: sugarG == null ? null : sugarG! * f,
      sodiumMg: sodiumMg == null ? null : sodiumMg! * f,
    );
  }
}

class FoodLookupException implements Exception {
  FoodLookupException(this.message);
  final String message;

  @override
  String toString() => message;
}

double? _num(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

/// Ubah balasan Open Food Facts jadi bentuk yang dipakai app.
///
/// Dipisah dari pemanggilan jaringan supaya bisa diuji tanpa internet.
ScannedProduct? parseOpenFoodFacts(Map<String, dynamic> json) {
  // status 1 = ketemu. Selain itu produknya tidak ada di basis data.
  if (json['status'] != 1) return null;

  final product = json['product'];
  if (product is! Map) return null;

  final nama = (product['product_name_id'] ??
          product['product_name'] ??
          product['generic_name']) as String?;
  if (nama == null || nama.trim().isEmpty) return null;

  final gizi = product['nutriments'];
  if (gizi is! Map) return null;

  // Sebagian entri hanya punya kJ. 1 kkal = 4.184 kJ.
  var kalori = _num(gizi['energy-kcal_100g']);
  kalori ??= () {
    final kj = _num(gizi['energy_100g']) ?? _num(gizi['energy-kj_100g']);
    return kj == null ? null : kj / 4.184;
  }();

  // Tanpa angka kalori, catatan gizinya tidak ada gunanya — lebih baik
  // dianggap tidak ketemu daripada mengisi form dengan nol semua.
  if (kalori == null) return null;

  final natriumG = _num(gizi['sodium_100g']);
  final garamG = _num(gizi['salt_100g']);

  return ScannedProduct(
    name: nama.trim(),
    brand: (product['brands'] as String?)?.split(',').first.trim(),
    servingGrams: _num(product['serving_quantity']),
    per100g: NutritionPer100g(
      calories: kalori,
      proteinG: _num(gizi['proteins_100g']) ?? 0,
      carbsG: _num(gizi['carbohydrates_100g']) ?? 0,
      fatG: _num(gizi['fat_100g']) ?? 0,
      fiberG: _num(gizi['fiber_100g']),
      sugarG: _num(gizi['sugars_100g']),
      // Sumbernya menyimpan natrium dalam gram; sebagian entri hanya punya
      // garam, yang natriumnya kira-kira 40%.
      sodiumMg: natriumG != null
          ? natriumG * 1000
          : (garamG == null ? null : garamG * 0.4 * 1000),
    ),
  );
}

/// Cari produk berdasarkan barcode. Null berarti tidak ada di basis data.
Future<ScannedProduct?> lookupBarcode(
  String barcode, {
  http.Client? client,
}) async {
  final http_ = client ?? http.Client();
  try {
    final uri = Uri.parse(
      'https://world.openfoodfacts.org/api/v2/product/$barcode.json',
    );
    final response = await http_
        .get(uri, headers: {'User-Agent': 'tracking-app/1.0 (Flutter)'})
        .timeout(const Duration(seconds: 12));

    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw FoodLookupException(
        'Server basis data makanan sedang bermasalah (${response.statusCode}).',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) return null;
    return parseOpenFoodFacts(decoded);
  } on FoodLookupException {
    rethrow;
  } catch (e) {
    debugPrint('lookupBarcode gagal: $e');
    throw FoodLookupException(
      'Tidak bisa menghubungi basis data makanan. Cek koneksimu, atau isi '
      'manual saja.',
    );
  } finally {
    if (client == null) http_.close();
  }
}
