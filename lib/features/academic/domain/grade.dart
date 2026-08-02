/// Nilai per mata kuliah, IPS, dan IPK.
///
/// Dua hal yang sengaja tidak dilakukan di sini:
///
/// 1. **Komponen yang belum dinilai tidak dianggap nol.** Nilai akhir dihitung
///    dari bobot yang sudah terisi saja, lalu ditandai sebagai sementara. Kalau
///    komponen kosong dihitung nol, mahasiswa yang baru selesai UTS akan
///    melihat nilai E untuk semua mata kuliahnya — angka yang bukan cuma
///    menakutkan, tapi salah.
///
/// 2. **Skala nilai tidak ditebak.** Ambang huruf berbeda-beda antar kampus,
///    jadi skalanya dipilih sendiri dan angkanya ditampilkan apa adanya.
library;

/// Skala huruf yang dipakai kampus.
enum GradeScale {
  plusMinus('A / A- / B+ / B'),
  setengah('A / AB / B / BC');

  const GradeScale(this.label);
  final String label;

  static GradeScale fromName(String? value) => GradeScale.values.firstWhere(
        (s) => s.name == value,
        orElse: () => GradeScale.plusMinus,
      );
}

/// Satu tingkat huruf: hurufnya, bobot IP-nya, dan skor minimal untuk meraihnya.
class GradeStep {
  const GradeStep(this.huruf, this.bobot, this.minSkor);

  final String huruf;
  final double bobot;
  final double minSkor;
}

/// Ambang di bawah ini adalah yang paling umum dipakai, **bukan aturan resmi
/// yang berlaku di semua kampus**. Kalau kampusmu berbeda, angka skornya tetap
/// benar — yang bergeser cuma hurufnya.
const List<GradeStep> _plusMinus = [
  GradeStep('A', 4.00, 85),
  GradeStep('A-', 3.70, 80),
  GradeStep('B+', 3.30, 75),
  GradeStep('B', 3.00, 70),
  GradeStep('B-', 2.70, 65),
  GradeStep('C+', 2.30, 60),
  GradeStep('C', 2.00, 55),
  GradeStep('D', 1.00, 45),
  GradeStep('E', 0.00, 0),
];

const List<GradeStep> _setengah = [
  GradeStep('A', 4.00, 80),
  GradeStep('AB', 3.50, 75),
  GradeStep('B', 3.00, 70),
  GradeStep('BC', 2.50, 65),
  GradeStep('C', 2.00, 60),
  GradeStep('D', 1.00, 45),
  GradeStep('E', 0.00, 0),
];

List<GradeStep> stepsFor(GradeScale scale) =>
    scale == GradeScale.plusMinus ? _plusMinus : _setengah;

/// Semua huruf yang dikenal, dari kedua skala.
List<String> get semuaHuruf => {
      for (final step in _plusMinus) step.huruf,
      for (final step in _setengah) step.huruf,
    }.toList();

/// Huruf untuk sebuah skor 0–100.
GradeStep letterFor(double skor, GradeScale scale) {
  for (final step in stepsFor(scale)) {
    if (skor >= step.minSkor) return step;
  }
  return stepsFor(scale).last;
}

/// Tingkat untuk sebuah huruf, mis. "A-" dari KHS.
///
/// Skala yang dipilih dicari lebih dulu, lalu skala satunya. "AB" hanya ada di
/// satu skala dan "A-" hanya di satu lagi, jadi huruf dari KHS tetap terbaca
/// bobotnya meski skala yang dipilih kebetulan bukan yang dipakai kampusmu —
/// menolaknya cuma akan membuang nilai yang sebenarnya sudah jelas.
GradeStep? stepForLetter(String huruf, GradeScale scale) {
  final cari = huruf.trim().toUpperCase();
  if (cari.isEmpty) return null;

  for (final daftar in [stepsFor(scale), _plusMinus, _setengah]) {
    for (final step in daftar) {
      if (step.huruf == cari) return step;
    }
  }
  return null;
}

/// Satu komponen penilaian: Tugas 20%, UTS 30%, UAS 50%.
class GradeComponent {
  const GradeComponent({
    required this.id,
    required this.courseId,
    required this.name,
    required this.weight,
    this.score,
  });

  final String id;
  final String courseId;
  final String name;

  /// Persentase terhadap nilai akhir.
  final double weight;

  /// Null berarti belum keluar nilainya — bukan nol.
  final double? score;

  bool get dinilai => score != null;

  factory GradeComponent.fromMap(Map<String, dynamic> map) => GradeComponent(
        id: map['id'] as String,
        courseId: map['course_id'] as String,
        name: map['name'] as String,
        weight: (map['weight'] as num).toDouble(),
        score: (map['score'] as num?)?.toDouble(),
      );
}

/// Selisih bobot yang masih dianggap "seratus persen".
///
/// Bobot sering diketik sebagai 33,3 tiga kali dan berjumlah 99,9 — itu bukan
/// kesalahan yang perlu diperingatkan.
const double kToleransiBobot = 0.5;

/// Nilai satu mata kuliah.
class CourseGrade {
  const CourseGrade({
    required this.courseId,
    required this.courseName,
    required this.sks,
    required this.semester,
    required this.components,
    this.finalLetter,
  });

  final String courseId;
  final String courseName;

  /// Huruf resmi dari KHS. Kalau terisi, dia menang atas hitungan komponen:
  /// hasil resmi mengalahkan perkiraanmu sendiri.
  final String? finalLetter;

  /// Null kalau belum diisi. Tanpa sks, mata kuliah ini tidak bisa ikut
  /// menghitung IP — dan itu dilaporkan, bukan diam-diam dianggap nol.
  final int? sks;

  final String? semester;
  final List<GradeComponent> components;

  double get totalBobot =>
      components.fold(0.0, (jumlah, komponen) => jumlah + komponen.weight);

  double get bobotTerisi => components
      .where((k) => k.dinilai)
      .fold(0.0, (jumlah, komponen) => jumlah + komponen.weight);

  /// Bobot komponennya tidak berjumlah 100 — biasanya salah ketik.
  bool get bobotJanggal =>
      components.isNotEmpty && (totalBobot - 100).abs() > kToleransiBobot;

  /// Berapa bagian penilaian yang sudah keluar, 0–1.
  double get porsiTerisi => totalBobot <= 0 ? 0 : bobotTerisi / totalBobot;

  /// Nilai akhirnya sudah pasti — entah dari KHS, entah semua komponen keluar.
  bool get lengkap =>
      resmi ||
      (components.isNotEmpty && bobotTerisi >= totalBobot - kToleransiBobot);

  /// Nilainya datang dari KHS, bukan dihitung dari komponen.
  bool get resmi => (finalLetter?.trim().isNotEmpty ?? false);

  /// Skor 0–100 dari komponen yang sudah dinilai saja.
  ///
  /// Selama [lengkap] masih false ini nilai sementara: dia menjawab "kalau
  /// sisanya sebaik yang sudah berjalan", bukan "inilah nilai akhirmu".
  double? get skor {
    if (bobotTerisi <= 0) return null;
    var total = 0.0;
    for (final komponen in components) {
      final nilai = komponen.score;
      if (nilai != null) total += nilai * komponen.weight;
    }
    return total / bobotTerisi;
  }

  GradeStep? huruf(GradeScale scale) {
    // KHS lebih dulu: kalau hasil resminya sudah keluar, hitungan komponen
    // cuma perkiraan yang sudah tidak relevan.
    if (resmi) {
      final resmiStep = stepForLetter(finalLetter!, scale);
      if (resmiStep != null) return resmiStep;
    }
    final nilai = skor;
    return nilai == null ? null : letterFor(nilai, scale);
  }

  /// Ikut menghitung IP hanya kalau sks-nya diisi dan sudah ada nilainya.
  bool bisaDihitung(GradeScale scale) => (sks ?? 0) > 0 && huruf(scale) != null;
}

/// Ringkasan satu semester (atau seluruh riwayat, untuk IPK).
class GradeSummary {
  const GradeSummary({
    required this.ip,
    required this.sksDinilai,
    required this.sksTotal,
    required this.matkulDinilai,
    required this.matkulTotal,
  });

  /// Null kalau belum ada satu pun mata kuliah yang bisa dihitung.
  final double? ip;

  /// SKS yang ikut menghitung [ip].
  final int sksDinilai;

  /// Seluruh sks yang tercatat, termasuk yang belum ada nilainya.
  final int sksTotal;

  final int matkulDinilai;
  final int matkulTotal;

  /// Ada mata kuliah yang tidak ikut dihitung — angkanya belum menceritakan
  /// semuanya, dan itu perlu terlihat.
  bool get sebagian => matkulDinilai < matkulTotal;

  bool get kosong => matkulTotal == 0;
}

/// IP tertimbang sks. Mata kuliah tanpa sks atau tanpa nilai dilewati.
GradeSummary summarizeGrades(List<CourseGrade> courses, GradeScale scale) {
  var totalBobot = 0.0;
  var sksDinilai = 0;
  var sksTotal = 0;
  var matkulDinilai = 0;

  for (final course in courses) {
    sksTotal += course.sks ?? 0;
    if (!course.bisaDihitung(scale)) continue;

    final sks = course.sks!;
    totalBobot += course.huruf(scale)!.bobot * sks;
    sksDinilai += sks;
    matkulDinilai++;
  }

  return GradeSummary(
    ip: sksDinilai == 0 ? null : totalBobot / sksDinilai,
    sksDinilai: sksDinilai,
    sksTotal: sksTotal,
    matkulDinilai: matkulDinilai,
    matkulTotal: courses.length,
  );
}

/// Nama semester yang dipakai untuk mata kuliah yang belum dikelompokkan.
const String kSemesterTanpaNama = 'Belum diberi semester';

/// Kelompokkan per semester, urut menurun supaya semester terbaru di atas.
///
/// Mata kuliah tanpa semester selalu ditaruh paling bawah: itu daftar yang
/// perlu dirapikan, bukan semester yang sedang berjalan.
Map<String, List<CourseGrade>> groupBySemester(List<CourseGrade> courses) {
  final grouped = <String, List<CourseGrade>>{};
  for (final course in courses) {
    final nama = (course.semester?.trim().isNotEmpty ?? false)
        ? course.semester!.trim()
        : kSemesterTanpaNama;
    grouped.putIfAbsent(nama, () => []).add(course);
  }

  final kunci = grouped.keys.toList()
    ..sort((a, b) {
      if (a == kSemesterTanpaNama) return 1;
      if (b == kSemesterTanpaNama) return -1;
      return b.compareTo(a);
    });

  return {for (final nama in kunci) nama: grouped[nama]!};
}
