/// Batas ketidakhadiran yang paling umum dipakai kampus di Indonesia.
///
/// Dipakai hanya sebagai nilai awal yang bisa kamu ubah per mata kuliah, bukan
/// sebagai kebenaran. Ada kampus yang memakai 20%, ada yang menghitungnya per
/// mata kuliah, dan ada yang tidak memakai persentase sama sekali.
const int kMaksAbsenPersenBawaan = 25;

enum StatusKehadiran {
  hadir('hadir', 'Hadir'),
  izin('izin', 'Izin'),
  sakit('sakit', 'Sakit'),
  alpa('alpa', 'Alpa');

  const StatusKehadiran(this.dbValue, this.label);

  final String dbValue;
  final String label;

  static StatusKehadiran fromDb(String value) => StatusKehadiran.values
      .firstWhere((e) => e.dbValue == value, orElse: () => StatusKehadiran.hadir);

  bool get masuk => this == StatusKehadiran.hadir;
}

/// Satu pertemuan yang dicatat.
class Attendance {
  const Attendance({
    required this.id,
    required this.userId,
    required this.courseId,
    required this.meetingDate,
    required this.status,
    this.scheduleId,
    this.note,
  });

  final String id;
  final String userId;
  final String courseId;
  final String? scheduleId;
  final DateTime meetingDate;
  final StatusKehadiran status;

  /// Alasan, materi yang terlewat, atau titipan teman. Ini yang membuat catatan
  /// kehadiran masih berguna berbulan-bulan kemudian, bukan cuma jadi angka.
  final String? note;

  factory Attendance.fromMap(Map<String, dynamic> map) => Attendance(
        id: map['id'] as String,
        userId: map['user_id'] as String,
        courseId: map['course_id'] as String,
        scheduleId: map['schedule_id'] as String?,
        meetingDate: DateTime.parse(map['meeting_date'] as String),
        status: StatusKehadiran.fromDb(map['status'] as String),
        note: map['note'] as String?,
      );
}

enum StatusJatah {
  /// Jatahnya belum bisa dihitung karena jumlah pertemuan belum diisi.
  belumDiketahui,
  aman,

  /// Sisa jatahnya tinggal satu pertemuan atau kurang.
  hampir,
  lewat,
}

/// Rekap kehadiran satu mata kuliah.
class RekapKehadiran {
  const RekapKehadiran({
    required this.courseId,
    required this.hadir,
    required this.izin,
    required this.sakit,
    required this.alpa,
    this.totalPertemuan,
    this.maksAbsenPersen,
  });

  final String courseId;
  final int hadir;
  final int izin;
  final int sakit;
  final int alpa;

  /// Jumlah pertemuan satu semester. Null berarti belum diisi — dan kalau
  /// begitu, jatah tidak masuk memang tidak dihitung, bukan ditebak 14 atau 16.
  /// Angka jatah yang salah lebih berbahaya daripada tidak ada angka.
  final int? totalPertemuan;

  final int? maksAbsenPersen;

  /// Pertemuan yang sudah kamu catat, apa pun statusnya.
  int get tercatat => hadir + izin + sakit + alpa;

  /// Semua yang bukan hadir.
  ///
  /// Izin dan sakit ikut dihitung di sini. Sebagian kampus tidak
  /// menghitungnya kalau ada surat, jadi angka ini lebih ketat daripada aturan
  /// di tempat seperti itu — dan lebih ketat adalah arah yang benar untuk
  /// salah. Rinciannya tetap dipisah supaya kamu bisa menilai sendiri.
  int get tidakHadir => izin + sakit + alpa;

  /// Persentase kehadiran dari pertemuan yang tercatat. Null kalau belum ada
  /// satu pun catatan — bukan 0%, karena belum mencatat bukan berarti bolos.
  double? get persenKehadiran => tercatat == 0 ? null : hadir * 100 / tercatat;

  /// Pertemuan yang belum dicatat sama sekali.
  int? get belumTercatat {
    final total = totalPertemuan;
    if (total == null) return null;
    final sisa = total - tercatat;
    return sisa < 0 ? 0 : sisa;
  }

  /// Berapa kali kamu boleh tidak masuk sepanjang semester.
  int? get jatahTidakHadir {
    final total = totalPertemuan;
    if (total == null) return null;
    return total * (maksAbsenPersen ?? kMaksAbsenPersenBawaan) ~/ 100;
  }

  /// Sisa jatah. Bisa negatif, dan negatifnya memang ditampilkan apa adanya.
  int? get sisaJatah {
    final jatah = jatahTidakHadir;
    if (jatah == null) return null;
    return jatah - tidakHadir;
  }

  StatusJatah get statusJatah {
    final sisa = sisaJatah;
    if (sisa == null) return StatusJatah.belumDiketahui;
    if (sisa < 0) return StatusJatah.lewat;
    if (sisa <= 1) return StatusJatah.hampir;
    return StatusJatah.aman;
  }
}

/// Kumpulkan catatan kehadiran jadi rekap per mata kuliah.
///
/// [totalPertemuan] dan [maksAbsenPersen] datang dari mata kuliahnya, dan
/// keduanya boleh kosong. Mata kuliah yang belum punya satu pun catatan tetap
/// muncul dengan angka nol, supaya tidak hilang dari daftar hanya karena belum
/// pernah disentuh.
List<RekapKehadiran> rekapKehadiran({
  required List<Attendance> catatan,
  required List<String> courseIds,
  Map<String, int?> totalPertemuan = const {},
  Map<String, int?> maksAbsenPersen = const {},
}) {
  final hadir = <String, int>{};
  final izin = <String, int>{};
  final sakit = <String, int>{};
  final alpa = <String, int>{};

  for (final item in catatan) {
    final ember = switch (item.status) {
      StatusKehadiran.hadir => hadir,
      StatusKehadiran.izin => izin,
      StatusKehadiran.sakit => sakit,
      StatusKehadiran.alpa => alpa,
    };
    ember[item.courseId] = (ember[item.courseId] ?? 0) + 1;
  }

  return [
    for (final id in courseIds)
      RekapKehadiran(
        courseId: id,
        hadir: hadir[id] ?? 0,
        izin: izin[id] ?? 0,
        sakit: sakit[id] ?? 0,
        alpa: alpa[id] ?? 0,
        totalPertemuan: totalPertemuan[id],
        maksAbsenPersen: maksAbsenPersen[id],
      ),
  ];
}

/// Urutkan dari yang paling perlu diperhatikan.
///
/// Yang jatahnya sudah lewat lebih dulu, lalu yang hampir habis, lalu sisanya.
/// Mata kuliah yang jatahnya belum bisa dihitung ditaruh paling belakang —
/// bukan karena tidak penting, tapi karena tidak ada yang bisa dikatakan
/// tentangnya sampai jumlah pertemuannya diisi.
int _urutanStatus(StatusJatah status) => switch (status) {
      StatusJatah.lewat => 0,
      StatusJatah.hampir => 1,
      StatusJatah.aman => 2,
      StatusJatah.belumDiketahui => 3,
    };

List<RekapKehadiran> urutkanRekap(
  List<RekapKehadiran> rekap,
  String Function(String courseId) namaMataKuliah,
) {
  final hasil = [...rekap];
  hasil.sort((a, b) {
    final urutan = _urutanStatus(a.statusJatah).compareTo(_urutanStatus(b.statusJatah));
    if (urutan != 0) return urutan;

    // Dalam status yang sama, yang sisanya paling sedikit lebih dulu.
    final sisaA = a.sisaJatah;
    final sisaB = b.sisaJatah;
    if (sisaA != null && sisaB != null && sisaA != sisaB) return sisaA.compareTo(sisaB);

    return namaMataKuliah(a.courseId).compareTo(namaMataKuliah(b.courseId));
  });
  return hasil;
}
