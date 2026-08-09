import '../data/models/class_schedule.dart';
import '../data/models/course.dart';

/// Mata kuliah yang sedang dijalani, yaitu yang punya jadwal kelas.
///
/// Tabel `courses` menumpuk terus: mata kuliah semester 1 tidak pernah dihapus
/// karena nilainya masih dipakai menghitung IPK. Akibatnya daftar pilihan di
/// form tugas ikut memanjang oleh mata kuliah yang sudah lewat bertahun-tahun.
///
/// Penyaringnya jadwal kelas, bukan kolom `semester`: mata kuliah hasil impor
/// KRS tidak mengisi kolom itu, jadi menyaring lewatnya justru menghasilkan nol
/// untuk semester yang sedang berjalan. Jadwal cuma ada untuk semester yang
/// sedang diambil, dan itu bukti yang lebih bisa dipercaya.
///
/// Kalau belum ada satu jadwal pun, seluruh daftar dikembalikan apa adanya —
/// tidak ada dasar untuk menyaring, dan menyembunyikan semuanya cuma membuat
/// form tugas mustahil dipakai sebelum jadwal diisi.
///
/// [tetap] berisi id yang harus ikut walau jadwalnya sudah tidak ada. Dipakai
/// untuk hal yang terlanjur menunjuk mata kuliah lama: tugas semester lalu,
/// atau catatan kehadiran yang sudah masuk. Menyembunyikannya bukan cuma
/// merapikan daftar — datanya jadi tidak bisa dibuka lagi.
List<Course> matkulAktif(
  List<Course> semua,
  List<ClassSchedule> jadwal, {
  Set<String> tetap = const {},
}) {
  final aktif = {for (final item in jadwal) item.courseId};
  if (aktif.isEmpty) return semua;
  return [
    for (final course in semua)
      if (aktif.contains(course.id) || tetap.contains(course.id)) course,
  ];
}

/// Daftar pilihan untuk form, dengan [dipakai] tetap disertakan walau mata
/// kuliahnya sudah tidak aktif.
///
/// Tanpa ini, membuka tugas lama dari semester lalu akan menampilkan pilihan
/// yang tidak memuat mata kuliahnya sendiri — dan menyimpan ulang tugas itu
/// diam-diam melepas mata kuliahnya.
List<Course> pilihanMatkul(
  List<Course> semua,
  List<ClassSchedule> jadwal, {
  String? dipakai,
  bool semuanya = false,
}) {
  if (semuanya) return semua;
  return matkulAktif(semua, jadwal, tetap: {?dipakai});
}
