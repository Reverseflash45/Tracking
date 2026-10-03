import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb, visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/export_file.dart';
import 'export_repository.dart';

/// Cadangan otomatis mingguan yang disimpan di HP.
///
/// Gunanya untuk skenario terburuk di sisi server: project Supabase gratis
/// dijeda setelah seminggu tidak dipakai dan bisa terhapus kalau dibiarkan,
/// dan paket gratis tidak punya cadangan harian. Salinan di HP tetap ada
/// apa pun yang terjadi di sana, dan bisa dipulihkan ke project baru.
///
/// Yang tidak dilindungi: HP hilang atau app dihapus — folder app ikut hilang.
/// Untuk itu ada tombol simpan ke Drive / folder lain di halaman Cadangan.
const Duration kSelangCadangan = Duration(days: 7);

/// Berapa cadangan otomatis yang disimpan. Yang lebih lama dihapus.
const int kSisakanCadangan = 5;

/// Jeda sebelum mencoba lagi setelah cadangan otomatis gagal (biasanya
/// karena offline), supaya tidak mencoba di tiap kali app dibuka.
const Duration _jedaCobaLagi = Duration(hours: 6);

const _aktifKey = 'cadangan_otomatis';
const _cobaKey = 'cadangan_otomatis_coba';

@visibleForTesting
bool perluCadanganOtomatis({
  required bool aktif,
  required DateTime? terakhir,
  required DateTime? percobaanTerakhir,
  required DateTime sekarang,
}) {
  if (!aktif) return false;
  if (percobaanTerakhir != null) {
    final sejakCoba = sekarang.difference(percobaanTerakhir);
    if (!sejakCoba.isNegative && sejakCoba < _jedaCobaLagi) return false;
  }
  if (terakhir == null) return true;
  final sejak = sekarang.difference(terakhir);
  // Jam yang dimundurkan: anggap perlu, daripada tidak pernah mencadangkan.
  return sejak.isNegative || sejak >= kSelangCadangan;
}

class BerkasCadangan {
  const BerkasCadangan({required this.file, required this.dibuat, required this.ukuran});

  final File file;
  final DateTime dibuat;
  final int ukuran;

  String get nama => file.uri.pathSegments.last;
}

/// Tanggal dari nama berkas "tracking-backup-2026-10-03-0915.json".
@visibleForTesting
DateTime? tanggalDariNama(String nama) {
  final cocok = RegExp(r'tracking-backup-(\d{4})-(\d{2})-(\d{2})-(\d{2})(\d{2})').firstMatch(nama);
  if (cocok == null) return null;
  final angka = [for (var i = 1; i <= 5; i++) int.parse(cocok.group(i)!)];
  return DateTime(angka[0], angka[1], angka[2], angka[3], angka[4]);
}

class CadanganLokal {
  Future<Directory> _folder() async {
    final dasar = await getApplicationDocumentsDirectory();
    final folder = Directory('${dasar.path}/cadangan');
    if (!await folder.exists()) await folder.create(recursive: true);
    return folder;
  }

  /// Cadangan yang tersimpan, terbaru dulu.
  Future<List<BerkasCadangan>> daftar() async {
    if (kIsWeb) return const [];
    final folder = await _folder();
    final hasil = <BerkasCadangan>[];
    await for (final entity in folder.list()) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      final stat = await entity.stat();
      hasil.add(BerkasCadangan(
        file: entity,
        dibuat: tanggalDariNama(entity.uri.pathSegments.last) ?? stat.modified,
        ukuran: stat.size,
      ));
    }
    hasil.sort((a, b) => b.dibuat.compareTo(a.dibuat));
    return hasil;
  }

  Future<BerkasCadangan> simpan(String json, DateTime waktu) async {
    final folder = await _folder();
    final file = File('${folder.path}/${exportFileName(waktu)}');
    await file.writeAsString(json, flush: true);
    await _rapikan();
    return BerkasCadangan(file: file, dibuat: waktu, ukuran: await file.length());
  }

  Future<void> _rapikan() async {
    final semua = await daftar();
    for (final lama in semua.skip(kSisakanCadangan)) {
      try {
        await lama.file.delete();
      } catch (_) {}
    }
  }

  Future<bool> aktif() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_aktifKey) ?? true;
  }

  Future<void> setAktif(bool aktif) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_aktifKey, aktif);
  }

  /// Buat cadangan kalau sudah waktunya. Aman dipanggil tiap kali app dibuka:
  /// biasanya langsung selesai tanpa melakukan apa-apa.
  Future<BerkasCadangan?> jalankanKalauPerlu(ExportRepository repo, {String? email}) async {
    if (kIsWeb) return null;
    final prefs = await SharedPreferences.getInstance();
    final daftarAda = await daftar();
    final coba = prefs.getString(_cobaKey);
    final sekarang = DateTime.now();

    if (!perluCadanganOtomatis(
      aktif: prefs.getBool(_aktifKey) ?? true,
      terakhir: daftarAda.isEmpty ? null : daftarAda.first.dibuat,
      percobaanTerakhir: coba == null ? null : DateTime.tryParse(coba),
      sekarang: sekarang,
    )) {
      return null;
    }

    await prefs.setString(_cobaKey, sekarang.toIso8601String());
    try {
      final hasil = await repo.buildExport(email: email, rapi: false);
      return await simpan(hasil.json, sekarang);
    } catch (e) {
      // Biasanya offline. Dicoba lagi setelah [_jedaCobaLagi].
      debugPrint('Cadangan otomatis gagal: $e');
      return null;
    }
  }
}

final cadanganLokalProvider = Provider<CadanganLokal>((ref) => CadanganLokal());

final daftarCadanganProvider = FutureProvider.autoDispose<List<BerkasCadangan>>((ref) {
  return ref.watch(cadanganLokalProvider).daftar();
});

final cadanganOtomatisAktifProvider = FutureProvider.autoDispose<bool>((ref) {
  return ref.watch(cadanganLokalProvider).aktif();
});
