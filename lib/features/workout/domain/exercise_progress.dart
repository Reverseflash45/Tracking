import '../data/models/exercise_entry.dart';
import '../data/models/workout_session.dart';

/// Angka yang dilacak sebagai "progres" berbeda per tipe latihan: latihan beban
/// diukur dari kilogram, bodyweight dari jumlah rep, isometrik dari lama
/// tahanan, dan cardio dari durasi.
enum ProgressMetric {
  beban('Beban', 'kg'),
  rep('Rep', 'rep'),
  tahanan('Tahanan', 'detik'),
  durasi('Durasi', 'menit');

  const ProgressMetric(this.label, this.unit);

  final String label;
  final String unit;

  static ProgressMetric forType(ExerciseType type) => switch (type) {
        ExerciseType.beban => ProgressMetric.beban,
        ExerciseType.bodyweight => ProgressMetric.rep,
        ExerciseType.isometrik => ProgressMetric.tahanan,
        ExerciseType.cardio => ProgressMetric.durasi,
      };
}

class ProgressPoint {
  const ProgressPoint({
    required this.date,
    required this.value,
    required this.volume,
  });

  final DateTime date;

  /// Nilai metrik utama sesuai [ProgressMetric] latihannya.
  final double value;

  /// Beban x set x rep. Nol untuk latihan yang tidak memakai beban.
  final double volume;
}

/// Riwayat satu nama latihan, sudah diurutkan dari yang terlama.
class ExerciseProgress {
  const ExerciseProgress({
    required this.name,
    required this.type,
    required this.metric,
    required this.points,
    required this.hasVolume,
  });

  final String name;
  final ExerciseType type;
  final ProgressMetric metric;
  final List<ProgressPoint> points;

  /// True kalau ada minimal satu catatan dengan beban > 0, jadi grafik volume
  /// layak ditampilkan. Bodyweight tanpa beban tambahan tidak punya volume.
  final bool hasVolume;

  int get sessionCount => points.length;

  double get best => points.map((p) => p.value).reduce((a, b) => a > b ? a : b);

  double get bestVolume => points.map((p) => p.volume).reduce((a, b) => a > b ? a : b);

  double get latest => points.last.value;

  /// Selisih catatan terakhir dengan yang pertama. Nol kalau baru satu sesi.
  double get delta => points.length < 2 ? 0 : points.last.value - points.first.value;

  DateTime get lastDate => points.last.date;
}

/// Kumpulkan riwayat tiap nama latihan dari seluruh sesi.
///
/// Latihan hanya masuk kalau angka metriknya ada — mis. sesi bodyweight tanpa
/// rep tidak bisa digrafikkan, jadi dilewati. Nama latihan dianggap sama tanpa
/// memandang huruf besar/kecil, tapi ditampilkan memakai ejaan terbaru.
List<ExerciseProgress> buildExerciseProgress(List<WorkoutSession> sessions) {
  final urut = [...sessions]..sort((a, b) => a.sessionDate.compareTo(b.sessionDate));

  final points = <String, List<ProgressPoint>>{};
  final types = <String, ExerciseType>{};
  final labels = <String, String>{};
  final punyaBeban = <String, bool>{};

  for (final session in urut) {
    for (final exercise in session.exercises) {
      final value = _metricValue(exercise);
      if (value == null) continue;

      final key = exercise.exerciseName.trim().toLowerCase();
      if (key.isEmpty) continue;

      points.putIfAbsent(key, () => []).add(ProgressPoint(
            date: session.sessionDate,
            value: value,
            volume: exercise.volume,
          ));

      // Sesi terbaru menang: kalau tipenya pernah diubah, yang terakhir dipakai.
      types[key] = exercise.type;
      labels[key] = exercise.exerciseName.trim();
      punyaBeban[key] =
          (punyaBeban[key] ?? false) || ((exercise.weightKg ?? 0) > 0 && exercise.type.pakaiRep);
    }
  }

  final hasil = <ExerciseProgress>[];
  points.forEach((key, list) {
    final type = types[key]!;
    hasil.add(ExerciseProgress(
      name: labels[key]!,
      type: type,
      metric: ProgressMetric.forType(type),
      points: list,
      hasVolume: punyaBeban[key] ?? false,
    ));
  });

  // Latihan yang paling baru dicatat muncul lebih dulu.
  hasil.sort((a, b) => b.lastDate.compareTo(a.lastDate));
  return hasil;
}

double? _metricValue(ExerciseEntry entry) {
  return switch (entry.type) {
    ExerciseType.beban => entry.weightKg,
    ExerciseType.bodyweight => entry.reps?.toDouble(),
    ExerciseType.isometrik => entry.durationSeconds?.toDouble(),
    ExerciseType.cardio => entry.durationMinutes?.toDouble(),
  };
}
