import '../../academic/data/models/task.dart';
import '../../run/data/run_repository.dart';
import '../../workout/data/models/workout_session.dart';

/// Jumlah minggu minimum di TIAP kelompok pembanding sebelum sebuah pola boleh
/// ditampilkan.
///
/// Dengan dua atau tiga minggu, satu minggu sial sudah cukup membalik
/// kesimpulannya. Menampilkan "pola" dari sampel sekecil itu bukan wawasan,
/// melainkan derau yang kebetulan berbentuk kalimat meyakinkan.
const int kMinWeeksPerGroup = 3;

/// Selisih minimum sebelum perbedaan dianggap layak disebut, dalam satuan
/// masing-masing pola.
const double kMinDayGap = 0.5;
const double kMinPercentGap = 10;

enum InsightKind { olahragaVsKetepatan, olahragaVsKecepatan, konsistensi }

class Insight {
  const Insight({
    required this.kind,
    required this.headline,
    required this.detail,
    required this.weeksHigh,
    required this.weeksLow,
  });

  final InsightKind kind;

  /// Kalimat utama, sudah berisi angkanya.
  final String headline;

  /// Penjelasan pembandingnya, supaya angkanya tidak menggantung.
  final String detail;

  final int weeksHigh;
  final int weeksLow;

  int get totalWeeks => weeksHigh + weeksLow;
}

/// Ringkasan satu minggu, bahan dasar semua perbandingan.
class WeekBucket {
  WeekBucket(this.start);

  /// Senin minggu tersebut.
  final DateTime start;

  int sesiOlahraga = 0;
  int tugasSelesai = 0;
  int tugasTepatWaktu = 0;

  /// Total selisih hari antara waktu selesai dan tenggat, untuk tugas yang
  /// selesai. Negatif berarti lebih awal.
  double totalSelisihHari = 0;

  double get persenTepatWaktu =>
      tugasSelesai == 0 ? 0 : tugasTepatWaktu / tugasSelesai * 100;

  /// Rata-rata berapa hari sebelum tenggat tugas diselesaikan. Positif berarti
  /// lebih awal, jadi makin besar makin baik.
  double get rataHariLebihAwal =>
      tugasSelesai == 0 ? 0 : -totalSelisihHari / tugasSelesai;
}

DateTime _mondayOf(DateTime date) {
  final day = DateTime(date.year, date.month, date.day);
  return day.subtract(Duration(days: day.weekday - 1));
}

/// Kelompokkan seluruh aktivitas per minggu.
Map<DateTime, WeekBucket> buildWeeks({
  required List<AcademicTask> tasks,
  required List<WorkoutSession> sessions,
  required List<RunLog> runs,
}) {
  final weeks = <DateTime, WeekBucket>{};

  WeekBucket bucketFor(DateTime date) =>
      weeks.putIfAbsent(_mondayOf(date), () => WeekBucket(_mondayOf(date)));

  // Satu hari dengan beberapa sesi tetap dihitung satu hari olahraga; yang
  // dibandingkan adalah seberapa sering kamu bergerak, bukan berapa kali
  // kamu menekan tombol simpan.
  final hariOlahraga = <DateTime>{
    for (final session in sessions)
      DateTime(
        session.sessionDate.year,
        session.sessionDate.month,
        session.sessionDate.day,
      ),
    for (final run in runs)
      DateTime(run.startedAt.year, run.startedAt.month, run.startedAt.day),
  };

  for (final hari in hariOlahraga) {
    bucketFor(hari).sesiOlahraga++;
  }

  for (final task in tasks) {
    final selesai = task.completedAt;
    if (selesai == null) continue;

    final bucket = bucketFor(selesai);
    bucket.tugasSelesai++;
    if (task.isOnTime) bucket.tugasTepatWaktu++;
    bucket.totalSelisihHari +=
        selesai.difference(task.deadline).inMinutes / (60 * 24);
  }

  return weeks;
}

double _mean(Iterable<double> values) {
  if (values.isEmpty) return 0;
  return values.reduce((a, b) => a + b) / values.length;
}

String _hari(double value) {
  final rounded = (value * 10).round() / 10;
  return rounded.toStringAsFixed(1).replaceAll('.', ',');
}

/// Cari pola antara kebiasaan olahraga dan penyelesaian tugas.
///
/// Ini perbandingan rata-rata dua kelompok minggu, bukan uji statistik. Yang
/// dihasilkan pola, bukan sebab-akibat — dan itu harus dinyatakan di UI, bukan
/// disembunyikan supaya kalimatnya terdengar lebih pintar.
List<Insight> findInsights({
  required List<AcademicTask> tasks,
  required List<WorkoutSession> sessions,
  required List<RunLog> runs,
  DateTime? now,
}) {
  final weeks = buildWeeks(tasks: tasks, sessions: sessions, runs: runs);
  if (weeks.isEmpty) return const [];

  // Minggu berjalan dibuang: datanya belum lengkap, dan minggu setengah jadi
  // akan selalu terlihat seperti minggu yang buruk.
  final mingguIni = _mondayOf(now ?? DateTime.now());
  final selesai = weeks.values.where((w) => w.start.isBefore(mingguIni)).toList();

  // Hanya minggu yang ada tugas selesainya yang bisa dibandingkan; minggu libur
  // tanpa tugas tidak mengatakan apa pun tentang ketepatan waktu.
  final adaTugas = selesai.where((w) => w.tugasSelesai > 0).toList();

  final aktif = adaTugas.where((w) => w.sesiOlahraga >= 3).toList();
  final santai = adaTugas.where((w) => w.sesiOlahraga < 3).toList();

  final insights = <Insight>[];

  if (aktif.length >= kMinWeeksPerGroup && santai.length >= kMinWeeksPerGroup) {
    final tepatAktif = _mean(aktif.map((w) => w.persenTepatWaktu));
    final tepatSantai = _mean(santai.map((w) => w.persenTepatWaktu));
    final selisihPersen = tepatAktif - tepatSantai;

    if (selisihPersen.abs() >= kMinPercentGap) {
      final lebih = selisihPersen > 0;
      insights.add(Insight(
        kind: InsightKind.olahragaVsKetepatan,
        headline: 'Minggu kamu olahraga minimal 3 hari, tugas tepat waktu '
            '${lebih ? 'naik' : 'turun'} ${selisihPersen.abs().round()} poin.',
        detail: '${tepatAktif.round()}% saat aktif, '
            '${tepatSantai.round()}% saat jarang olahraga.',
        weeksHigh: aktif.length,
        weeksLow: santai.length,
      ));
    }

    final awalAktif = _mean(aktif.map((w) => w.rataHariLebihAwal));
    final awalSantai = _mean(santai.map((w) => w.rataHariLebihAwal));
    final selisihHari = awalAktif - awalSantai;

    if (selisihHari.abs() >= kMinDayGap) {
      final lebihAwal = selisihHari > 0;
      insights.add(Insight(
        kind: InsightKind.olahragaVsKecepatan,
        headline: 'Minggu kamu olahraga minimal 3 hari, tugas selesai '
            '${_hari(selisihHari.abs())} hari lebih '
            '${lebihAwal ? 'awal' : 'mepet'}.',
        detail: lebihAwal
            ? 'Rata-rata ${_hari(awalAktif)} hari sebelum tenggat saat aktif, '
                '${_hari(awalSantai)} hari saat jarang olahraga.'
            : 'Rata-rata ${_hari(awalAktif)} hari sebelum tenggat saat aktif, '
                'padahal ${_hari(awalSantai)} hari saat jarang olahraga.',
        weeksHigh: aktif.length,
        weeksLow: santai.length,
      ));
    }
  }

  // Pola konsistensi tidak butuh dua kelompok, jadi ambangnya hanya jumlah
  // minggu yang tersedia.
  if (selesai.length >= kMinWeeksPerGroup * 2) {
    final mingguOlahraga = selesai.where((w) => w.sesiOlahraga > 0).length;
    final persen = mingguOlahraga / selesai.length * 100;

    insights.add(Insight(
      kind: InsightKind.konsistensi,
      headline: 'Kamu olahraga di ${persen.round()}% minggumu.',
      detail: '$mingguOlahraga dari ${selesai.length} minggu terakhir ada '
          'setidaknya satu hari olahraga.',
      weeksHigh: mingguOlahraga,
      weeksLow: selesai.length - mingguOlahraga,
    ));
  }

  return insights;
}

/// Berapa minggu lagi sampai pola pertama bisa dihitung. Null kalau sudah cukup.
///
/// Ditampilkan supaya halaman kosongnya menjelaskan "tunggu sekian minggu lagi"
/// alih-alih sekadar "belum ada data" tanpa ujung.
int? weeksUntilReady({
  required List<AcademicTask> tasks,
  required List<WorkoutSession> sessions,
  required List<RunLog> runs,
  DateTime? now,
}) {
  final weeks = buildWeeks(tasks: tasks, sessions: sessions, runs: runs);
  final mingguIni = _mondayOf(now ?? DateTime.now());
  final selesai = weeks.values
      .where((w) => w.start.isBefore(mingguIni) && w.tugasSelesai > 0)
      .length;

  final butuh = kMinWeeksPerGroup * 2;
  return selesai >= butuh ? null : butuh - selesai;
}
