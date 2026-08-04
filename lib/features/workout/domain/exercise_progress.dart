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

/// Ukuran kedua di samping [ProgressMetric]: berapa banyak kerja dalam satu
/// sesi, bukan seberapa berat satu repetisinya.
///
/// Ini yang selama ini hilang. Metrik utama untuk bodyweight adalah jumlah rep
/// per set, jadi 3 set x 10 rep dan 5 set x 10 rep sama-sama tergambar sebagai
/// "10" — padahal yang kedua hampir dua kali lipat kerjanya. Setnya tercatat di
/// database sejak awal, cuma tidak pernah ikut dihitung maupun ditampilkan.
enum MetrikBeban {
  volume('Volume', 'kg'),
  totalRep('Total Rep', 'rep'),
  totalTahanan('Total Tahanan', 'detik');

  const MetrikBeban(this.label, this.unit);

  final String label;
  final String unit;

  /// Null untuk cardio: durasinya sudah jadi metrik utama, dan mengalikannya
  /// dengan set tidak berarti apa-apa.
  static MetrikBeban? forType(ExerciseType type) => switch (type) {
        ExerciseType.beban => MetrikBeban.volume,
        ExerciseType.bodyweight => MetrikBeban.totalRep,
        ExerciseType.isometrik => MetrikBeban.totalTahanan,
        ExerciseType.cardio => null,
      };
}

class ProgressPoint {
  const ProgressPoint({
    required this.date,
    required this.value,
    required this.volume,
    this.sets,
    this.reps,
    this.bebanKerja,
  });

  final DateTime date;

  /// Nilai metrik utama sesuai [ProgressMetric] latihannya.
  final double value;

  /// Beban x set x rep. Nol untuk latihan yang tidak memakai beban.
  final double volume;

  /// Jumlah set yang tercatat. Null kalau memang tidak diisi — tidak ditebak
  /// jadi 1, karena "satu set" dan "tidak dicatat" itu dua hal berbeda.
  final int? sets;

  /// Rep per set.
  final int? reps;

  /// Kerja total sesuai [MetrikBeban] latihannya. Null kalau angkanya belum
  /// lengkap untuk dihitung.
  final double? bebanKerja;

  /// "3 x 10" untuk ditampilkan di samping angka utama. Null kalau setnya tidak
  /// tercatat, supaya tidak ada kombinasi yang dikarang.
  String? get ringkasSetRep {
    final s = sets;
    final r = reps;
    if (s == null || r == null) return null;
    return '$s x $r';
  }
}

/// Riwayat satu nama latihan, sudah diurutkan dari yang terlama.
class ExerciseProgress {
  const ExerciseProgress({
    required this.name,
    required this.type,
    required this.metric,
    required this.points,
    required this.hasVolume,
    this.metrikBeban,
  });

  final String name;
  final ExerciseType type;
  final ProgressMetric metric;
  final List<ProgressPoint> points;

  /// True kalau ada minimal satu catatan dengan beban > 0, jadi grafik volume
  /// layak ditampilkan. Bodyweight tanpa beban tambahan tidak punya volume.
  final bool hasVolume;

  /// Ukuran kerja total yang cocok untuk tipe latihan ini. Null untuk cardio.
  final MetrikBeban? metrikBeban;

  int get sessionCount => points.length;

  double get best => points.map((p) => p.value).reduce((a, b) => a > b ? a : b);

  double get bestVolume => points.map((p) => p.volume).reduce((a, b) => a > b ? a : b);

  double get latest => points.last.value;

  /// Selisih catatan terakhir dengan yang pertama. Nol kalau baru satu sesi.
  double get delta => points.length < 2 ? 0 : points.last.value - points.first.value;

  DateTime get lastDate => points.last.date;

  /// Titik yang setnya lengkap, jadi kerja totalnya bisa dihitung. Catatan lama
  /// yang setnya kosong dilewati, bukan diisi nol — nol berarti "tidak latihan",
  /// dan itu bukan yang terjadi.
  List<ProgressPoint> get titikBeban =>
      [for (final p in points) if (p.bebanKerja != null) p];

  /// Grafik kerja total baru berarti kalau ada dua titik untuk dibandingkan.
  bool get punyaBeban => metrikBeban != null && titikBeban.length >= 2;

  /// Titik yang setnya tercatat.
  ///
  /// Set berhak atas grafiknya sendiri. Rep dan total saja tidak cukup: rep
  /// bisa turun sementara setnya naik, dan hasilnya total yang nyaris tidak
  /// bergerak — tiga angka yang bergerak sendiri-sendiri tidak bisa diwakili
  /// dua garis.
  List<ProgressPoint> get titikSet => [for (final p in points) if (p.sets != null) p];

  bool get punyaSet => titikSet.length >= 2;

  double get bebanTerbaik =>
      titikBeban.map((p) => p.bebanKerja!).reduce((a, b) => a > b ? a : b);

  double? get bebanTerakhir => titikBeban.isEmpty ? null : titikBeban.last.bebanKerja;
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
            sets: exercise.sets,
            reps: exercise.reps,
            bebanKerja: _bebanKerja(exercise),
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
      metrikBeban: MetrikBeban.forType(type),
    ));
  });

  // Latihan yang paling baru dicatat muncul lebih dulu.
  hasil.sort((a, b) => b.lastDate.compareTo(a.lastDate));
  return hasil;
}

/// Kerja total satu catatan, dihitung berbeda per tipe latihan.
///
/// Semuanya butuh [ExerciseEntry.sets]. Kalau setnya tidak diisi hasilnya null,
/// bukan nol dan bukan satu: catatan lama yang setnya kosong memang tidak tahu
/// berapa kali diulang, dan menebaknya akan membuat grafiknya berbohong.
double? _bebanKerja(ExerciseEntry entry) {
  final sets = entry.sets;
  if (sets == null || sets <= 0) return null;

  return switch (entry.type) {
    // Untuk beban, ini sama dengan volume yang sudah dipakai di tempat lain:
    // kilogram yang benar-benar diangkat sepanjang sesi.
    ExerciseType.beban => switch ((entry.weightKg, entry.reps)) {
        (final double w, final int r) when w > 0 && r > 0 => w * sets * r,
        _ => null,
      },
    ExerciseType.bodyweight => switch (entry.reps) {
        final int r when r > 0 => (sets * r).toDouble(),
        _ => null,
      },
    ExerciseType.isometrik => switch (entry.durationSeconds) {
        final int d when d > 0 => (sets * d).toDouble(),
        _ => null,
      },
    ExerciseType.cardio => null,
  };
}

double? _metricValue(ExerciseEntry entry) {
  return switch (entry.type) {
    ExerciseType.beban => entry.weightKg,
    ExerciseType.bodyweight => entry.reps?.toDouble(),
    ExerciseType.isometrik => entry.durationSeconds?.toDouble(),
    ExerciseType.cardio => entry.durationMinutes?.toDouble(),
  };
}
