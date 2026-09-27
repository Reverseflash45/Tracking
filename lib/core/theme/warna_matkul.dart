import 'package:flutter/material.dart';

/// Warna tetap per mata kuliah, dipakai di Jadwal, Tugas, dan Beranda.
///
/// Delapan rona yang dipilih bersama supaya tidak ada dua yang tertukar di
/// layar yang sama, semuanya cukup gelap untuk teks putih kecil maupun untuk
/// batang tipis di atas kartu terang. Warnanya diturunkan dari id mata kuliah,
/// jadi "Basis Data" selalu hijau di mana pun ia muncul — kamu belajar
/// mengenalinya dari warna sebelum sempat membaca namanya.
const List<Color> paletMatkul = [
  Color(0xFF5B6EE1), // indigo
  Color(0xFFE0655A), // koral
  Color(0xFF1E9E8C), // teal
  Color(0xFFC0679E), // magenta lembut
  Color(0xFFD08A1E), // kunyit
  Color(0xFF3F8FD1), // biru langit
  Color(0xFF7C62D6), // ungu
  Color(0xFF4E9A48), // hijau daun
];

/// Warna yang sudah dibagikan berurutan ke mata kuliah yang dikenal.
final Map<String, Color> _terbagi = {};
final Set<String> _dikenal = {};

/// Membagikan warna palet secara berurutan ke [idMatkul] (diurutkan dulu
/// supaya stabil). Hash saja bisa memberi dua mata kuliah warna yang sama —
/// dengan lima mata kuliah dan delapan warna, peluangnya lebih dari separuh.
/// Dipanggil setiap daftar mata kuliah dimuat.
///
/// Id yang pernah dikenal digabung, bukan diganti: daftar mata kuliah dan
/// daftar jadwal isinya bisa berbeda, dan warna tidak boleh berpindah hanya
/// karena yang satu selesai dimuat lebih dulu.
void bagikanWarnaMatkul(Iterable<String> idMatkul) {
  _dikenal.addAll(idMatkul);
  final urut = _dikenal.toList()..sort();
  _terbagi
    ..clear()
    ..addEntries([
      for (final (i, id) in urut.indexed) MapEntry(id, paletMatkul[i % paletMatkul.length]),
    ]);
}

Color warnaMatkul(String? kunci) {
  if (kunci == null || kunci.isEmpty) return const Color(0xFF7A808A);
  if (_terbagi[kunci] case final warna?) return warna;
  // FNV-1a sederhana: stabil antar-sesi, tidak seperti String.hashCode yang
  // boleh berubah antar-versi Dart.
  var h = 0x811c9dc5;
  for (final unit in kunci.codeUnits) {
    h ^= unit;
    h = (h * 0x01000193) & 0xFFFFFFFF;
  }
  return paletMatkul[h % paletMatkul.length];
}
