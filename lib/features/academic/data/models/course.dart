class Course {
  const Course({
    required this.id,
    required this.userId,
    required this.name,
    this.code,
    this.lecturer,
    this.totalMeetings,
    this.maxAbsencePercent,
    this.sks,
    this.semester,
    this.finalLetter,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String name;

  /// Kode mata kuliah, mis. "SIC204". Diisi otomatis saat impor KRS.
  final String? code;

  final String? lecturer;

  /// Jumlah pertemuan satu semester. Null berarti belum diisi — dan tanpa ini
  /// jatah tidak masuk memang tidak dihitung, bukan ditebak 14 atau 16.
  final int? totalMeetings;

  /// Batas ketidakhadiran dalam persen. Null berarti memakai nilai bawaan.
  final int? maxAbsencePercent;

  /// Null berarti belum diisi. Tanpa ini mata kuliahnya tidak bisa ikut
  /// menghitung IP — dan itu dilaporkan, bukan dianggap nol diam-diam.
  final int? sks;

  /// Teks bebas, mis. "2026/2027 Ganjil". Penamaan semester berbeda-beda tiap
  /// kampus, jadi tidak ada format yang dipaksakan.
  final String? semester;

  /// Huruf mutu resmi dari KHS. Kalau terisi, dia menang atas hitungan
  /// komponen — hasil resmi mengalahkan perkiraan sendiri.
  final String? finalLetter;

  final DateTime createdAt;

  factory Course.fromMap(Map<String, dynamic> map) => Course(
        id: map['id'] as String,
        userId: map['user_id'] as String,
        name: map['name'] as String,
        code: map['code'] as String?,
        lecturer: map['lecturer'] as String?,
        totalMeetings: (map['total_meetings'] as num?)?.toInt(),
        maxAbsencePercent: (map['max_absence_percent'] as num?)?.toInt(),
        sks: (map['sks'] as num?)?.toInt(),
        semester: map['semester'] as String?,
        finalLetter: map['final_letter'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}
