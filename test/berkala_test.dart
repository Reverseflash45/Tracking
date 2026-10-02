import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tracking/core/notifications/smart_reminders.dart';
import 'package:tracking/features/routine/data/rutinitas_widget_sync.dart';
import 'package:tracking/features/routine/domain/berkala.dart';
import 'package:tracking/features/routine/domain/routine.dart';

/// Jumat, 2 Oktober 2026, jam 10 pagi.
final _now = DateTime(2026, 10, 2, 10);

const _pengaturan = NotificationSettings(
  aktif: true,
  menitDalamHari: 8 * 60,
  jenisAktif: {ReminderKind.berkala},
);

RutinitasBerkala _absen({
  required DateTime terakhir,
  int jarak = 25,
  String? jam,
  String judul = 'Absen akun',
}) =>
    RutinitasBerkala(
      id: judul,
      userId: 'u',
      title: judul,
      intervalDays: jarak,
      lastDoneOn: terakhir,
      remindAt: jam,
    );

List<PlannedReminder> _rencana(List<RutinitasBerkala> berkala, {NotificationSettings? settings}) =>
    planReminders(
      data: ReminderInput(berkala: berkala),
      settings: settings ?? _pengaturan,
      now: _now,
    );

void main() {
  group('RutinitasBerkala', () {
    test('jatuh tempo = terakhir dilakukan + jarak hari', () {
      final item = _absen(terakhir: DateTime(2026, 9, 20));
      expect(item.jatuhTempo, DateTime(2026, 10, 15));
      expect(item.sisaHari(_now), 13);
      expect(item.perluDikerjakan(_now), isFalse);
    });

    test('hari-H dan telat dihitung per tanggal, bukan per jam', () {
      expect(_absen(terakhir: DateTime(2026, 9, 7)).sisaHari(_now), 0);
      expect(_absen(terakhir: DateTime(2026, 9, 5)).sisaHari(_now), -2);
      expect(_absen(terakhir: DateTime(2026, 9, 5)).perluDikerjakan(_now), isTrue);
    });

    test('kemajuan dibatasi 0..1', () {
      expect(_absen(terakhir: DateTime(2026, 10, 2)).kemajuan(_now), 0);
      expect(_absen(terakhir: DateTime(2026, 9, 1)).kemajuan(_now), 1);
    });

    test('label sisa hari', () {
      expect(labelSisaHari(0), 'Hari ini');
      expect(labelSisaHari(1), 'Besok');
      expect(labelSisaHari(5), '5 hari lagi');
      expect(labelSisaHari(-3), 'Telat 3 hari');
    });

    test('urutan: yang paling mendesak di atas', () {
      final urut = urutkanBerkala([
        _absen(terakhir: DateTime(2026, 9, 30), judul: 'B'),
        _absen(terakhir: DateTime(2026, 9, 1), judul: 'A'),
        _absen(terakhir: DateTime(2026, 9, 30), judul: 'C', jarak: 7),
      ]);
      expect(urut.map((r) => r.title), ['A', 'C', 'B']);
    });

    test('dibaca dari baris database', () {
      final item = RutinitasBerkala.fromMap({
        'id': 'x',
        'user_id': 'u',
        'title': 'Absen akun',
        'interval_days': 25,
        'last_done_on': '2026-09-20',
        'remind_at': '07:30:00',
        'note': null,
      });
      expect(item.jatuhTempo, DateTime(2026, 10, 15));
      expect(item.remindAt, '07:30:00');
    });
  });

  group('pengingat berkala', () {
    test('H-1, hari-H, lalu diulang selama belum ditandai', () {
      final rencana = _rencana([_absen(terakhir: DateTime(2026, 9, 20))]);
      expect(rencana.map((r) => r.waktu), [
        DateTime(2026, 10, 14, 8),
        DateTime(2026, 10, 15, 8),
        DateTime(2026, 10, 16, 8),
        DateTime(2026, 10, 17, 8),
      ]);
      expect(rencana.map((r) => r.judul), [
        'Besok: Absen akun',
        'Absen akun hari ini',
        'Absen akun telat 1 hari',
        'Absen akun telat 2 hari',
      ]);
      expect(rencana.every((r) => r.kind == ReminderKind.berkala), isTrue);
    });

    test('jam khusus mengalahkan jam umum', () {
      final rencana = _rencana([_absen(terakhir: DateTime(2026, 9, 20), jam: '19:15:00')]);
      expect(rencana.first.waktu, DateTime(2026, 10, 14, 19, 15));
    });

    test('yang sudah telat mulai dari jam berikutnya yang masih di depan', () {
      // Jatuh tempo 30 Sep; jam 08.00 hari ini sudah lewat.
      final rencana = _rencana([_absen(terakhir: DateTime(2026, 9, 5))]);
      expect(rencana.map((r) => r.waktu), [
        DateTime(2026, 10, 3, 8),
        DateTime(2026, 10, 4, 8),
        DateTime(2026, 10, 5, 8),
      ]);
      expect(rencana.first.judul, 'Absen akun telat 3 hari');
    });

    test('jarak pendek tidak dapat H-1', () {
      final rencana = _rencana([_absen(terakhir: DateTime(2026, 10, 2), jarak: 2)]);
      expect(rencana.first.waktu, DateTime(2026, 10, 4, 8));
      expect(rencana.any((r) => r.judul.startsWith('Besok')), isFalse);
    });

    test('tidak dipasang kalau jenisnya dimatikan', () {
      final rencana = _rencana(
        [_absen(terakhir: DateTime(2026, 9, 20))],
        settings: const NotificationSettings(
          aktif: true,
          menitDalamHari: 8 * 60,
          jenisAktif: {ReminderKind.deadline},
        ),
      );
      expect(rencana, isEmpty);
    });
  });

  group('payload notifikasi', () {
    test('bolak-balik utuh, termasuk judul yang memuat "|"', () {
      const asli = PayloadBerkala(
        routineId: 'r1',
        userId: 'u1',
        title: 'Absen | akun A',
        intervalDays: 25,
        menitPengingat: 450,
      );
      final balik = PayloadBerkala.decode(asli.encode())!;
      expect(balik.routineId, 'r1');
      expect(balik.userId, 'u1');
      expect(balik.title, 'Absen | akun A');
      expect(balik.intervalDays, 25);
      expect(balik.menitPengingat, 450);
      expect(asli.encode().startsWith(PayloadBerkala.awalanUntuk('r1')), isTrue);
    });

    test('payload lain diabaikan', () {
      expect(PayloadBerkala.decode(null), isNull);
      expect(PayloadBerkala.decode('deadline|x'), isNull);
      expect(PayloadBerkala.decode('berkala|r1|u1|bukan-angka|0|x'), isNull);
    });

    test('pengingat berkala membawa payload, jenis lain tidak perlu', () {
      final rencana = _rencana([_absen(terakhir: DateTime(2026, 9, 20), jam: '07:30:00')]);
      final payload = PayloadBerkala.decode(rencana.first.payload)!;
      expect(payload.routineId, 'Absen akun');
      expect(payload.menitPengingat, 7 * 60 + 30);
    });
  });

  group('antrean offline', () {
    test('catatan tertunda memajukan tanggal terakhir', () {
      final hasil = terapkanAntrean(
        [_absen(terakhir: DateTime(2026, 9, 5))],
        [
          {'routine_id': 'Absen akun', 'done_on': '2026-10-01'},
          {'routine_id': 'Absen akun', 'done_on': '2026-10-02'},
          {'routine_id': 'lain', 'done_on': '2026-10-02'},
        ],
      );
      expect(hasil.single.lastDoneOn, DateTime(2026, 10, 2));
      expect(hasil.single.perluDikerjakan(_now), isFalse);
    });

    test('tidak pernah memundurkan', () {
      final hasil = terapkanAntrean(
        [_absen(terakhir: DateTime(2026, 10, 1))],
        [
          {'routine_id': 'Absen akun', 'done_on': '2026-09-01'},
        ],
      );
      expect(hasil.single.lastDoneOn, DateTime(2026, 10, 1));
    });
  });

  group('riwayat', () {
    test('telat dihitung dari jatuh tempo saat itu', () {
      final logs = [
        LogBerkala(id: '1', routineId: 'r', doneOn: DateTime(2026, 10, 2), dueOn: DateTime(2026, 9, 30)),
        LogBerkala(id: '2', routineId: 'r', doneOn: DateTime(2026, 9, 5), dueOn: DateTime(2026, 9, 5)),
        LogBerkala(id: '3', routineId: 'r', doneOn: DateTime(2026, 8, 10), dueOn: DateTime(2026, 8, 12)),
        LogBerkala(id: '4', routineId: 'r', doneOn: DateTime(2026, 7, 1)),
      ];
      expect(logs.map((l) => l.telatHari), [2, 0, 0, 0]);
      final ringkas = ringkasRiwayat(logs);
      expect(ringkas.total, 4);
      expect(ringkas.tepat, 3);
    });

    test('uuid v4 berbentuk benar dan unik', () {
      final a = uuidBaru();
      final b = uuidBaru();
      expect(a, matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')));
      expect(a, isNot(b));
    });
  });

  group('data widget', () {
    test('berisi jatuh tempo terurut dan lini masa per hari', () {
      final data = jsonDecode(dataWidgetRutinitas(
        berkala: [
          _absen(terakhir: DateTime(2026, 9, 30), judul: 'B'),
          _absen(terakhir: DateTime(2026, 9, 1), judul: 'A'),
        ],
        rutinitas: const [
          RoutineItem(id: '1', userId: 'u', dayOfWeek: 5, startTime: '05:45:00', title: 'Bangun'),
        ],
        jadwal: const [],
      )) as Map<String, dynamic>;

      expect(data['berkala'], [
        {'t': 'A', 'd': '2026-09-26'},
        {'t': 'B', 'd': '2026-10-25'},
      ]);
      expect(data['harian']['5'], [
        {'m': '05:45', 't': 'Bangun'},
      ]);
      expect(data['harian']['1'], isEmpty);
    });
  });
}
