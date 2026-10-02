import 'package:flutter_test/flutter_test.dart';
import 'package:tracking/features/nutrition/domain/food_log.dart';
import 'package:tracking/features/nutrition/domain/food_photo.dart';

const _nasi = TebakanMakanan(
  nama: 'Nasi putih',
  porsi: '1 centong',
  gram: 150,
  kalori: 195,
  proteinG: 3.6,
  karboG: 42,
  lemakG: 0.4,
  yakin: 85,
);

void main() {
  group('TebakanMakanan', () {
    test('mengubah berat menskalakan semua gizi sebanding', () {
      final dua = _nasi.denganGram(300);
      expect(dua.gram, 300);
      expect(dua.kalori, closeTo(390, 0.001));
      expect(dua.proteinG, closeTo(7.2, 0.001));
      expect(dua.karboG, closeTo(84, 0.001));
      expect(dua.lemakG, closeTo(0.8, 0.001));
      expect(dua.yakin, 85);
    });

    test('berat 0 tidak bisa diskalakan, gizinya dibiarkan', () {
      final nol = _nasi.denganGram(0).denganGram(100);
      expect(nol.gram, 100);
      expect(nol.kalori, 0);
    });

    test('yakin di bawah batas ditandai kasar', () {
      expect(_nasi.kasar, isFalse);
      expect(TebakanMakanan.fromJson({'nama': 'Sambal', 'yakin': 40})!.kasar, isTrue);
    });

    test('jadi FoodLog dengan angka dibulatkan dan keyakinan tercatat', () {
      final waktu = DateTime(2026, 10, 2, 12);
      final log = _nasi.denganGram(155).keFoodLog(Meal.makanSiang, waktu);
      expect(log.name, 'Nasi putih');
      expect(log.meal, Meal.makanSiang);
      expect(log.calories, 202); // 195 * 155/150 = 201.5
      expect(log.carbsG, 43.4);
      expect(log.servingGrams, 155);
      expect(log.confidencePercent, 85);
      expect(log.toInsertMap(userId: 'u', date: waktu)['confidence_percent'], 85);
    });
  });

  group('membaca jawaban server', () {
    test('baris tanpa nama dibuang, angka aneh jadi 0, yakin dibatasi', () {
      final hasil = HasilFotoMakanan.fromJson({
        'items': [
          {'nama': 'Ayam goreng', 'porsi': 'paha', 'gram': 90, 'kalori': 260, 'protein_g': 22,
           'karbo_g': 4, 'lemak_g': 17, 'yakin': 140},
          {'nama': '  ', 'gram': 10},
          {'nama': 'Tempe', 'gram': -5, 'kalori': 'banyak', 'yakin': 70.6},
          'bukan objek',
        ],
        'catatan': ' Minyaknya mungkin lebih banyak. ',
      });
      expect(hasil.items.map((i) => i.nama), ['Ayam goreng', 'Tempe']);
      expect(hasil.items.first.yakin, 100);
      expect(hasil.items.last.gram, 0);
      expect(hasil.items.last.kalori, 0);
      expect(hasil.items.last.yakin, 71);
      expect(hasil.catatan, 'Minyaknya mungkin lebih banyak.');
    });

    test('jawaban tanpa items aman', () {
      final hasil = HasilFotoMakanan.fromJson({'catatan': 'Bukan makanan.'});
      expect(hasil.items, isEmpty);
    });

    test('total menjumlahkan item terpilih', () {
      final total = totalTebakan([_nasi, _nasi.denganGram(75)]);
      expect(total.kalori, closeTo(292.5, 0.001));
      expect(total.karbo, closeTo(63, 0.001));
    });
  });

  group('jenisGambar', () {
    test('dikenali dari isi, bukan nama file', () {
      expect(jenisGambar([0xFF, 0xD8, 0xFF, 0xE0, 0, 0]), 'image/jpeg');
      expect(jenisGambar([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A]), 'image/png');
      expect(
        jenisGambar([0x52, 0x49, 0x46, 0x46, 1, 2, 3, 4, 0x57, 0x45, 0x42, 0x50]),
        'image/webp',
      );
      expect(jenisGambar([0x00, 0x00, 0x00, 0x18, 0x66, 0x74, 0x79, 0x70]), isNull); // HEIC
      expect(jenisGambar([0xFF]), isNull);
    });
  });
}
