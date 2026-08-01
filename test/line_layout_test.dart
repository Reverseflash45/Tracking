import 'package:flutter_test/flutter_test.dart';
import 'package:tracking/core/ocr/line_layout.dart';

ScanLine _line(
  String text, {
  required double left,
  required double top,
  double height = 20,
}) =>
    ScanLine(text: text, left: left, top: top, bottom: top + height);

void main() {
  group('groupIntoRows', () {
    test('label kiri dan nominal kanan jadi satu baris', () {
      // Persis bentuk struk aplikasi: dua kolom yang oleh ML Kit dikembalikan
      // sebagai blok terpisah.
      final hasil = groupIntoRows([
        _line('Subtotal', left: 40, top: 100),
        _line('Total Pembayaran', left: 40, top: 140),
        _line('Rp45.000', left: 400, top: 100),
        _line('Rp55.000', left: 400, top: 140),
      ]);

      expect(hasil, ['Subtotal  Rp45.000', 'Total Pembayaran  Rp55.000']);
    });

    test('isi baris diurutkan kiri ke kanan, bukan urutan masuknya', () {
      final hasil = groupIntoRows([
        _line('Rp10.000', left: 400, top: 50),
        _line('Ongkir', left: 40, top: 50),
      ]);

      expect(hasil, ['Ongkir  Rp10.000']);
    });

    test('baris yang jelas terpisah tidak ikut digabung', () {
      final hasil = groupIntoRows([
        _line('Baris satu', left: 40, top: 0),
        _line('Baris dua', left: 40, top: 40),
      ]);

      expect(hasil, ['Baris satu', 'Baris dua']);
    });

    test('foto yang sedikit miring tetap tergabung', () {
      // Beda 8 piksel pada baris setinggi 20 px masih di dalam toleransi 0.6.
      final hasil = groupIntoRows([
        _line('Total', left: 40, top: 100),
        _line('Rp30.000', left: 400, top: 108),
      ]);

      expect(hasil, ['Total  Rp30.000']);
    });

    test('geseran yang melewati toleransi dianggap baris berbeda', () {
      final hasil = groupIntoRows([
        _line('Total', left: 40, top: 100),
        _line('Rp30.000', left: 400, top: 116),
      ]);

      expect(hasil, hasLength(2));
    });

    test('baris pertama jadi patokan, bukan baris terakhir', () {
      // Tanpa patokan tetap, tiga baris yang masing-masing meleset sedikit
      // akan saling menarik sampai satu "baris" membentang jauh.
      final hasil = groupIntoRows([
        _line('A', left: 10, top: 100),
        _line('B', left: 20, top: 110),
        _line('C', left: 30, top: 120),
      ]);

      expect(hasil, ['A  B', 'C']);
    });

    test('daftar kosong menghasilkan daftar kosong', () {
      expect(groupIntoRows(const []), isEmpty);
    });

    test('baris tanpa isi dibuang', () {
      final hasil = groupIntoRows([
        _line('   ', left: 10, top: 0),
        _line('Nasi Goreng', left: 10, top: 40),
      ]);

      expect(hasil, ['Nasi Goreng']);
    });

    test('tinggi nol tidak membuat semua baris terpisah', () {
      final hasil = groupIntoRows([
        ScanLine(text: 'Total', left: 10, top: 100, bottom: 100),
        ScanLine(text: 'Rp5.000', left: 400, top: 100, bottom: 100),
      ]);

      expect(hasil, ['Total  Rp5.000']);
    });
  });
}
