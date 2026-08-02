import 'package:flutter_test/flutter_test.dart';
import 'package:tracking/features/academic/data/models/task.dart';
import 'package:tracking/features/finance/domain/transaction.dart';
import 'package:tracking/features/goals/domain/goal.dart';
import 'package:tracking/features/run/data/run_repository.dart';
import 'package:tracking/features/sleep/data/sleep_repository.dart';
import 'package:tracking/features/workout/data/models/workout_session.dart';

/// Rabu, 5 Agustus 2026 — hari ke-5 dari 31 hari Agustus.
final _now = DateTime(2026, 8, 5, 10);

Goal _goal({
  GoalMetric metric = GoalMetric.jarakLari,
  double target = 20,
  GoalPeriod period = GoalPeriod.bulanan,
  DateTime? mulai,
  DateTime? selesai,
  bool archived = false,
}) =>
    Goal(
      id: 'g-${metric.name}',
      title: 'Target',
      metric: metric,
      targetValue: target,
      period: period,
      startDate: mulai,
      endDate: selesai,
      archived: archived,
    );

RunLog _lari(DateTime tanggal, double km) => RunLog(
      id: '$tanggal',
      startedAt: tanggal,
      durationSeconds: 1800,
      distanceMeters: km * 1000,
      route: const [],
    );

WorkoutSession _sesi(DateTime tanggal) => WorkoutSession(
      id: '$tanggal',
      userId: 'u',
      sessionDate: tanggal,
      createdAt: tanggal,
      exercises: const [],
    );

AcademicTask _tugas({DateTime? selesai, DateTime? deadline}) => AcademicTask(
      id: '$selesai-$deadline',
      userId: 'u',
      title: 'Tugas',
      deadline: deadline ?? _now,
      priority: TaskPriority.medium,
      status: selesai == null ? TaskStatus.todo : TaskStatus.done,
      createdAt: _now,
      completedAt: selesai,
    );

SleepLog _tidur(DateTime tanggal, double jam) =>
    SleepLog(id: '$tanggal', loggedOn: tanggal, hours: jam);

Transaction _tx(DateTime tanggal, double jumlah, TxKind kind) => Transaction(
      id: '$tanggal-$jumlah-$kind',
      occurredOn: tanggal,
      kind: kind,
      category: TxCategory.lainnya,
      amount: jumlah,
    );

GoalProgress _eval(Goal goal, GoalData data) =>
    evaluateGoal(goal: goal, data: data, now: _now);

void main() {
  group('windowFor', () {
    test('bulanan menutup bulan berjalan, termasuk hari terakhirnya', () {
      final w = windowFor(_goal(), _now);
      expect(w.mulai, DateTime(2026, 8, 1));
      expect(w.selesai, DateTime(2026, 8, 31));
      expect(w.totalHari, 31);
    });

    test('Februari kabisat tidak salah hitung', () {
      final w = windowFor(_goal(), DateTime(2028, 2, 10));
      expect(w.selesai, DateTime(2028, 2, 29));
    });

    test('mingguan mulai Senin dan berakhir Minggu', () {
      final w = windowFor(_goal(period: GoalPeriod.mingguan), _now);
      expect(w.mulai, DateTime(2026, 8, 3)); // Senin
      expect(w.selesai, DateTime(2026, 8, 9)); // Minggu
      expect(w.totalHari, 7);
    });

    test('sekali jalan memakai tanggalnya apa adanya', () {
      final w = windowFor(
        _goal(
          period: GoalPeriod.sekali,
          mulai: DateTime(2026, 9, 1),
          selesai: DateTime(2026, 9, 30),
        ),
        _now,
      );
      expect(w.mulai, DateTime(2026, 9, 1));
      expect(w.selesai, DateTime(2026, 9, 30));
    });

    test('jendela bulanan ikut berpindah bulan', () {
      final september = windowFor(_goal(), DateTime(2026, 9, 15));
      expect(september.mulai, DateTime(2026, 9, 1));
    });
  });

  group('pengukuran', () {
    test('jarak lari dijumlahkan dalam jendela saja', () {
      final progress = _eval(
        _goal(metric: GoalMetric.jarakLari, target: 20),
        GoalData(runs: [
          _lari(DateTime(2026, 8, 2), 5),
          _lari(DateTime(2026, 8, 4), 3),
          _lari(DateTime(2026, 7, 30), 10), // bulan lalu
        ]),
      );
      expect(progress.nilai, closeTo(8, 0.001));
    });

    test('hari bergerak: lari dan sesi di hari yang sama tetap satu hari', () {
      final tanggal = DateTime(2026, 8, 4);
      final progress = _eval(
        _goal(metric: GoalMetric.hariBergerak, target: 20),
        GoalData(runs: [_lari(tanggal, 5)], sessions: [_sesi(tanggal)]),
      );
      expect(progress.nilai, 1);
    });

    test('tugas selesai dihitung dari tanggal penyelesaian, bukan deadline', () {
      final progress = _eval(
        _goal(metric: GoalMetric.tugasSelesai, target: 10),
        GoalData(tasks: [
          // Deadline bulan lalu, diselesaikan bulan ini — masuk hitungan.
          _tugas(selesai: DateTime(2026, 8, 3), deadline: DateTime(2026, 7, 28)),
          _tugas(selesai: DateTime(2026, 7, 3), deadline: DateTime(2026, 8, 3)),
          _tugas(),
        ]),
      );
      expect(progress.nilai, 1);
    });

    test('tugas tepat waktu hanya menghitung yang selesai sebelum deadline', () {
      final progress = _eval(
        _goal(metric: GoalMetric.tugasTepatWaktu, target: 10),
        GoalData(tasks: [
          _tugas(selesai: DateTime(2026, 8, 3), deadline: DateTime(2026, 8, 4)),
          _tugas(selesai: DateTime(2026, 8, 4), deadline: DateTime(2026, 8, 3)),
        ]),
      );
      expect(progress.nilai, 1);
    });

    test('malam tidur cukup memakai ambang yang sama dengan halaman Tidur', () {
      final progress = _eval(
        _goal(metric: GoalMetric.malamTidurCukup, target: 20),
        GoalData(sleeps: [
          _tidur(DateTime(2026, 8, 2), 7.5),
          _tidur(DateTime(2026, 8, 3), 6.5),
          _tidur(DateTime(2026, 8, 4), 9.5), // kelebihan tetap dihitung cukup
        ]),
      );
      expect(progress.nilai, 2);
    });

    test('uang tersisa boleh negatif', () {
      final progress = _eval(
        _goal(metric: GoalMetric.uangTersisa, target: 500000),
        GoalData(transactions: [
          _tx(DateTime(2026, 8, 2), 200000, TxKind.pemasukan),
          _tx(DateTime(2026, 8, 3), 350000, TxKind.pengeluaran),
        ]),
      );
      expect(progress.nilai, -150000);
    });

    test('batas pengeluaran hanya menjumlah pengeluaran', () {
      final progress = _eval(
        _goal(metric: GoalMetric.batasPengeluaran, target: 1000000),
        GoalData(transactions: [
          _tx(DateTime(2026, 8, 2), 900000, TxKind.pemasukan),
          _tx(DateTime(2026, 8, 3), 300000, TxKind.pengeluaran),
        ]),
      );
      expect(progress.nilai, 300000);
    });
  });

  group('status arah minimal', () {
    test('sampai target berarti tercapai', () {
      final progress = _eval(
        _goal(target: 20),
        GoalData(runs: [_lari(DateTime(2026, 8, 2), 25)]),
      );
      expect(progress.status, GoalStatus.tercapai);
    });

    test('sepadan dengan waktu yang terpakai berarti sesuai jalur', () {
      // Hari ke-5 dari 31: jatah wajar ≈ 3,2 km dari 20 km.
      final progress = _eval(
        _goal(target: 20),
        GoalData(runs: [_lari(DateTime(2026, 8, 2), 4)]),
      );
      expect(progress.status, GoalStatus.sesuaiJalur);
    });

    test('jauh tertinggal dari laju berarti perlu dikejar', () {
      final progress = _eval(
        _goal(target: 200),
        GoalData(runs: [_lari(DateTime(2026, 8, 2), 1)]),
      );
      expect(progress.status, GoalStatus.perluKejar);
    });

    test('target yang belum mulai ditandai jelas', () {
      final progress = _eval(
        _goal(
          period: GoalPeriod.sekali,
          mulai: DateTime(2026, 9, 1),
          selesai: DateTime(2026, 9, 30),
        ),
        const GoalData(),
      );
      expect(progress.status, GoalStatus.belumMulai);
      expect(progress.hariTerpakai, 0);
    });
  });

  group('status arah maksimal', () {
    test('melewati batas berarti terlampaui', () {
      final progress = _eval(
        _goal(metric: GoalMetric.batasPengeluaran, target: 1000000),
        GoalData(transactions: [_tx(DateTime(2026, 8, 2), 1200000, TxKind.pengeluaran)]),
      );
      expect(progress.status, GoalStatus.terlampaui);
    });

    test('boros lebih cepat daripada waktunya berjalan sudah diperingatkan', () {
      // Hari ke-5 dari 31, tapi 60% jatah sudah habis.
      final progress = _eval(
        _goal(metric: GoalMetric.batasPengeluaran, target: 1000000),
        GoalData(transactions: [_tx(DateTime(2026, 8, 2), 600000, TxKind.pengeluaran)]),
      );
      expect(progress.status, GoalStatus.perluKejar);
    });

    test('masih di dalam jatah berarti sesuai jalur', () {
      final progress = _eval(
        _goal(metric: GoalMetric.batasPengeluaran, target: 1000000),
        GoalData(transactions: [_tx(DateTime(2026, 8, 2), 100000, TxKind.pengeluaran)]),
      );
      expect(progress.status, GoalStatus.sesuaiJalur);
    });

    test('jendela berakhir tanpa melewati batas berarti tercapai', () {
      final progress = _eval(
        _goal(
          metric: GoalMetric.batasPengeluaran,
          target: 1000000,
          period: GoalPeriod.sekali,
          mulai: DateTime(2026, 7, 1),
          selesai: DateTime(2026, 7, 31),
        ),
        GoalData(transactions: [_tx(DateTime(2026, 7, 10), 500000, TxKind.pengeluaran)]),
      );
      expect(progress.status, GoalStatus.tercapai);
      expect(progress.sisaHari, 0);
    });
  });

  group('angka turunan', () {
    test('persen dipotong di 100 untuk bilah, mentahnya tidak', () {
      final progress = _eval(
        _goal(target: 10),
        GoalData(runs: [_lari(DateTime(2026, 8, 2), 15)]),
      );
      expect(progress.persen, 1.0);
      expect(progress.persenMentah, 150);
    });

    test('laju dibutuhkan dibagi sisa hari termasuk hari ini', () {
      // 20 km target, 2 km terkumpul, sisa 27 hari (5–31 Agustus).
      final progress = _eval(
        _goal(target: 20),
        GoalData(runs: [_lari(DateTime(2026, 8, 2), 2)]),
      );
      expect(progress.sisaHari, 27);
      expect(progress.lajuDibutuhkan, closeTo(18 / 27, 0.0001));
    });

    test('target yang sudah tercapai tidak menuntut laju apa pun', () {
      final progress = _eval(
        _goal(target: 5),
        GoalData(runs: [_lari(DateTime(2026, 8, 2), 9)]),
      );
      expect(progress.lajuDibutuhkan, isNull);
    });

    test('arah maksimal tidak punya laju yang perlu dikejar', () {
      final progress = _eval(
        _goal(metric: GoalMetric.batasPengeluaran, target: 1000000),
        const GoalData(),
      );
      expect(progress.lajuDibutuhkan, isNull);
    });
  });

  group('evaluateGoals', () {
    test('target arsip tidak ikut dievaluasi', () {
      final hasil = evaluateGoals(
        goals: [_goal(archived: true)],
        data: const GoalData(),
        now: _now,
      );
      expect(hasil, isEmpty);
    });

    test('yang perlu perhatian muncul lebih dulu, yang tercapai paling akhir', () {
      final hasil = evaluateGoals(
        goals: [
          _goal(metric: GoalMetric.jarakLari, target: 1), // tercapai
          _goal(metric: GoalMetric.sesiLatihan, target: 100), // perlu dikejar
          _goal(metric: GoalMetric.batasPengeluaran, target: 1000), // terlampaui
        ],
        data: GoalData(
          runs: [_lari(DateTime(2026, 8, 2), 5)],
          transactions: [_tx(DateTime(2026, 8, 2), 90000, TxKind.pengeluaran)],
        ),
        now: _now,
      );

      expect(hasil.map((p) => p.status), [
        GoalStatus.terlampaui,
        GoalStatus.perluKejar,
        GoalStatus.tercapai,
      ]);
    });
  });

  group('Goal.fromMap', () {
    test('metrik yang tidak dikenal menghasilkan null, bukan lemparan', () {
      final hasil = Goal.fromMap({
        'id': 'g',
        'title': 'T',
        'metric': 'metrik_masa_depan',
        'target_value': 10,
        'period': 'bulanan',
      });
      expect(hasil, isNull);
    });

    test('periode yang tidak dikenal jatuh ke bulanan', () {
      final hasil = Goal.fromMap({
        'id': 'g',
        'title': 'T',
        'metric': 'jarakLari',
        'target_value': 10,
        'period': 'entah',
      });
      expect(hasil!.period, GoalPeriod.bulanan);
    });
  });
}
