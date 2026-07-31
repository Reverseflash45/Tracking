import '../../academic/data/models/task.dart';
import '../../workout/data/models/workout_session.dart';

enum WrappedPeriod {
  mingguan('Mingguan', 'minggu ini'),
  bulanan('Bulanan', 'bulan ini'),
  tahunan('Tahunan', 'tahun ini');

  const WrappedPeriod(this.label, this.phrase);

  final String label;

  /// Dipakai di kalimat, mis. "kamu menyelesaikan 12 tugas `minggu ini`".
  final String phrase;
}

/// Rentang periode, inklusif di kedua ujung pada level hari.
class WrappedRange {
  const WrappedRange(this.start, this.end);

  /// Awal hari pertama.
  final DateTime start;

  /// Akhir hari terakhir.
  final DateTime end;

  bool contains(DateTime moment) => !moment.isBefore(start) && !moment.isAfter(end);
}

WrappedRange rangeFor(WrappedPeriod period, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

  return switch (period) {
    // Minggu berjalan, Senin sampai hari ini.
    WrappedPeriod.mingguan =>
      WrappedRange(today.subtract(Duration(days: today.weekday - 1)), endOfToday),
    WrappedPeriod.bulanan => WrappedRange(DateTime(now.year, now.month), endOfToday),
    WrappedPeriod.tahunan => WrappedRange(DateTime(now.year), endOfToday),
  };
}

class Highlight {
  const Highlight(this.label, this.count);

  final String label;
  final int count;
}

class PersonalRecord {
  const PersonalRecord(this.exerciseName, this.weightKg);

  final String exerciseName;
  final double weightKg;
}

class WrappedStats {
  const WrappedStats({
    required this.period,
    required this.range,
    required this.tugasSelesai,
    required this.tugasTepatWaktu,
    required this.sesiWorkout,
    required this.totalVolume,
    required this.hariAktif,
    required this.matkulTersibuk,
    required this.latihanFavorit,
    required this.prBeban,
    required this.hariPalingProduktif,
    required this.persona,
  });

  final WrappedPeriod period;
  final WrappedRange range;
  final int tugasSelesai;
  final int tugasTepatWaktu;
  final int sesiWorkout;
  final double totalVolume;

  /// Jumlah hari unik yang ada aktivitasnya (tugas selesai atau workout).
  final int hariAktif;

  final Highlight? matkulTersibuk;
  final Highlight? latihanFavorit;
  final PersonalRecord? prBeban;

  /// 1 = Senin ... 7 = Minggu. Null kalau belum ada tugas yang selesai.
  final int? hariPalingProduktif;

  final String persona;

  bool get kosong => tugasSelesai == 0 && sesiWorkout == 0;

  /// Dibulatkan ke bilangan bulat; 0 kalau belum ada tugas yang selesai.
  int get persenTepatWaktu =>
      tugasSelesai == 0 ? 0 : ((tugasTepatWaktu / tugasSelesai) * 100).round();
}

WrappedStats computeWrappedStats({
  required WrappedPeriod period,
  required DateTime now,
  required List<AcademicTask> tasks,
  required List<WorkoutSession> sessions,
}) {
  final range = rangeFor(period, now);

  // --- Tugas ---
  final selesai = tasks
      .where((task) => task.completedAt != null && range.contains(task.completedAt!))
      .toList();

  final tepatWaktu = selesai.where((task) => task.isOnTime).length;

  final perMatkul = <String, int>{};
  final perHari = <int, int>{};
  for (final task in selesai) {
    final matkul = task.courseName;
    if (matkul != null && matkul.trim().isNotEmpty) {
      perMatkul[matkul] = (perMatkul[matkul] ?? 0) + 1;
    }
    final weekday = task.completedAt!.weekday;
    perHari[weekday] = (perHari[weekday] ?? 0) + 1;
  }

  // --- Workout ---
  final sesiPeriode =
      sessions.where((session) => range.contains(session.sessionDate)).toList();

  var totalVolume = 0.0;
  final perLatihan = <String, int>{};
  PersonalRecord? pr;
  for (final session in sesiPeriode) {
    for (final exercise in session.exercises) {
      if (!exercise.type.pakaiVolume) continue;
      totalVolume += exercise.volume;
      perLatihan[exercise.exerciseName] = (perLatihan[exercise.exerciseName] ?? 0) + 1;

      final berat = exercise.weightKg;
      if (berat != null && (pr == null || berat > pr.weightKg)) {
        pr = PersonalRecord(exercise.exerciseName, berat);
      }
    }
  }

  // --- Hari aktif ---
  final hariAktif = <DateTime>{
    for (final task in selesai)
      DateTime(task.completedAt!.year, task.completedAt!.month, task.completedAt!.day),
    for (final session in sesiPeriode)
      DateTime(session.sessionDate.year, session.sessionDate.month, session.sessionDate.day),
  };

  return WrappedStats(
    period: period,
    range: range,
    tugasSelesai: selesai.length,
    tugasTepatWaktu: tepatWaktu,
    sesiWorkout: sesiPeriode.length,
    totalVolume: totalVolume,
    hariAktif: hariAktif.length,
    matkulTersibuk: _topEntry(perMatkul),
    latihanFavorit: _topEntry(perLatihan),
    prBeban: pr,
    hariPalingProduktif: _topKey(perHari),
    persona: _persona(
      tugasSelesai: selesai.length,
      tepatWaktu: tepatWaktu,
      sesiWorkout: sesiPeriode.length,
    ),
  );
}

Highlight? _topEntry(Map<String, int> counts) {
  if (counts.isEmpty) return null;
  var best = counts.entries.first;
  for (final entry in counts.entries) {
    if (entry.value > best.value) best = entry;
  }
  return Highlight(best.key, best.value);
}

int? _topKey(Map<int, int> counts) {
  if (counts.isEmpty) return null;
  var best = counts.entries.first;
  for (final entry in counts.entries) {
    if (entry.value > best.value) best = entry;
  }
  return best.key;
}

/// Julukan berbasis aturan sederhana (bukan LLM), dipilih dari kombinasi
/// jumlah tugas, ketepatan waktu, dan sesi workout.
String _persona({
  required int tugasSelesai,
  required int tepatWaktu,
  required int sesiWorkout,
}) {
  if (tugasSelesai == 0 && sesiWorkout == 0) return 'Baru Mulai';

  final rajinTugas = tugasSelesai >= 5;
  final rajinGym = sesiWorkout >= 5;
  final disiplin = tugasSelesai > 0 && tepatWaktu == tugasSelesai;

  if (rajinTugas && rajinGym) return 'Si Seimbang';
  if (rajinGym) return 'Gym Rat';
  if (disiplin && rajinTugas) return 'Si Konsisten';
  if (rajinTugas) return 'Deadline Fighter';
  return 'Pemula Semangat';
}
