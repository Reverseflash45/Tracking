import 'package:flutter_test/flutter_test.dart';
import 'package:tracking/core/theme/warna_matkul.dart';

void main() {
  test('delapan mata kuliah pertama mendapat delapan warna berbeda', () {
    final id = [for (var i = 0; i < 8; i++) 'matkul-$i'];
    bagikanWarnaMatkul(id);
    expect({for (final x in id) warnaMatkul(x)}.length, 8);
  });

  test('warna tidak berpindah saat daftar lain dimuat belakangan', () {
    bagikanWarnaMatkul(['a', 'b', 'c']);
    final sebelum = warnaMatkul('b');
    // Daftar jadwal hanya memuat sebagian mata kuliah.
    bagikanWarnaMatkul(['b']);
    expect(warnaMatkul('b'), sebelum);
  });

  test('tanpa id memakai abu-abu netral', () {
    expect(warnaMatkul(null), warnaMatkul(''));
  });
}
