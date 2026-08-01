import 'package:flutter_test/flutter_test.dart';
import 'package:tracking/features/workout/domain/workout_streak.dart';

final _hariIni = DateTime(2026, 8, 1);

DateTime _lalu(int hari) => _hariIni.subtract(Duration(days: hari));

WorkoutStreak _hitung({
  List<DateTime> latihan = const [],
  List<DateTime> istirahat = const [],
}) =>
    calculateStreakFromDates(latihan, restDates: istirahat, now: _hariIni);

void main() {
  group('streak tanpa hari istirahat', () {
    test('tidak ada catatan berarti nol', () {
      final hasil = _hitung();
      expect(hasil.current, 0);
      expect(hasil.best, 0);
    });

    test('latihan hari ini saja', () {
      final hasil = _hitung(latihan: [_lalu(0)]);
      expect(hasil.current, 1);
      expect(hasil.best, 1);
    });

    test('tiga hari berturut-turut', () {
      final hasil = _hitung(latihan: [_lalu(0), _lalu(1), _lalu(2)]);
      expect(hasil.current, 3);
      expect(hasil.best, 3);
    });

    test('belum sempat hari ini tapi kemarin jalan — streak tetap hidup', () {
      final hasil = _hitung(latihan: [_lalu(1), _lalu(2)]);
      expect(hasil.current, 2);
    });

    test('bolong dua hari mematikan streak, tapi rekornya tersimpan', () {
      final hasil = _hitung(latihan: [_lalu(2), _lalu(3), _lalu(4), _lalu(5)]);
      expect(hasil.current, 0);
      expect(hasil.best, 4);
    });

    test('dua sesi di hari yang sama dihitung sekali', () {
      final hasil = _hitung(latihan: [
        DateTime(2026, 8, 1, 7),
        DateTime(2026, 8, 1, 19),
      ]);
      expect(hasil.current, 1);
    });
  });

  group('hari istirahat menyambung streak', () {
    test('istirahat hari ini setelah latihan kemarin', () {
      final hasil = _hitung(latihan: [_lalu(1), _lalu(2)], istirahat: [_lalu(0)]);
      expect(hasil.current, 3);
      expect(hasil.restInCurrent, 1);
      expect(hasil.activeInCurrent, 2);
    });

    test('istirahat di tengah dua hari latihan', () {
      final hasil = _hitung(
        latihan: [_lalu(0), _lalu(2), _lalu(3)],
        istirahat: [_lalu(1)],
      );
      expect(hasil.current, 4);
      expect(hasil.restInCurrent, 1);
    });

    test('dua hari istirahat berturut-turut masih menyambung', () {
      final hasil = _hitung(
        latihan: [_lalu(0), _lalu(3)],
        istirahat: [_lalu(1), _lalu(2)],
      );
      expect(hasil.current, 4);
      expect(hasil.restInCurrent, 2);
    });

    test('tiga hari istirahat berturut-turut memutus rantai', () {
      // Batasnya ada supaya streak tidak bisa dipelihara tanpa bergerak.
      final hasil = _hitung(
        latihan: [_lalu(0), _lalu(4)],
        istirahat: [_lalu(1), _lalu(2), _lalu(3)],
      );
      expect(hasil.current, 1);
      expect(hasil.restInCurrent, 0);
    });

    test('istirahat terus-menerus tidak menghasilkan streak', () {
      final hasil = _hitung(
        latihan: [_lalu(20)],
        istirahat: [for (var i = 0; i < 10; i++) _lalu(i)],
      );
      expect(hasil.current, 0);
    });

    test('istirahat saja tanpa satu pun latihan tetap nol', () {
      final hasil = _hitung(istirahat: [_lalu(0), _lalu(1)]);
      expect(hasil.current, 0);
      expect(hasil.best, 0);
    });

    test('istirahat di pangkal rantai tidak ikut dihitung', () {
      // Latihan hari ini, sebelumnya dua hari istirahat yang tidak menempel
      // pada latihan apa pun. Streak dimulai dari hari latihan.
      final hasil = _hitung(latihan: [_lalu(0)], istirahat: [_lalu(1), _lalu(2)]);
      expect(hasil.current, 1);
      expect(hasil.restInCurrent, 0);
    });

    test('hari yang ada latihannya bukan hari istirahat meski ditandai', () {
      final hasil = _hitung(latihan: [_lalu(0)], istirahat: [_lalu(0)]);
      expect(hasil.current, 1);
      expect(hasil.restInCurrent, 0);
    });

    test('streak yang sudah mati tidak bisa dihidupkan dengan istirahat', () {
      final hasil = _hitung(latihan: [_lalu(5)], istirahat: [_lalu(0)]);
      expect(hasil.current, 0);
    });

    test('rekor terpanjang ikut menghitung hari istirahat', () {
      final hasil = _hitung(
        latihan: [_lalu(10), _lalu(11), _lalu(14), _lalu(15)],
        istirahat: [_lalu(12), _lalu(13)],
      );
      // 15,14 latihan · 13,12 istirahat · 11,10 latihan = rantai 6 hari.
      expect(hasil.best, 6);
      expect(hasil.current, 0);
    });

    test('rekor tidak menyambung lewat batas istirahat', () {
      final hasil = _hitung(
        latihan: [_lalu(10), _lalu(14)],
        istirahat: [_lalu(11), _lalu(12), _lalu(13)],
      );
      // Istirahat ketiga memutus, jadi rantai terpanjangnya 14 + dua istirahat.
      expect(hasil.best, 3);
    });
  });

  group('consecutiveRestDays', () {
    test('nol kalau hari ini bukan hari istirahat', () {
      expect(
        consecutiveRestDays(
          restDates: [_lalu(1)],
          activeDates: [_lalu(2)],
          now: _hariIni,
        ),
        0,
      );
    });

    test('menghitung mundur sampai hari bukan istirahat', () {
      expect(
        consecutiveRestDays(
          restDates: [_lalu(0), _lalu(1), _lalu(3)],
          activeDates: [_lalu(2)],
          now: _hariIni,
        ),
        2,
      );
    });

    test('hari yang ada latihannya memutus hitungan', () {
      expect(
        consecutiveRestDays(
          restDates: [_lalu(0), _lalu(1)],
          activeDates: [_lalu(1)],
          now: _hariIni,
        ),
        1,
      );
    });
  });
}
