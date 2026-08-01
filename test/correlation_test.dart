import 'package:flutter_test/flutter_test.dart';
import 'package:tracking/features/academic/data/models/task.dart';
import 'package:tracking/features/insight/domain/correlation.dart';
import 'package:tracking/features/run/data/run_repository.dart';
import 'package:tracking/features/workout/data/models/workout_session.dart';

/// Senin, 3 Agustus 2026. Semua minggu uji berada sebelum tanggal ini.
final _now = DateTime(2026, 8, 3);

/// Senin minggu ke-[index] sebelum minggu berjalan.
DateTime _monday(int weeksAgo) => _now.subtract(Duration(days: 7 * weeksAgo));

AcademicTask _task({
  required DateTime completedAt,
  required DateTime deadline,
}) {
  return AcademicTask(
    id: '${completedAt.toIso8601String()}-${deadline.toIso8601String()}',
    userId: 'u',
    title: 'Tugas',
    deadline: deadline,
    priority: TaskPriority.medium,
    status: TaskStatus.done,
    createdAt: deadline.subtract(const Duration(days: 14)),
    completedAt: completedAt,
  );
}

WorkoutSession _session(DateTime date) => WorkoutSession(
      id: date.toIso8601String(),
      userId: 'u',
      sessionDate: date,
      createdAt: date,
      exercises: const [],
    );

RunLog _run(DateTime date) => RunLog(
      id: date.toIso8601String(),
      startedAt: date,
      durationSeconds: 1800,
      distanceMeters: 5000,
      route: const [],
    );

/// Susun satu minggu: berapa hari olahraga, dan berapa hari sebelum tenggat
/// tugasnya diselesaikan.
({List<WorkoutSession> sessions, List<AcademicTask> tasks}) _week(
  int weeksAgo, {
  required int hariOlahraga,
  required int jumlahTugas,
  required double hariSebelumTenggat,
}) {
  final senin = _monday(weeksAgo);
  return (
    sessions: [
      for (var i = 0; i < hariOlahraga; i++) _session(senin.add(Duration(days: i))),
    ],
    tasks: [
      for (var i = 0; i < jumlahTugas; i++)
        _task(
          completedAt: senin.add(Duration(days: i, hours: 9)),
          deadline: senin.add(
            Duration(
              days: i,
              hours: 9,
              minutes: (hariSebelumTenggat * 24 * 60).round(),
            ),
          ),
        ),
    ],
  );
}

void main() {
  group('buildWeeks', () {
    test('beberapa sesi dalam satu hari dihitung satu hari olahraga', () {
      final hari = _monday(2);
      final weeks = buildWeeks(
        tasks: const [],
        sessions: [_session(hari), _session(hari), _session(hari)],
        runs: const [],
      );

      expect(weeks.values.single.sesiOlahraga, 1);
    });

    test('lari dan sesi gym di hari sama tidak dihitung dua kali', () {
      final hari = _monday(2);
      final weeks = buildWeeks(
        tasks: const [],
        sessions: [_session(hari)],
        runs: [_run(hari)],
      );

      expect(weeks.values.single.sesiOlahraga, 1);
    });

    test('lari saja tetap terhitung hari olahraga', () {
      final weeks = buildWeeks(
        tasks: const [],
        sessions: const [],
        runs: [_run(_monday(2)), _run(_monday(2).add(const Duration(days: 2)))],
      );

      expect(weeks.values.single.sesiOlahraga, 2);
    });

    test('hari dalam satu minggu dikelompokkan ke Senin yang sama', () {
      final senin = _monday(2);
      final weeks = buildWeeks(
        tasks: const [],
        sessions: [
          _session(senin),
          _session(senin.add(const Duration(days: 6))),
        ],
        runs: const [],
      );

      expect(weeks, hasLength(1));
      expect(weeks.keys.single, senin);
    });

    test('tugas tepat waktu dan terlambat dibedakan', () {
      final senin = _monday(2);
      final weeks = buildWeeks(
        tasks: [
          _task(
            completedAt: senin.add(const Duration(days: 1)),
            deadline: senin.add(const Duration(days: 3)),
          ),
          _task(
            completedAt: senin.add(const Duration(days: 4)),
            deadline: senin.add(const Duration(days: 2)),
          ),
        ],
        sessions: const [],
        runs: const [],
      );

      final bucket = weeks.values.single;
      expect(bucket.tugasSelesai, 2);
      expect(bucket.tugasTepatWaktu, 1);
      expect(bucket.persenTepatWaktu, 50);
    });

    test('rata-rata hari lebih awal bernilai positif saat dikerjakan lebih dini', () {
      final senin = _monday(2);
      final weeks = buildWeeks(
        tasks: [
          _task(
            completedAt: senin,
            deadline: senin.add(const Duration(days: 2)),
          ),
        ],
        sessions: const [],
        runs: const [],
      );

      expect(weeks.values.single.rataHariLebihAwal, closeTo(2, 0.01));
    });

    test('minggu tanpa tugas tidak membagi dengan nol', () {
      final weeks = buildWeeks(
        tasks: const [],
        sessions: [_session(_monday(2))],
        runs: const [],
      );

      final bucket = weeks.values.single;
      expect(bucket.persenTepatWaktu, 0);
      expect(bucket.rataHariLebihAwal, 0);
    });
  });

  group('findInsights — pengaman sampel kecil', () {
    test('data kosong tidak menghasilkan pola', () {
      expect(
        findInsights(tasks: const [], sessions: const [], runs: const [], now: _now),
        isEmpty,
      );
    });

    test('dua minggu aktif belum cukup untuk menyimpulkan apa pun', () {
      final sessions = <WorkoutSession>[];
      final tasks = <AcademicTask>[];

      // 2 minggu aktif + 4 minggu santai: kelompok aktif di bawah ambang.
      for (var i = 1; i <= 2; i++) {
        final w = _week(i, hariOlahraga: 4, jumlahTugas: 2, hariSebelumTenggat: 3);
        sessions.addAll(w.sessions);
        tasks.addAll(w.tasks);
      }
      for (var i = 3; i <= 6; i++) {
        final w = _week(i, hariOlahraga: 0, jumlahTugas: 2, hariSebelumTenggat: 0);
        sessions.addAll(w.sessions);
        tasks.addAll(w.tasks);
      }

      final insights = findInsights(
        tasks: tasks,
        sessions: sessions,
        runs: const [],
        now: _now,
      );

      // Perbandingan dua kelompok tidak boleh muncul.
      expect(
        insights.any((i) => i.kind == InsightKind.olahragaVsKecepatan),
        isFalse,
      );
      expect(
        insights.any((i) => i.kind == InsightKind.olahragaVsKetepatan),
        isFalse,
      );
    });

    test('minggu berjalan tidak ikut dihitung', () {
      // Minggu ke-0 adalah minggu berjalan; datanya belum lengkap.
      final w = _week(0, hariOlahraga: 5, jumlahTugas: 3, hariSebelumTenggat: 4);

      final weeks = buildWeeks(tasks: w.tasks, sessions: w.sessions, runs: const []);
      expect(weeks, isNotEmpty);

      final insights = findInsights(
        tasks: w.tasks,
        sessions: w.sessions,
        runs: const [],
        now: _now,
      );
      expect(insights, isEmpty);
    });

    test('perbedaan terlalu kecil tidak dilaporkan', () {
      final sessions = <WorkoutSession>[];
      final tasks = <AcademicTask>[];

      // Kedua kelompok praktis sama; selisihnya di bawah ambang.
      for (var i = 1; i <= 3; i++) {
        final w = _week(i, hariOlahraga: 4, jumlahTugas: 2, hariSebelumTenggat: 2);
        sessions.addAll(w.sessions);
        tasks.addAll(w.tasks);
      }
      for (var i = 4; i <= 6; i++) {
        final w = _week(i, hariOlahraga: 0, jumlahTugas: 2, hariSebelumTenggat: 2);
        sessions.addAll(w.sessions);
        tasks.addAll(w.tasks);
      }

      final insights = findInsights(
        tasks: tasks,
        sessions: sessions,
        runs: const [],
        now: _now,
      );

      expect(
        insights.any((i) => i.kind == InsightKind.olahragaVsKecepatan),
        isFalse,
      );
    });
  });

  group('findInsights — pola yang ditemukan', () {
    List<Insight> susun({
      required double awalSaatAktif,
      required double awalSaatSantai,
    }) {
      final sessions = <WorkoutSession>[];
      final tasks = <AcademicTask>[];

      for (var i = 1; i <= 3; i++) {
        final w = _week(
          i,
          hariOlahraga: 4,
          jumlahTugas: 2,
          hariSebelumTenggat: awalSaatAktif,
        );
        sessions.addAll(w.sessions);
        tasks.addAll(w.tasks);
      }
      for (var i = 4; i <= 6; i++) {
        final w = _week(
          i,
          hariOlahraga: 0,
          jumlahTugas: 2,
          hariSebelumTenggat: awalSaatSantai,
        );
        sessions.addAll(w.sessions);
        tasks.addAll(w.tasks);
      }

      return findInsights(
        tasks: tasks,
        sessions: sessions,
        runs: const [],
        now: _now,
      );
    }

    test('minggu aktif yang lebih awal terdeteksi', () {
      final insights = susun(awalSaatAktif: 3, awalSaatSantai: 0.5);
      final pola = insights.firstWhere(
        (i) => i.kind == InsightKind.olahragaVsKecepatan,
      );

      expect(pola.headline, contains('lebih awal'));
      expect(pola.weeksHigh, 3);
      expect(pola.weeksLow, 3);
    });

    test('arah sebaliknya juga dilaporkan apa adanya', () {
      // Kalau datamu bilang minggu aktif justru lebih mepet, itu yang ditulis.
      final insights = susun(awalSaatAktif: 0.5, awalSaatSantai: 3);
      final pola = insights.firstWhere(
        (i) => i.kind == InsightKind.olahragaVsKecepatan,
      );

      expect(pola.headline, contains('lebih mepet'));
    });

    test('ketepatan waktu dibandingkan antar kelompok', () {
      final sessions = <WorkoutSession>[];
      final tasks = <AcademicTask>[];

      // Aktif: selalu tepat waktu. Santai: selalu telat.
      for (var i = 1; i <= 3; i++) {
        final w = _week(i, hariOlahraga: 4, jumlahTugas: 2, hariSebelumTenggat: 2);
        sessions.addAll(w.sessions);
        tasks.addAll(w.tasks);
      }
      for (var i = 4; i <= 6; i++) {
        final w = _week(i, hariOlahraga: 0, jumlahTugas: 2, hariSebelumTenggat: -2);
        sessions.addAll(w.sessions);
        tasks.addAll(w.tasks);
      }

      final pola = findInsights(
        tasks: tasks,
        sessions: sessions,
        runs: const [],
        now: _now,
      ).firstWhere((i) => i.kind == InsightKind.olahragaVsKetepatan);

      expect(pola.headline, contains('naik'));
      expect(pola.detail, contains('100%'));
    });

    test('konsistensi dihitung dari minggu yang ada tugasnya', () {
      final insights = susun(awalSaatAktif: 3, awalSaatSantai: 0.5);
      final pola = insights.firstWhere(
        (i) => i.kind == InsightKind.konsistensi,
      );

      // 3 dari 6 minggu ada olahraganya.
      expect(pola.headline, contains('50%'));
    });
  });

  group('weeksUntilReady', () {
    test('tanpa data, butuh enam minggu penuh', () {
      expect(
        weeksUntilReady(
          tasks: const [],
          sessions: const [],
          runs: const [],
          now: _now,
        ),
        6,
      );
    });

    test('berkurang seiring minggu terkumpul', () {
      final tasks = <AcademicTask>[];
      for (var i = 1; i <= 2; i++) {
        tasks.addAll(
          _week(i, hariOlahraga: 0, jumlahTugas: 1, hariSebelumTenggat: 1).tasks,
        );
      }

      expect(
        weeksUntilReady(
          tasks: tasks,
          sessions: const [],
          runs: const [],
          now: _now,
        ),
        4,
      );
    });

    test('null setelah cukup', () {
      final tasks = <AcademicTask>[];
      for (var i = 1; i <= 6; i++) {
        tasks.addAll(
          _week(i, hariOlahraga: 0, jumlahTugas: 1, hariSebelumTenggat: 1).tasks,
        );
      }

      expect(
        weeksUntilReady(
          tasks: tasks,
          sessions: const [],
          runs: const [],
          now: _now,
        ),
        isNull,
      );
    });
  });
}
