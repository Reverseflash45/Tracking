/// Simpanan lokal untuk data yang terakhir berhasil diambil dari server.
///
/// Tanpa ini seluruh app mati begitu sinyal hilang: setiap halaman menembak
/// Supabase langsung, jadi di ruang kuliah tanpa sinyal jadwal dan tugas pun
/// tidak bisa dibuka.
///
/// Disimpan sebagai berkas JSON, bukan SharedPreferences. SharedPreferences di
/// Android itu satu berkas XML yang dibaca seluruhnya ke memori — menaruh
/// ratusan sesi latihan dan rute lari di sana membebani startup app, termasuk
/// saat datanya tidak sedang dipakai.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

/// Isi cache beserta kapan terakhir diperbarui.
class CachedRows {
  const CachedRows({required this.rows, required this.savedAt});

  final List<Map<String, dynamic>> rows;
  final DateTime savedAt;
}

class LocalCache {
  LocalCache();

  Directory? _dir;
  Future<Directory>? _pending;

  /// Cache dimatikan di web: tidak ada direktori dokumen di sana, dan browser
  /// sudah punya cache-nya sendiri.
  bool get supported => !kIsWeb;

  Future<Directory> _directory() {
    final ready = _dir;
    if (ready != null) return Future.value(ready);
    return _pending ??= () async {
      final base = await getApplicationDocumentsDirectory();
      final dir = Directory('${base.path}/cache_v1');
      if (!await dir.exists()) await dir.create(recursive: true);
      _dir = dir;
      return dir;
    }();
  }

  /// Nama berkas dibuat dari key supaya karakter aneh tidak bocor ke path.
  String _fileName(String key) =>
      '${key.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')}.json';

  Future<CachedRows?> read(String key) async {
    if (!supported) return null;
    try {
      final file = File('${(await _directory()).path}/${_fileName(key)}');
      if (!await file.exists()) return null;

      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) return null;

      final rows = (decoded['rows'] as List?) ?? const [];
      return CachedRows(
        rows: [for (final row in rows) Map<String, dynamic>.from(row as Map)],
        savedAt: DateTime.tryParse(decoded['saved_at'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );
    } catch (e) {
      // Cache rusak bukan alasan untuk menjatuhkan app — anggap saja kosong.
      debugPrint('LocalCache.read($key) gagal: $e');
      return null;
    }
  }

  Future<void> write(String key, List<Map<String, dynamic>> rows) async {
    if (!supported) return;
    try {
      final file = File('${(await _directory()).path}/${_fileName(key)}');
      await file.writeAsString(jsonEncode({
        'saved_at': DateTime.now().toIso8601String(),
        'rows': rows,
      }));
    } catch (e) {
      debugPrint('LocalCache.write($key) gagal: $e');
    }
  }

  /// Dipanggil saat logout: data orang lain tidak boleh tertinggal di HP.
  Future<void> clear() async {
    if (!supported) return;
    try {
      final dir = await _directory();
      if (await dir.exists()) await dir.delete(recursive: true);
      _dir = null;
      _pending = null;
    } catch (e) {
      debugPrint('LocalCache.clear gagal: $e');
    }
  }
}

final localCacheProvider = Provider<LocalCache>((ref) => LocalCache());

/// Ambil dari server, simpan hasilnya, dan jatuh ke cache kalau gagal.
///
/// Kegagalan server sengaja tidak ditelan diam-diam kalau cache-nya juga
/// kosong — lebih baik halaman menampilkan error daripada daftar kosong yang
/// terbaca sebagai "kamu memang belum mencatat apa-apa".
Future<List<T>> fetchWithCache<T>({
  required LocalCache cache,
  required String key,
  required Future<List<Map<String, dynamic>>> Function() remote,
  required T Function(Map<String, dynamic>) parse,
}) async {
  try {
    final rows = await remote();
    await cache.write(key, rows);
    return [for (final row in rows) parse(row)];
  } catch (error) {
    final cached = await cache.read(key);
    if (cached == null) rethrow;

    try {
      return [for (final row in cached.rows) parse(row)];
    } catch (e) {
      // Bentuk data berubah sejak cache ditulis (misal setelah migrasi).
      // Yang dilaporkan tetap kegagalan aslinya, karena itu sebab kita sampai
      // di sini — bukan kesalahan cache-nya.
      debugPrint('Cache $key tidak bisa dibaca lagi: $e');
      throw error;
    }
  }
}
