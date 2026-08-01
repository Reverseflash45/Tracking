import 'package:flutter_test/flutter_test.dart';
import 'package:tracking/features/sleep/data/sleep_repository.dart';
import 'package:tracking/features/sleep/domain/sleep_stats.dart';

final _now = DateTime(2026, 8, 1);

SleepLog _log(int hariLalu, double jam) => SleepLog(
      id: 'l$hariLalu',
      loggedOn: _now.subtract(Duration(days: hariLalu)),
      hours: jam,
    );

void main() {
  group('summarizeSleep', () {
    test('rata-rata dari hari yang tercatat', () {
      final hasil = summarizeSleep(
        [_log(0, 8), _log(1, 6), _log(2, 7)],
        now: _now,
      );
      expect(hasil.rataJam, closeTo(7, 0.001));
      expect(hasil.hariTercatat, 3);
    });

    test('cukup dan kurang dipisah di ambang 7 jam', () {
      final hasil = summarizeSleep(
        [_log(0, 7), _log(1, 6.9), _log(2, 9)],
        now: _now,
      );
      expect(hasil.hariCukup, 2);
      expect(hasil.hariKurang, 1);
    });

    test('hari yang tidak dicatat tidak dianggap kurang tidur', () {
      // Dua hari tercatat cukup dari jendela 14 hari. Persentasenya harus
      // 100%, bukan 2/14 — lupa mencatat bukan kurang tidur.
      final hasil = summarizeSleep([_log(0, 8), _log(1, 8)], now: _now);
      expect(hasil.persenCukup, 100);
      expect(hasil.hariTercatat, 2);
    });

    test('di luar jendela tidak ikut dihitung', () {
      final hasil = summarizeSleep(
        [_log(0, 8), _log(13, 4), _log(14, 4)],
        now: _now,
      );
      // Hari ke-14 sudah lewat batas jendela 14 hari.
      expect(hasil.hariTercatat, 2);
    });

    test('catatan dari masa depan diabaikan', () {
      final hasil = summarizeSleep(
        [SleepLog(id: 'x', loggedOn: _now.add(const Duration(days: 1)), hours: 9)],
        now: _now,
      );
      expect(hasil.kosong, isTrue);
    });

    test('tanpa catatan tidak membagi dengan nol', () {
      final hasil = summarizeSleep(const [], now: _now);
      expect(hasil.kosong, isTrue);
      expect(hasil.rataJam, 0);
      expect(hasil.persenCukup, 0);
    });
  });

  group('formatJamTidur', () {
    test('jam bulat tanpa menit', () {
      expect(formatJamTidur(7), '7j');
    });

    test('setengah jam jadi menit', () {
      expect(formatJamTidur(7.5), '7j 30m');
    });

    test('pembulatan menit tidak menghasilkan 60 menit', () {
      expect(formatJamTidur(6.999), '7j');
    });
  });
}
