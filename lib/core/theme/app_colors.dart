import 'package:flutter/material.dart';

/// Warna per kategori konten, dipakai konsisten di seluruh app: hero header,
/// section header, ikon list, dan indikator tab bawah.
///
/// Sembilan warna ini dulu diambil langsung dari palet baku Material, satu
/// keluarga per kategori. Masalahnya bukan jumlahnya, tapi bahwa kesembilannya
/// tidak pernah dipilih bersama-sama:
///
/// - Terangnya berjauhan. Dokumen (cokelat) dan Keuangan (hijau tua) jatuh
///   jauh lebih gelap daripada Deadline (deep orange). Yang gelap terlihat
///   berlumpur, yang terang berteriak, dan keduanya ada di layar yang sama.
/// - Dua yang paling sering bersebelahan justru paling mirip. Beranda #3B6FE5
///   dan Jadwal #4F46E5 cuma beda belasan derajat rona — di layar keduanya
///   "biru", jadi warnanya tidak membedakan apa pun.
/// - Semuanya berkroma penuh. Kalau semua warna berteriak sekencang-kencangnya,
///   tidak ada yang terdengar.
///
/// Yang sekarang dipilih sebagai satu set, dan dua syaratnya diuji di
/// `test/tampilan_test.dart` — bukan dinilai dengan mata:
///
/// 1. Tiap warna harus mencapai rasio kontras 3:1 di atas kartu, di tema
///    terang maupun gelap. Itu ambang WCAG untuk grafis dan teks besar, dan
///    ini satu-satunya cara satu nilai warna boleh dipakai di kedua tema.
/// 2. Lima warna tab harus berjarak minimal 40 derajat rona satu sama lain.
///
/// Syarat kedua itu yang paling sering dilanggar tanpa sadar. Versi pertama
/// palet ini pun gagal: Beranda vs Jadwal cuma 26 derajat, dan Workout vs
/// Keuangan juga 26. Keduanya baru ketahuan setelah diuji.
///
/// Tiga kategori sekunder sengaja dibiarkan lebih redup daripada lima warna
/// tab. Aturan 60-30-10 menaruh warna aksen di 10% permukaan; kalau tiap
/// kategori berhak atas warna sekencang tab utama, angkanya jauh di atas itu.
class AppColors {
  AppColors._();

  // --- Lima warna tab utama. Rona: 227, 268, 9, 174, 128. ---

  /// Biru, 227°. Beranda.
  static const Color dashboard = Color(0xFF4667D9);

  /// Ungu, 268°. Jadwal kuliah. Sengaja dijauhkan dari biru Beranda — dulu
  /// keduanya sama-sama terbaca "biru" padahal dua tab bersebelahan.
  static const Color academic = Color(0xFF9448E8);

  /// Koral, 9°. Tugas dan deadline. Satu-satunya rona hangat di antara lima
  /// tab, karena ini satu-satunya yang punya unsur mendesak.
  static const Color deadline = Color(0xFFE2553D);

  /// Teal, 174°. Workout.
  static const Color workout = Color(0xFF10A092);

  /// Hijau, 128°. Keuangan. Dulu #2E7D32 yang gelap dan pekat sampai terlihat
  /// berlumpur di sebelah warna lain; sekarang lebih terang dan sedikit
  /// digeser menjauh dari teal Workout.
  static const Color finance = Color(0xFF3D9E4A);

  // --- Kategori sekunder. Rona tetap berjarak, kroma diturunkan. ---

  /// Plum, 292°. Profil.
  static const Color profile = Color(0xFFA950B8);

  /// Rose, 340°. Watchlist.
  static const Color watchlist = Color(0xFFD44B79);

  /// Biru abu, 209°, kroma rendah. Kendaraan.
  static const Color vehicle = Color(0xFF5E7F9E);

  /// Olive, 72°, kroma rendah. Catatan. Rona ini satu-satunya yang belum
  /// dipakai di celah lebar antara amber Dokumen (32°) dan hijau Keuangan
  /// (128°), jadi dia tidak perlu berdesakan dengan yang sudah ada.
  static const Color note = Color(0xFF74862F);

  /// Amber tua, 32°, kroma rendah. Dokumen. Dulu cokelat #6D4C41 yang di layar
  /// kecil tidak terbaca sebagai warna, cuma sebagai abu-abu kotor.
  static const Color document = Color(0xFFB07C42);

  // --- Warna status. Ini yang paling perlu langsung terbaca, jadi ronanya
  // dipilih dari yang paling konvensional: merah bahaya, kuning tunggu, hijau
  // aman. ---

  static const Color priorityHigh = Color(0xFFDB4444);

  /// Amber gelap, bukan oranye terang. Versi pertama (#DB8A2E) cuma mencapai
  /// 2.59:1 di atas kartu tema terang — di bawah ambang, dan ketahuan lewat
  /// uji kontras, bukan lewat melihat.
  static const Color priorityMedium = Color(0xFFB8721A);

  static const Color priorityLow = Color(0xFF3D9E63);

  static const Color statusInProgress = Color(0xFF3E7BD9);
  static const Color statusDone = Color(0xFF3D9E63);
}
