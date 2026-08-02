import 'package:flutter_test/flutter_test.dart';
import 'package:tracking/features/academic/data/models/task.dart';
import 'package:tracking/features/academic/domain/recurring_task.dart';

/// Rabu, 5 Agustus 2026, jam 10 pagi.
final _now = DateTime(2026, 8, 5, 10);

RecurringTask _template({
  String id = 'r1',
  String title = 'Laporan praktikum',
  int weekday = DateTime.monday,
  int deadlineMinute = 23 * 60 + 59,
  bool active = true,
}) =>
    RecurringTask(
      id: id,
      userId: 'u',
      title: title,
      priority: TaskPriority.medium,
      weekday: weekday,
      deadlineMinute: deadlineMinute,
      active: active,
    );

AcademicTask _tugasDari(String recurringId, DateTime tanggal) => AcademicTask(
      id: '$recurringId-$tanggal',
      userId: 'u',
      title: 'apa saja',
      deadline: tanggal,
      priority: TaskPriority.medium,
      status: TaskStatus.todo,
      createdAt: _now,
      recurringId: recurringId,
      recurringOn: tanggal,
    );

void main() {
  group('occurrencesToCreate', () {
    test('template mingguan menghasilkan tiga kejadian dalam horizon', () {
      // Dari Rabu 5 Agt, Senin berikutnya: 10, 17, 24 Agt (horizon 21 hari).
      final hasil = occurrencesToCreate(
        templates: [_template()],
        sudahAda: const {},
        now: _now,
      );

      expect(hasil.map((o) => o.tanggal.day), [10, 17, 24]);
      expect(hasil.every((o) => o.deadline.weekday == DateTime.monday), isTrue);
    });

    test('jam deadline mengikuti template', () {
      final hasil = occurrencesToCreate(
        templates: [_template(deadlineMinute: 17 * 60 + 30)],
        sudahAda: const {},
        now: _now,
      );
      expect(hasil.first.deadline, DateTime(2026, 8, 10, 17, 30));
    });

    test('template nonaktif dilewati', () {
      final hasil = occurrencesToCreate(
        templates: [_template(active: false)],
        sudahAda: const {},
        now: _now,
      );
      expect(hasil, isEmpty);
    });

    test('kejadian yang sudah ada tidak dibuat lagi', () {
      final hasil = occurrencesToCreate(
        templates: [_template()],
        sudahAda: {occurrenceKey('r1', DateTime(2026, 8, 10))},
        now: _now,
      );
      expect(hasil.map((o) => o.tanggal.day), [17, 24]);
    });

    test('menjalankan dua kali berturut-turut tidak menghasilkan kembaran', () {
      final pertama = occurrencesToCreate(
        templates: [_template()],
        sudahAda: const {},
        now: _now,
      );
      final kedua = occurrencesToCreate(
        templates: [_template()],
        sudahAda: {for (final o in pertama) occurrenceKey(o.sumber.id, o.tanggal)},
        now: _now,
      );
      expect(kedua, isEmpty);
    });

    test('kejadian hari ini yang jamnya belum lewat tetap dibuat', () {
      // Hari ini Rabu jam 10, deadline template jam 23.59.
      final hasil = occurrencesToCreate(
        templates: [_template(weekday: DateTime.wednesday)],
        sudahAda: const {},
        now: _now,
      );
      expect(hasil.first.tanggal.day, 5);
    });

    test('kejadian hari ini yang jamnya sudah lewat dilewati', () {
      // Tugas yang lahir sudah terlambat cuma jadi angka merah palsu.
      final hasil = occurrencesToCreate(
        templates: [_template(weekday: DateTime.wednesday, deadlineMinute: 8 * 60)],
        sudahAda: const {},
        now: _now,
      );
      expect(hasil.first.tanggal.day, 12);
    });

    test('beberapa template diurutkan dari deadline terdekat', () {
      final hasil = occurrencesToCreate(
        templates: [
          _template(id: 'senin', weekday: DateTime.monday),
          _template(id: 'kamis', weekday: DateTime.thursday),
        ],
        sudahAda: const {},
        now: _now,
      );

      expect(hasil.first.sumber.id, 'kamis'); // 6 Agt lebih dekat dari 10 Agt
      for (var i = 1; i < hasil.length; i++) {
        expect(hasil[i].deadline.isBefore(hasil[i - 1].deadline), isFalse);
      }
    });

    test('horizon bisa dipersempit', () {
      final hasil = occurrencesToCreate(
        templates: [_template()],
        sudahAda: const {},
        now: _now,
        horizonHari: 7,
      );
      expect(hasil, hasLength(1));
    });

    test('tanpa template tidak error', () {
      expect(
        occurrencesToCreate(templates: const [], sudahAda: const {}, now: _now),
        isEmpty,
      );
    });
  });

  group('existingOccurrenceKeys', () {
    test('tugas biasa tidak ikut jadi kunci', () {
      final kunci = existingOccurrenceKeys([
        AcademicTask(
          id: 't',
          userId: 'u',
          title: 'Tugas manual',
          deadline: _now,
          priority: TaskPriority.medium,
          status: TaskStatus.todo,
          createdAt: _now,
        ),
      ]);
      expect(kunci, isEmpty);
    });

    test('tugas dari template menghasilkan kunci yang cocok', () {
      final tanggal = DateTime(2026, 8, 10);
      final kunci = existingOccurrenceKeys([_tugasDari('r1', tanggal)]);
      expect(kunci, {occurrenceKey('r1', tanggal)});
    });

    test('jam pada tanggal tidak memengaruhi kunci', () {
      final a = occurrenceKey('r1', DateTime(2026, 8, 10));
      final b = occurrenceKey('r1', DateTime(2026, 8, 10, 23, 59));
      expect(a, b);
    });
  });

  group('RecurringTask', () {
    test('jamLabel dipadding dua digit', () {
      expect(_template(deadlineMinute: 9 * 60 + 5).jamLabel, '09:05');
      expect(_template(deadlineMinute: 23 * 60 + 59).jamLabel, '23:59');
    });

    test('fromMap membaca kolom apa adanya', () {
      final template = RecurringTask.fromMap({
        'id': 'r1',
        'user_id': 'u',
        'course_id': 'c1',
        'courses': {'name': 'Basis Data'},
        'title': 'Laporan',
        'description': null,
        'priority': 'high',
        'weekday': 1,
        'deadline_minute': 1439,
        'active': true,
      });

      expect(template.courseName, 'Basis Data');
      expect(template.priority, TaskPriority.high);
      expect(template.weekday, DateTime.monday);
    });
  });
}
