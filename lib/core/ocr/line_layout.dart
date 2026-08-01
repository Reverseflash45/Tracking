/// Menyusun ulang hasil OCR mengikuti letak tiap baris di gambar.
///
/// ML Kit mengelompokkan teks per blok, bukan per baris yang terlihat mata.
/// Di struk aplikasi (ShopeeFood, GoFood, m-banking) label ada di kolom kiri
/// dan nominalnya di kolom kanan — dua blok yang terpisah jauh. Akibatnya teks
/// mentahnya keluar sebagai "semua label dulu, baru semua nominal", dan
/// "Total Pembayaran" tidak pernah bersebelahan dengan angkanya. Pembaca struk
/// yang mencari angka di baris yang sama jelas tidak akan menemukan apa pun.
///
/// Di sini baris-baris itu dirangkai ulang jadi baris tampilan, memakai kotak
/// posisi yang sudah ikut dikembalikan ML Kit.
library;

import 'dart:math' as math;

/// Satu baris teks beserta letaknya di gambar.
class ScanLine {
  const ScanLine({
    required this.text,
    required this.left,
    required this.top,
    required this.bottom,
  });

  final String text;
  final double left;
  final double top;
  final double bottom;

  double get center => (top + bottom) / 2;
  double get height => bottom - top;
}

/// Seberapa jauh titik tengah dua baris boleh berbeda — relatif terhadap
/// tinggi baris yang lebih pendek — sebelum keduanya dianggap baris berbeda.
///
/// 0.6 dipilih supaya foto yang sedikit miring tetap tergabung, tapi dua baris
/// yang benar-benar bertumpuk tidak ikut tertarik jadi satu.
const double kRowToleranceRatio = 0.6;

/// Gabungkan baris yang sejajar mendatar menjadi satu baris teks.
///
/// Urutan di dalam satu baris mengikuti posisi kiri-ke-kanan, bukan urutan
/// blok dari ML Kit — supaya "Total Pembayaran  Rp55.000" tidak keluar
/// terbalik jadi "Rp55.000  Total Pembayaran".
List<String> groupIntoRows(
  List<ScanLine> lines, {
  double toleranceRatio = kRowToleranceRatio,
}) {
  if (lines.isEmpty) return const [];

  final sorted = [...lines]..sort((a, b) => a.center.compareTo(b.center));

  final rows = <List<ScanLine>>[];
  for (final line in sorted) {
    final row = rows.isEmpty ? null : rows.last;
    if (row != null) {
      // Dibandingkan dengan anggota pertama, bukan yang terakhir, supaya
      // banyak baris yang menyimpang sedikit-sedikit tidak saling menarik
      // sampai satu "baris" membentang jauh melewati batas toleransi.
      final anchor = row.first;
      // Tinggi nol seharusnya mustahil, tapi kalau terjadi jangan sampai
      // toleransinya ikut nol dan tidak ada yang pernah tergabung.
      final reference = math.max(1.0, math.min(anchor.height, line.height));
      if ((line.center - anchor.center).abs() <= toleranceRatio * reference) {
        row.add(line);
        continue;
      }
    }
    rows.add([line]);
  }

  final hasil = <String>[];
  for (final row in rows) {
    row.sort((a, b) => a.left.compareTo(b.left));
    final teks = row
        .map((line) => line.text.trim())
        .where((text) => text.isNotEmpty)
        .join('  ');
    if (teks.isNotEmpty) hasil.add(teks);
  }
  return hasil;
}
