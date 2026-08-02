/// Target lintas domain, dan cara mengukurnya dari data yang sudah ada.
///
/// Tidak ada satu pun angka kemajuan yang disimpan: semuanya dihitung ulang
/// dari catatan lari, sesi latihan, tugas, tidur, dan transaksi. Menyimpan
/// progres berarti punya dua sumber kebenaran yang bisa berselisih — dan yang
/// salah selalu yang tersimpan.
library;

import 'package:flutter/material.dart';

import '../../academic/data/models/task.dart';
import '../../finance/domain/transaction.dart';
import '../../run/data/run_repository.dart';
import '../../sleep/data/sleep_repository.dart';
import '../../sleep/domain/sleep_stats.dart';
import '../../workout/data/models/workout_session.dart';

/// Arah target: lebih banyak lebih baik, atau lebih sedikit lebih baik.
///
/// Melekat pada metriknya, bukan dipilih user. "Lari maksimal 50 km" bukan
/// target yang masuk akal, dan menawarkannya cuma bikin salah pilih.
enum GoalDirection { minimal, maksimal }

enum GoalMetric {
  jarakLari('Jarak lari', 'km', GoalDirection.minimal, Icons.directions_run),
  hariBergerak('Hari bergerak', 'hari', GoalDirection.minimal, Icons.local_fire_department),
  sesiLatihan('Sesi latihan', 'sesi', GoalDirection.minimal, Icons.fitness_center),
  tugasSelesai('Tugas selesai', 'tugas', GoalDirection.minimal, Icons.task_alt),
  tugasTepatWaktu('Tugas tepat waktu', 'tugas', GoalDirection.minimal, Icons.schedule),
  malamTidurCukup('Malam tidur cukup', 'malam', GoalDirection.minimal, Icons.bedtime),
  uangTersisa('Uang tersisa', 'Rp', GoalDirection.minimal, Icons.savings),
  batasPengeluaran('Batas pengeluaran', 'Rp', GoalDirection.maksimal, Icons.payments_outlined);

  const GoalMetric(this.label, this.satuan, this.arah, this.icon);

  final String label;
  final String satuan;
  final GoalDirection arah;
  final IconData icon;

  bool get isRupiah => satuan == 'Rp';

  static GoalMetric? fromDb(String value) {
    for (final metric in GoalMetric.values) {
      if (metric.name == value) return metric;
    }
    // Nama yang tidak dikenal (mis. dari versi app yang lebih baru) diabaikan
    // diam-diam daripada membuat seluruh daftar target gagal dimuat.
    return null;
  }
}

enum GoalPeriod {
  mingguan('Tiap minggu'),
  bulanan('Tiap bulan'),
  sekali('Sekali jalan');

  const GoalPeriod(this.label);
  final String label;

  static GoalPeriod fromDb(String value) => GoalPeriod.values.firstWhere(
        (p) => p.name == value,
        orElse: () => GoalPeriod.bulanan,
      );
}

class Goal {
  const Goal({
    required this.id,
    required this.title,
    required this.metric,
    required this.targetValue,
    required this.period,
    this.startDate,
    this.endDate,
    this.archived = false,
  });

  final String id;
  final String title;
  final GoalMetric metric;
  final double targetValue;
  final GoalPeriod period;

  /// Hanya dipakai [GoalPeriod.sekali].
  final DateTime? startDate;
  final DateTime? endDate;

  final bool archived;

  /// Null kalau metriknya tidak dikenal — baris seperti itu dilewati, bukan
  /// membuat seluruh daftar gagal dimuat.
  static Goal? fromMap(Map<String, dynamic> map) {
    final metric = GoalMetric.fromDb(map['metric'] as String);
    if (metric == null) return null;

    return Goal(
      id: map['id'] as String,
      title: map['title'] as String,
      metric: metric,
      targetValue: (map['target_value'] as num).toDouble(),
      period: GoalPeriod.fromDb(map['period'] as String),
      startDate:
          map['start_date'] == null ? null : DateTime.parse(map['start_date'] as String),
      endDate: map['end_date'] == null ? null : DateTime.parse(map['end_date'] as String),
      archived: map['archived'] as bool? ?? false,
    );
  }
}

/// Rentang tanggal yang sedang diukur. [selesai] inklusif.
class GoalWindow {
  const GoalWindow(this.mulai, this.selesai);

  final DateTime mulai;
  final DateTime selesai;

  int get totalHari => selesai.difference(mulai).inDays + 1;

  bool memuat(DateTime date) {
    final hari = DateTime(date.year, date.month, date.day);
    return !hari.isBefore(mulai) && !hari.isAfter(selesai);
  }
}

DateTime _hari(DateTime date) => DateTime(date.year, date.month, date.day);

/// Jendela pengukuran target pada saat [now].
///
/// Target mingguan dan bulanan ikut berpindah sendiri: "lari 20 km tiap bulan"
/// di bulan September mengukur September, bukan bulan waktu target itu dibuat.
GoalWindow windowFor(Goal goal, DateTime now) {
  final hariIni = _hari(now);

  switch (goal.period) {
    case GoalPeriod.mingguan:
      final mulai = hariIni.subtract(Duration(days: hariIni.weekday - 1));
      return GoalWindow(mulai, mulai.add(const Duration(days: 6)));

    case GoalPeriod.bulanan:
      final mulai = DateTime(hariIni.year, hariIni.month, 1);
      // Hari 0 bulan berikutnya = hari terakhir bulan ini, tanpa perlu tahu
      // bulan mana yang 30 atau 31 hari, dan tanpa salah di Februari kabisat.
      return GoalWindow(mulai, DateTime(hariIni.year, hariIni.month + 1, 0));

    case GoalPeriod.sekali:
      final mulai = _hari(goal.startDate ?? hariIni);
      final selesai = _hari(goal.endDate ?? hariIni);
      return GoalWindow(mulai, selesai.isBefore(mulai) ? mulai : selesai);
  }
}

enum GoalStatus {
  /// Sudah sampai target (untuk arah minimal), atau jendelanya berakhir dan
  /// masih di dalam batas (untuk arah maksimal).
  tercapai('Tercapai'),

  /// Kemajuannya sepadan dengan waktu yang sudah terpakai.
  sesuaiJalur('Sesuai jalur'),

  /// Arah minimal, tertinggal dari laju yang dibutuhkan.
  perluKejar('Perlu dikejar'),

  /// Arah maksimal, batasnya sudah lewat.
  terlampaui('Terlampaui'),

  /// Jendelanya belum mulai (target sekali jalan yang tanggalnya di depan).
  belumMulai('Belum mulai');

  const GoalStatus(this.label);
  final String label;
}

class GoalProgress {
  const GoalProgress({
    required this.goal,
    required this.window,
    required this.nilai,
    required this.status,
    required this.sisaHari,
    required this.hariTerpakai,
  });

  final Goal goal;
  final GoalWindow window;

  /// Angka yang tercapai sejauh ini dalam jendela.
  final double nilai;

  final GoalStatus status;

  /// Sisa hari termasuk hari ini. 0 berarti jendelanya sudah lewat.
  final int sisaHari;

  /// Hari yang sudah terpakai, termasuk hari ini.
  final int hariTerpakai;

  /// 0–1, dipotong di 1 supaya bilah progres tidak meluber.
  double get persen =>
      goal.targetValue <= 0 ? 0 : (nilai / goal.targetValue).clamp(0.0, 1.0);

  /// Persen apa adanya, boleh lebih dari 100 — dipakai untuk angka, bukan bilah.
  double get persenMentah =>
      goal.targetValue <= 0 ? 0 : (nilai / goal.targetValue) * 100;

  double get sisa => (goal.targetValue - nilai).clamp(0.0, double.infinity);

  /// Berapa per hari yang dibutuhkan untuk sampai target.
  ///
  /// Null kalau sudah tercapai, kalau arahnya maksimal (tidak ada yang perlu
  /// dikejar), atau kalau waktunya sudah habis — angka yang tidak bisa lagi
  /// dipenuhi lebih baik tidak ditampilkan daripada ditampilkan sebagai
  /// tuntutan mustahil.
  double? get lajuDibutuhkan {
    if (goal.metric.arah != GoalDirection.minimal) return null;
    if (sisa <= 0 || sisaHari <= 0) return null;
    return sisa / sisaHari;
  }
}

/// Semua data yang bisa diukur jadi target.
class GoalData {
  const GoalData({
    this.runs = const [],
    this.sessions = const [],
    this.tasks = const [],
    this.sleeps = const [],
    this.transactions = const [],
  });

  final List<RunLog> runs;
  final List<WorkoutSession> sessions;
  final List<AcademicTask> tasks;
  final List<SleepLog> sleeps;
  final List<Transaction> transactions;
}

double _ukur(GoalMetric metric, GoalData data, GoalWindow window) {
  switch (metric) {
    case GoalMetric.jarakLari:
      var total = 0.0;
      for (final run in data.runs) {
        if (window.memuat(run.startedAt)) total += run.distanceMeters / 1000;
      }
      return total;

    case GoalMetric.hariBergerak:
      // Lari dan sesi angkat beban di hari yang sama tetap satu hari.
      final hari = <String>{};
      for (final run in data.runs) {
        if (window.memuat(run.startedAt)) hari.add(_kunciHari(run.startedAt));
      }
      for (final session in data.sessions) {
        if (window.memuat(session.sessionDate)) hari.add(_kunciHari(session.sessionDate));
      }
      return hari.length.toDouble();

    case GoalMetric.sesiLatihan:
      return data.sessions.where((s) => window.memuat(s.sessionDate)).length.toDouble();

    case GoalMetric.tugasSelesai:
      return data.tasks
          .where((t) => t.completedAt != null && window.memuat(t.completedAt!))
          .length
          .toDouble();

    case GoalMetric.tugasTepatWaktu:
      return data.tasks
          .where((t) => t.isOnTime && window.memuat(t.completedAt!))
          .length
          .toDouble();

    case GoalMetric.malamTidurCukup:
      return data.sleeps
          .where((s) => window.memuat(s.loggedOn) && tidurCukup(s.hours))
          .length
          .toDouble();

    case GoalMetric.uangTersisa:
      var masuk = 0.0;
      var keluar = 0.0;
      for (final tx in data.transactions) {
        if (!window.memuat(tx.occurredOn)) continue;
        if (tx.kind == TxKind.pemasukan) {
          masuk += tx.amount;
        } else {
          keluar += tx.amount;
        }
      }
      // Boleh negatif — kalau memang tekor, menampilkannya sebagai nol
      // menyembunyikan justru hal yang paling perlu dilihat.
      return masuk - keluar;

    case GoalMetric.batasPengeluaran:
      var total = 0.0;
      for (final tx in data.transactions) {
        if (tx.kind == TxKind.pengeluaran && window.memuat(tx.occurredOn)) {
          total += tx.amount;
        }
      }
      return total;
  }
}

String _kunciHari(DateTime date) => '${date.year}-${date.month}-${date.day}';

/// Toleransi laju sebelum sebuah target disebut tertinggal.
///
/// Tanpa ini target 30 hari akan berstatus "perlu dikejar" di hampir setiap
/// hari yang kamu lewatkan, dan peringatan yang menyala terus tidak lagi
/// berarti apa-apa.
const double kToleransiLaju = 0.85;

GoalStatus _status(Goal goal, double nilai, GoalWindow window, DateTime now) {
  final hariIni = _hari(now);
  if (hariIni.isBefore(window.mulai)) return GoalStatus.belumMulai;

  final selesai = hariIni.isAfter(window.selesai);
  final terpakai = selesai
      ? window.totalHari
      : hariIni.difference(window.mulai).inDays + 1;
  final porsiWaktu = window.totalHari <= 0 ? 1.0 : terpakai / window.totalHari;

  if (goal.metric.arah == GoalDirection.minimal) {
    if (nilai >= goal.targetValue) return GoalStatus.tercapai;
    final diharapkan = goal.targetValue * porsiWaktu * kToleransiLaju;
    return nilai >= diharapkan ? GoalStatus.sesuaiJalur : GoalStatus.perluKejar;
  }

  if (nilai > goal.targetValue) return GoalStatus.terlampaui;
  if (selesai) return GoalStatus.tercapai;

  // Habis lebih cepat daripada waktunya berjalan berarti tidak akan cukup —
  // walau angkanya hari ini masih di bawah batas.
  final jatah = goal.targetValue * porsiWaktu;
  return nilai <= jatah ? GoalStatus.sesuaiJalur : GoalStatus.perluKejar;
}

GoalProgress evaluateGoal({
  required Goal goal,
  required GoalData data,
  required DateTime now,
}) {
  final window = windowFor(goal, now);
  final nilai = _ukur(goal.metric, data, window);
  final hariIni = _hari(now);

  final sisaHari = hariIni.isAfter(window.selesai)
      ? 0
      : window.selesai.difference(hariIni.isBefore(window.mulai) ? window.mulai : hariIni).inDays + 1;

  final hariTerpakai = hariIni.isBefore(window.mulai)
      ? 0
      : (hariIni.isAfter(window.selesai)
          ? window.totalHari
          : hariIni.difference(window.mulai).inDays + 1);

  return GoalProgress(
    goal: goal,
    window: window,
    nilai: nilai,
    status: _status(goal, nilai, window, now),
    sisaHari: sisaHari,
    hariTerpakai: hariTerpakai,
  );
}

/// Target aktif diurutkan: yang paling perlu perhatian lebih dulu.
List<GoalProgress> evaluateGoals({
  required List<Goal> goals,
  required GoalData data,
  required DateTime now,
}) {
  final hasil = [
    for (final goal in goals)
      if (!goal.archived) evaluateGoal(goal: goal, data: data, now: now),
  ];

  const urutan = {
    GoalStatus.terlampaui: 0,
    GoalStatus.perluKejar: 1,
    GoalStatus.sesuaiJalur: 2,
    GoalStatus.belumMulai: 3,
    GoalStatus.tercapai: 4,
  };

  hasil.sort((a, b) {
    final selisih = urutan[a.status]!.compareTo(urutan[b.status]!);
    if (selisih != 0) return selisih;
    // Dalam status yang sama, yang tenggatnya paling dekat lebih dulu.
    return a.sisaHari.compareTo(b.sisaHari);
  });
  return hasil;
}
