import 'package:flutter_test/flutter_test.dart';
import 'package:tracking/features/academic/data/models/class_schedule.dart';
import 'package:tracking/features/academic/domain/schedule_conflict.dart';

final _now = DateTime(2026, 8, 5); // Rabu

ClassSchedule _jadwal(
  String id, {
  required int hari,
  required String mulai,
  required String selesai,
  String nama = 'Matkul',
  String courseId = 'c1',
  DateTime? phl,
}) =>
    ClassSchedule(
      id: id,
      userId: 'u',
      courseId: courseId,
      courseName: nama,
      dayOfWeek: hari,
      startTime: mulai,
      endTime: selesai,
      isPhl: phl != null,
      specificDate: phl,
    );

JadwalSlot _slot(int hari, String mulai, String selesai, {DateTime? phl}) => JadwalSlot(
      dayOfWeek: hari,
      mulai: menitDariJam(mulai)!,
      selesai: menitDariJam(selesai)!,
      tanggal: phl,
    );

void main() {
  group('menitDariJam', () {
    test('membaca format kolom time Postgres', () {
      expect(menitDariJam('08:30:00'), 8 * 60 + 30);
    });

    test('tengah malam bukan kegagalan', () {
      expect(menitDariJam('00:00:00'), 0);
    });

    test('format rusak jadi null, bukan nol', () {
      expect(menitDariJam('pagi'), isNull);
      expect(menitDariJam('25:00:00'), isNull);
      expect(menitDariJam('08'), isNull);
    });
  });

  group('menitBeririsan', () {
    test('hari berbeda tidak pernah bentrok', () {
      expect(menitBeririsan(_slot(1, '08:00:00', '10:00:00'), _slot(2, '08:00:00', '10:00:00')), 0);
    });

    test('bersentuhan bukan bentrok', () {
      // 10:00 selesai, 10:00 mulai — berurutan, bukan tabrakan.
      expect(menitBeririsan(_slot(1, '08:00:00', '10:00:00'), _slot(1, '10:00:00', '12:00:00')), 0);
    });

    test('irisan sebagian dihitung menitnya', () {
      expect(menitBeririsan(_slot(1, '08:00:00', '10:00:00'), _slot(1, '09:30:00', '11:00:00')), 30);
    });

    test('satu jadwal menelan jadwal lain', () {
      expect(menitBeririsan(_slot(1, '08:00:00', '12:00:00'), _slot(1, '09:00:00', '10:00:00')), 60);
    });
  });

  group('PHL', () {
    test('PHL bentrok dengan kelas rutin di hari yang sama', () {
      // Kelas pengganti tidak membatalkan kelas reguler lain hari itu.
      final phl = _slot(3, '08:00:00', '10:00:00', phl: DateTime(2026, 8, 5));
      final rutin = _slot(3, '09:00:00', '11:00:00');
      expect(menitBeririsan(phl, rutin), 60);
    });

    test('dua PHL di tanggal berbeda tidak bentrok meski hari sama', () {
      final a = _slot(3, '08:00:00', '10:00:00', phl: DateTime(2026, 8, 5));
      final b = _slot(3, '08:00:00', '10:00:00', phl: DateTime(2026, 8, 12));
      expect(menitBeririsan(a, b), 0);
    });

    test('dua PHL di tanggal sama bentrok', () {
      final a = _slot(3, '08:00:00', '10:00:00', phl: DateTime(2026, 8, 5));
      final b = _slot(3, '09:00:00', '11:00:00', phl: DateTime(2026, 8, 5));
      expect(menitBeririsan(a, b), 60);
    });

    test('PHL yang tanggalnya sudah lewat tidak dilaporkan', () {
      final map = conflictMap(
        [
          _jadwal('a', hari: 3, mulai: '08:00:00', selesai: '10:00:00'),
          _jadwal('b', hari: 3, mulai: '08:00:00', selesai: '10:00:00',
              phl: DateTime(2026, 7, 1)),
        ],
        now: _now,
      );
      expect(map, isEmpty);
    });
  });

  group('conflictsForSlot', () {
    final tersimpan = [
      _jadwal('a', hari: 1, mulai: '08:00:00', selesai: '10:00:00', nama: 'Basis Data'),
      _jadwal('b', hari: 1, mulai: '13:00:00', selesai: '15:00:00', nama: 'Kalkulus'),
      _jadwal('c', hari: 2, mulai: '08:00:00', selesai: '10:00:00', nama: 'Statistika'),
    ];

    test('slot bebas tidak melaporkan apa-apa', () {
      final hasil = conflictsForSlot(_slot(1, '10:00:00', '12:00:00'), tersimpan, now: _now);
      expect(hasil, isEmpty);
    });

    test('slot yang menimpa menyebut lawannya', () {
      final hasil = conflictsForSlot(_slot(1, '09:00:00', '14:00:00'), tersimpan, now: _now);
      expect(hasil.map((c) => c.lawan.courseName), ['Basis Data', 'Kalkulus']);
    });

    test('diurutkan dari irisan terlama', () {
      final hasil = conflictsForSlot(_slot(1, '09:00:00', '13:30:00'), tersimpan, now: _now);
      // Basis Data 60 menit, Kalkulus 30 menit.
      expect(hasil.first.lawan.courseName, 'Basis Data');
      expect(hasil.first.menit, 60);
      expect(hasil.last.menit, 30);
    });

    test('durasiLabel membaca wajar', () {
      final hasil = conflictsForSlot(_slot(1, '08:00:00', '09:30:00'), tersimpan, now: _now);
      expect(hasil.first.durasiLabel, '1 jam 30 menit');
    });
  });

  group('conflictMap', () {
    test('daftar aman menghasilkan peta kosong', () {
      final map = conflictMap(
        [
          _jadwal('a', hari: 1, mulai: '08:00:00', selesai: '10:00:00'),
          _jadwal('b', hari: 1, mulai: '10:00:00', selesai: '12:00:00'),
        ],
        now: _now,
      );
      expect(map, isEmpty);
    });

    test('kedua sisi pasangan sama-sama ditandai', () {
      final map = conflictMap(
        [
          _jadwal('a', hari: 1, mulai: '08:00:00', selesai: '10:00:00', nama: 'A'),
          _jadwal('b', hari: 1, mulai: '09:00:00', selesai: '11:00:00', nama: 'B'),
        ],
        now: _now,
      );

      expect(map.keys, containsAll(['a', 'b']));
      expect(map['a']!.single.lawan.courseName, 'B');
      expect(map['b']!.single.lawan.courseName, 'A');
    });

    test('dua kelas yang menimpa dihitung satu masalah', () {
      final map = conflictMap(
        [
          _jadwal('a', hari: 1, mulai: '08:00:00', selesai: '10:00:00'),
          _jadwal('b', hari: 1, mulai: '09:00:00', selesai: '11:00:00'),
        ],
        now: _now,
      );
      expect(totalPasanganBentrok(map), 1);
    });

    test('import KRS dobel: tiga salinan identik jadi tiga pasangan', () {
      final map = conflictMap(
        [
          for (var i = 0; i < 3; i++)
            _jadwal('s$i', hari: 1, mulai: '08:00:00', selesai: '10:00:00'),
        ],
        now: _now,
      );
      expect(map, hasLength(3));
      expect(totalPasanganBentrok(map), 3);
    });

    test('jam yang tidak terbaca dilewati, bukan bikin crash', () {
      final map = conflictMap(
        [
          _jadwal('a', hari: 1, mulai: 'rusak', selesai: '10:00:00'),
          _jadwal('b', hari: 1, mulai: '08:00:00', selesai: '10:00:00'),
        ],
        now: _now,
      );
      expect(map, isEmpty);
    });
  });
}
