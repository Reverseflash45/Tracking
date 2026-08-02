import 'package:flutter_test/flutter_test.dart';
import 'package:tracking/core/notifications/smart_reminders.dart';
import 'package:tracking/features/academic/data/models/class_schedule.dart';
import 'package:tracking/features/academic/data/models/task.dart';
import 'package:tracking/features/finance/domain/finance_stats.dart';
import 'package:tracking/features/finance/domain/transaction.dart';

/// Rabu, 5 Agustus 2026, jam 10 pagi.
final _now = DateTime(2026, 8, 5, 10);

const _semua = NotificationSettings(
  aktif: true,
  menitDalamHari: 8 * 60,
  jenisAktif: {
    ReminderKind.deadline,
    ReminderKind.kelas,
    ReminderKind.streak,
    ReminderKind.tagihan,
    ReminderKind.catatMakan,
  },
);

NotificationSettings _hanya(Set<ReminderKind> jenis) => NotificationSettings(
      aktif: true,
      menitDalamHari: 8 * 60,
      jenisAktif: jenis,
    );

AcademicTask _tugas(String judul, DateTime deadline, {TaskStatus status = TaskStatus.todo}) =>
    AcademicTask(
      id: judul,
      userId: 'u',
      title: judul,
      deadline: deadline,
      priority: TaskPriority.medium,
      status: status,
      createdAt: _now,
    );

ClassSchedule _kelas({
  required int hari,
  String mulai = '13:00:00',
  String nama = 'Basis Data',
  String? ruang,
  DateTime? phl,
}) =>
    ClassSchedule(
      id: '$nama-$hari-$mulai',
      userId: 'u',
      courseId: 'c',
      courseName: nama,
      dayOfWeek: hari,
      startTime: mulai,
      endTime: '15:00:00',
      room: ruang,
      isPhl: phl != null,
      specificDate: phl,
    );

RecurringExpense _tagihan(String nama, int dueDay, {double amount = 800000, bool active = true}) =>
    RecurringExpense(
      id: nama,
      name: nama,
      amount: amount,
      category: TxCategory.lainnya,
      dueDay: dueDay,
      active: active,
    );

List<PlannedReminder> _rencana(ReminderInput data, {NotificationSettings? settings}) =>
    planReminders(data: data, settings: settings ?? _semua, now: _now);

void main() {
  group('saklar', () {
    test('saklar utama mati berarti tidak ada apa pun', () {
      final hasil = planReminders(
        data: ReminderInput(tasks: [_tugas('A', _now.add(const Duration(days: 3)))]),
        settings: const NotificationSettings(aktif: false, menitDalamHari: 480),
        now: _now,
      );
      expect(hasil, isEmpty);
    });

    test('jenis yang dimatikan tidak ikut dipasang', () {
      final data = ReminderInput(
        tasks: [_tugas('A', _now.add(const Duration(days: 3)))],
        schedules: [_kelas(hari: 4)],
      );

      final hasil = _rencana(data, settings: _hanya({ReminderKind.kelas}));
      expect(hasil.map((r) => r.kind).toSet(), {ReminderKind.kelas});
    });

    test('semuanya urut dari waktu terdekat', () {
      final data = ReminderInput(
        tasks: [_tugas('A', _now.add(const Duration(days: 10)))],
        schedules: [_kelas(hari: 3)],
        recurring: [_tagihan('Kos', 20)],
        streakHari: 12,
      );

      final hasil = _rencana(data);
      for (var i = 1; i < hasil.length; i++) {
        expect(hasil[i].waktu.isBefore(hasil[i - 1].waktu), isFalse);
      }
    });
  });

  group('deadline', () {
    test('tugas selesai tidak diingatkan', () {
      final data = ReminderInput(
        tasks: [
          _tugas('Beres', _now.add(const Duration(days: 3)), status: TaskStatus.done),
        ],
      );
      expect(_rencana(data, settings: _hanya({ReminderKind.deadline})), isEmpty);
    });

    test('offset yang waktunya sudah lewat dilewati', () {
      // Deadline besok: H-7 dan H-3 sudah lewat, H-1 jam 08.00 hari ini juga
      // sudah lewat (sekarang jam 10). Sisa hanya H-0 besok.
      final data = ReminderInput(tasks: [_tugas('Besok', _now.add(const Duration(days: 1)))]);
      final hasil = _rencana(data, settings: _hanya({ReminderKind.deadline}));

      expect(hasil, hasLength(1));
      expect(hasil.single.judul, 'Deadline hari ini!');
      expect(hasil.single.waktu, DateTime(2026, 8, 6, 8));
    });

    test('nama mata kuliah ikut disebut kalau ada', () {
      final data = ReminderInput(
        tasks: [
          AcademicTask(
            id: 't',
            userId: 'u',
            title: 'Laporan',
            courseName: 'Basis Data',
            deadline: _now.add(const Duration(days: 3)),
            priority: TaskPriority.high,
            status: TaskStatus.todo,
            createdAt: _now,
          ),
        ],
      );

      final hasil = _rencana(data, settings: _hanya({ReminderKind.deadline}));
      expect(hasil.first.isi, contains('(Basis Data)'));
    });

    test('jumlah tugas dibatasi supaya tidak menghabiskan kuota alarm', () {
      final data = ReminderInput(
        tasks: [
          for (var i = 0; i < 80; i++) _tugas('T$i', _now.add(Duration(days: 20 + i))),
        ],
      );

      final hasil = _rencana(data, settings: _hanya({ReminderKind.deadline}));
      expect(hasil.length, lessThanOrEqualTo(kMaxTasksToSchedule * kReminderOffsetDays.length));
    });
  });

  group('jadwal kuliah', () {
    test('kelas hari ini yang belum mulai tetap diingatkan', () {
      final data = ReminderInput(schedules: [_kelas(hari: 3, mulai: '13:00:00', ruang: 'GD-301')]);
      final hasil = _rencana(data, settings: _hanya({ReminderKind.kelas}));

      expect(hasil.first.waktu, DateTime(2026, 8, 5, 12, 30));
      expect(hasil.first.isi, contains('GD-301'));
    });

    test('kelas yang jamnya sudah lewat hari ini dilewati', () {
      final data = ReminderInput(schedules: [_kelas(hari: 3, mulai: '08:00:00')]);
      final hasil = _rencana(data, settings: _hanya({ReminderKind.kelas}));

      // Hari ini sudah lewat; yang tersisa cuma pekan depan di dalam horizon.
      expect(hasil.every((r) => r.waktu.isAfter(_now)), isTrue);
    });

    test('kelas mingguan muncul sekali dalam horizon seminggu', () {
      final data = ReminderInput(schedules: [_kelas(hari: 1)]); // Senin
      final hasil = _rencana(data, settings: _hanya({ReminderKind.kelas}));

      expect(hasil, hasLength(1));
      expect(hasil.single.waktu.weekday, DateTime.monday);
    });

    test('PHL hanya berbunyi di tanggalnya sendiri', () {
      final data = ReminderInput(
        schedules: [_kelas(hari: 5, phl: DateTime(2026, 8, 7))],
      );
      final hasil = _rencana(data, settings: _hanya({ReminderKind.kelas}));

      expect(hasil, hasLength(1));
      expect(hasil.single.waktu.day, 7);
    });

    test('PHL di luar horizon tidak dipasang', () {
      final data = ReminderInput(
        schedules: [_kelas(hari: 5, phl: DateTime(2026, 9, 4))],
      );
      expect(_rencana(data, settings: _hanya({ReminderKind.kelas})), isEmpty);
    });

    test('jeda mengikuti setelan', () {
      final data = ReminderInput(schedules: [_kelas(hari: 3, mulai: '13:00:00')]);
      final hasil = planReminders(
        data: data,
        settings: const NotificationSettings(
          aktif: true,
          menitDalamHari: 480,
          jenisAktif: {ReminderKind.kelas},
          menitSebelumKelas: 60,
        ),
        now: _now,
      );

      expect(hasil.first.waktu, DateTime(2026, 8, 5, 12));
    });

    test('jam yang tidak terbaca dilewati, bukan bikin crash', () {
      final data = ReminderInput(schedules: [_kelas(hari: 3, mulai: 'rusak')]);
      expect(_rencana(data, settings: _hanya({ReminderKind.kelas})), isEmpty);
    });
  });

  group('streak', () {
    const setelan = {ReminderKind.streak};

    test('tanpa streak berjalan tidak ada yang perlu diselamatkan', () {
      expect(_rencana(const ReminderInput(streakHari: 0), settings: _hanya(setelan)), isEmpty);
    });

    test('belum bergerak hari ini: teguran malam ini dipasang', () {
      final hasil = _rencana(
        const ReminderInput(streakHari: 12),
        settings: _hanya(setelan),
      );

      final malamIni = hasil.firstWhere((r) => r.waktu.day == 5);
      expect(malamIni.waktu, DateTime(2026, 8, 5, 19));
      expect(malamIni.judul, contains('12 hari'));
    });

    test('sudah bergerak hari ini: teguran malam ini tidak dipasang', () {
      final hasil = _rencana(
        const ReminderInput(streakHari: 12, bergerakHariIni: true),
        settings: _hanya(setelan),
      );
      expect(hasil.any((r) => r.waktu.day == 5), isFalse);
    });

    test('hari istirahat yang sudah ditandai tidak ditegur', () {
      final hasil = _rencana(
        const ReminderInput(streakHari: 12, istirahatHariIni: true),
        settings: _hanya(setelan),
      );
      expect(hasil.any((r) => r.waktu.day == 5), isFalse);
    });

    test('hari-hari berikutnya memakai kalimat ajakan, bukan klaim', () {
      final hasil = _rencana(
        const ReminderInput(streakHari: 12, bergerakHariIni: true),
        settings: _hanya(setelan),
      );

      expect(hasil, hasLength(kLookaheadHari));
      // Tidak boleh mengaku tahu keadaan hari yang belum terjadi.
      expect(hasil.every((r) => !r.isi.contains('belum ada catatan')), isTrue);
    });
  });

  group('tagihan rutin', () {
    const setelan = {ReminderKind.tagihan};

    test('diingatkan sehari sebelum jatuh tempo', () {
      final hasil = _rencana(
        ReminderInput(recurring: [_tagihan('Kos', 20)]),
        settings: _hanya(setelan),
      );

      expect(hasil.single.waktu, DateTime(2026, 8, 19, 8));
      expect(hasil.single.judul, 'Kos jatuh tempo besok');
    });

    test('nominal ditulis dengan pemisah ribuan', () {
      final hasil = _rencana(
        ReminderInput(recurring: [_tagihan('Kos', 20, amount: 850000)]),
        settings: _hanya(setelan),
      );
      expect(hasil.single.isi, startsWith('Rp 850.000'));
    });

    test('tagihan nonaktif dilewati', () {
      final hasil = _rencana(
        ReminderInput(recurring: [_tagihan('Netflix', 20, active: false)]),
        settings: _hanya(setelan),
      );
      expect(hasil, isEmpty);
    });

    test('jatuh tempo yang sudah lewat bulan ini lompat ke bulan depan', () {
      // Tanggal 1 sudah lewat (sekarang tanggal 5).
      final hasil = _rencana(
        ReminderInput(recurring: [_tagihan('Internet', 1)]),
        settings: _hanya(setelan),
      );
      expect(hasil.single.waktu, DateTime(2026, 8, 31, 8));
    });

    test('H-1 yang jatuh hari ini tapi jamnya sudah lewat dilewati', () {
      // Jatuh tempo tanggal 6, H-1 = hari ini jam 08.00 — sudah lewat.
      final hasil = _rencana(
        ReminderInput(recurring: [_tagihan('Listrik', 6)]),
        settings: _hanya(setelan),
      );
      expect(hasil, isEmpty);
    });
  });

  group('catat makan', () {
    const setelan = {ReminderKind.catatMakan};

    test('tidak menegur orang yang memang tidak memakai fiturnya', () {
      final hasil = _rencana(
        const ReminderInput(pernahCatatMakan: false),
        settings: _hanya(setelan),
      );
      expect(hasil, isEmpty);
    });

    test('sudah mencatat hari ini: teguran malam ini tidak dipasang', () {
      final hasil = _rencana(
        const ReminderInput(pernahCatatMakan: true, sudahCatatMakanHariIni: true),
        settings: _hanya(setelan),
      );
      expect(hasil.any((r) => r.waktu.day == 5), isFalse);
      expect(hasil, hasLength(kLookaheadHari));
    });

    test('belum mencatat: malam ini plus hari-hari berikutnya', () {
      final hasil = _rencana(
        const ReminderInput(pernahCatatMakan: true),
        settings: _hanya(setelan),
      );
      expect(hasil, hasLength(kLookaheadHari + 1));
      expect(hasil.first.waktu, DateTime(2026, 8, 5, 20, 30));
    });
  });

  group('batas jumlah', () {
    test('total tidak pernah melewati kuota alarm', () {
      final data = ReminderInput(
        tasks: [
          for (var i = 0; i < 60; i++) _tugas('T$i', _now.add(Duration(days: 30 + i))),
        ],
        schedules: [
          for (var hari = 1; hari <= 7; hari++)
            for (final jam in ['08:00:00', '11:00:00', '14:00:00'])
              _kelas(hari: hari, mulai: jam, nama: 'M$hari$jam'),
        ],
        streakHari: 5,
      );

      expect(_rencana(data).length, kMaxReminders);
    });
  });

  group('NotificationSettings', () {
    test('dua setelan dengan jenis sama dianggap sama', () {
      const a = NotificationSettings(
        aktif: true,
        menitDalamHari: 480,
        jenisAktif: {ReminderKind.kelas, ReminderKind.streak},
      );
      const b = NotificationSettings(
        aktif: true,
        menitDalamHari: 480,
        jenisAktif: {ReminderKind.streak, ReminderKind.kelas},
      );

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('nyala() ikut saklar utama', () {
      const mati = NotificationSettings(
        aktif: false,
        menitDalamHari: 480,
        jenisAktif: {ReminderKind.kelas},
      );
      expect(mati.nyala(ReminderKind.kelas), isFalse);
    });
  });
}
