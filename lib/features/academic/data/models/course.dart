class Course {
  const Course({
    required this.id,
    required this.userId,
    required this.name,
    this.lecturer,
    this.sks,
    this.semester,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String name;
  final String? lecturer;

  /// Null berarti belum diisi. Tanpa ini mata kuliahnya tidak bisa ikut
  /// menghitung IP — dan itu dilaporkan, bukan dianggap nol diam-diam.
  final int? sks;

  /// Teks bebas, mis. "2026/2027 Ganjil". Penamaan semester berbeda-beda tiap
  /// kampus, jadi tidak ada format yang dipaksakan.
  final String? semester;

  final DateTime createdAt;

  factory Course.fromMap(Map<String, dynamic> map) => Course(
        id: map['id'] as String,
        userId: map['user_id'] as String,
        name: map['name'] as String,
        lecturer: map['lecturer'] as String?,
        sks: (map['sks'] as num?)?.toInt(),
        semester: map['semester'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}
