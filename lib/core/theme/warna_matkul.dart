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

Color warnaMatkul(String? kunci) {
  if (kunci == null || kunci.isEmpty) return const Color(0xFF7A808A);
  // FNV-1a sederhana: stabil antar-sesi, tidak seperti String.hashCode yang
  // boleh berubah antar-versi Dart.
  var h = 0x811c9dc5;
  for (final unit in kunci.codeUnits) {
    h ^= unit;
    h = (h * 0x01000193) & 0xFFFFFFFF;
  }
  return paletMatkul[h % paletMatkul.length];
}
