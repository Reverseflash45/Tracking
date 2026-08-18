import '../data/models/task.dart';

/// Tugas satu mata kuliah, beserta hitungan per status.
class ArsipMatkul {
  const ArsipMatkul({
    required this.courseId,
    required this.nama,
    required this.tugas,
  });

  /// Null berarti kumpulan tugas kuliah yang mata kuliahnya belum dipilih.
  final String? courseId;
  final String nama;

  /// Sudah terurut: yang belum selesai lebih dulu, deadline terdekat di atas.
  final List<AcademicTask> tugas;

  int get total => tugas.length;
  int get belum => tugas.where((t) => t.status == TaskStatus.todo).length;
  int get proses => tugas.where((t) => t.status == TaskStatus.inProgress).length;
  int get selesai => tugas.where((t) => t.isDone).length;
  int get belumSelesai => total - selesai;

  /// Null kalau belum ada tugasnya sama sekali. Bukan nol: "belum pernah
  /// mencatat tugas" dan "sudah mencatat tapi belum satu pun selesai" adalah
  /// dua keadaan yang berbeda, dan batang progres 0% menyamakan keduanya.
  double? get progres => total == 0 ? null : selesai / total;

  /// Urutan tampil. Yang masih menyisakan pekerjaan naik paling atas; mata
  /// kuliah yang belum punya tugas sama sekali di tengah, karena itu lebih
  /// sering berarti "lupa mencatat" daripada "memang tidak ada"; yang sudah
  /// tuntas turun ke bawah — tidak ada lagi yang perlu dilakukan di sana.
  int get tingkat => belumSelesai > 0 ? 0 : (total == 0 ? 1 : 2);
}

/// Mengelompokkan tugas kuliah per mata kuliah.
///
/// Tugas pribadi sengaja tidak ikut: dia memang tidak punya mata kuliah, dan
/// halaman ini menjawab satu pertanyaan saja — "mata kuliah ini tugasnya sudah
/// apa saja".
///
/// [matkulAktif] adalah mata kuliah yang tetap ditampilkan walau belum punya
/// satu tugas pun, dalam bentuk id ke nama. Tanpa itu, mata kuliah yang tugasnya
/// belum sempat dicatat menghilang dari daftar — dan menghilang terbaca sebagai
/// "tidak ada tugas", padahal yang benar adalah "belum pernah kamu tulis".
List<ArsipMatkul> arsipTugas(
  List<AcademicTask> semua, {
  Map<String, String> matkulAktif = const {},
}) {
  final perMatkul = <String?, List<AcademicTask>>{
    for (final entry in matkulAktif.entries) entry.key: <AcademicTask>[],
  };

  for (final task in semua) {
    if (task.kind != TaskKind.kuliah) continue;
    perMatkul.putIfAbsent(task.courseId, () => []).add(task);
  }

  final hasil = [
    for (final entry in perMatkul.entries)
      ArsipMatkul(
        courseId: entry.key,
        nama: _nama(entry.key, entry.value, matkulAktif),
        tugas: _urutkan(entry.value),
      ),
  ];

  hasil.sort((a, b) {
    if (a.tingkat != b.tingkat) return a.tingkat.compareTo(b.tingkat);
    return a.nama.toLowerCase().compareTo(b.nama.toLowerCase());
  });
  return hasil;
}

String _nama(String? courseId, List<AcademicTask> tugas, Map<String, String> matkulAktif) {
  if (courseId == null) return 'Tanpa mata kuliah';
  // Nama dari daftar mata kuliah menang atas nama yang menempel di tugas:
  // yang pertama selalu yang terbaru kalau mata kuliahnya baru diganti nama.
  return matkulAktif[courseId] ?? tugas.firstOrNull?.courseName ?? 'Tanpa mata kuliah';
}

List<AcademicTask> _urutkan(List<AcademicTask> tugas) {
  // Yang belum selesai diurut deadline terdekat lebih dulu — itu urutan
  // mengerjakan. Yang sudah selesai dibalik: yang paling baru di atas, karena
  // yang dicari dari tugas selesai biasanya yang barusan, bukan yang paling
  // lama.
  final belum = [
    for (final t in tugas)
      if (!t.isDone) t,
  ]..sort((a, b) => a.deadline.compareTo(b.deadline));
  final selesai = [
    for (final t in tugas)
      if (t.isDone) t,
  ]..sort((a, b) => b.deadline.compareTo(a.deadline));
  return [...belum, ...selesai];
}
