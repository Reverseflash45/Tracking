const List<String> weekDayNames = [
  'Senin',
  'Selasa',
  'Rabu',
  'Kamis',
  "Jum'at",
  'Sabtu',
  'Minggu',
];

String weekDayName(int dayOfWeek) => weekDayNames[(dayOfWeek - 1).clamp(0, 6)];

class ClassSchedule {
  const ClassSchedule({
    required this.id,
    required this.userId,
    required this.courseId,
    required this.courseName,
    this.courseCode,
    this.classCode,
    this.lecturer,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    this.room,
    this.isPhl = false,
    this.specificDate,
  });

  final String id;
  final String userId;
  final String courseId;
  final String courseName;

  /// Kode mata kuliah, mis. "SIC204". Menempel di mata kuliahnya — tetap sama
  /// di kelas mana pun.
  final String? courseCode;

  /// Kode kelas, mis. "TI-B2". Menempel di jadwalnya, bukan di mata kuliahnya:
  /// satu mata kuliah bisa dibuka untuk beberapa kelas.
  final String? classCode;

  final String? lecturer;

  /// 1 = Senin ... 7 = Minggu (mengikuti DateTime.weekday)
  final int dayOfWeek;

  /// Format 'HH:mm:ss' dari kolom `time` Postgres.
  final String startTime;
  final String endTime;
  final String? room;
  final bool isPhl;
  final DateTime? specificDate;

  String get timeRangeLabel => '${startTime.substring(0, 5)} - ${endTime.substring(0, 5)}';

  factory ClassSchedule.fromMap(Map<String, dynamic> map) => ClassSchedule(
        id: map['id'] as String,
        userId: map['user_id'] as String,
        courseId: map['course_id'] as String,
        courseName: (map['courses'] as Map<String, dynamic>?)?['name'] as String? ?? '-',
        courseCode: (map['courses'] as Map<String, dynamic>?)?['code'] as String?,
        classCode: map['class_code'] as String?,
        lecturer: (map['courses'] as Map<String, dynamic>?)?['lecturer'] as String?,
        dayOfWeek: map['day_of_week'] as int,
        startTime: map['start_time'] as String,
        endTime: map['end_time'] as String,
        room: map['room'] as String?,
        isPhl: map['is_phl'] as bool? ?? false,
        specificDate: map['specific_date'] == null
            ? null
            : DateTime.parse(map['specific_date'] as String),
      );
}
