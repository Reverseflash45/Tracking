enum TaskPriority {
  low('low', 'Rendah'),
  medium('medium', 'Sedang'),
  high('high', 'Tinggi');

  const TaskPriority(this.dbValue, this.label);
  final String dbValue;
  final String label;

  static TaskPriority fromDb(String value) =>
      TaskPriority.values.firstWhere((e) => e.dbValue == value, orElse: () => TaskPriority.medium);
}

enum TaskStatus {
  todo('todo', 'Belum'),
  inProgress('in_progress', 'Proses'),
  done('done', 'Selesai');

  const TaskStatus(this.dbValue, this.label);
  final String dbValue;
  final String label;

  static TaskStatus fromDb(String value) =>
      TaskStatus.values.firstWhere((e) => e.dbValue == value, orElse: () => TaskStatus.todo);
}

/// Tugas kuliah atau urusan pribadi.
///
/// Kolom sendiri, bukan disimpulkan dari mata kuliahnya kosong. Keduanya bukan
/// hal yang sama: tugas kuliah yang mata kuliahnya belum sempat dipilih juga
/// punya courseId kosong, dan kalau disimpulkan, dia akan diam-diam berpindah
/// ke daftar pribadi.
enum TaskKind {
  kuliah('kuliah', 'Kuliah'),
  pribadi('pribadi', 'Pribadi');

  const TaskKind(this.dbValue, this.label);

  final String dbValue;
  final String label;

  static TaskKind fromDb(String? value) =>
      TaskKind.values.firstWhere((e) => e.dbValue == value, orElse: () => TaskKind.kuliah);
}

class AcademicTask {
  const AcademicTask({
    required this.id,
    required this.userId,
    this.courseId,
    this.courseName,
    this.kind = TaskKind.kuliah,
    required this.title,
    this.description,
    required this.deadline,
    required this.priority,
    required this.status,
    required this.createdAt,
    this.completedAt,
    this.recurringId,
    this.recurringOn,
  });

  final String id;
  final String userId;
  final String? courseId;
  final String? courseName;
  final TaskKind kind;
  final String title;
  final String? description;
  final DateTime deadline;
  final TaskPriority priority;
  final TaskStatus status;
  final DateTime createdAt;
  final DateTime? completedAt;

  /// Template tugas berulang yang melahirkan tugas ini, kalau ada.
  final String? recurringId;

  /// Tanggal kejadian yang diwakili tugas ini. Bersama [recurringId] inilah
  /// yang membuat pembuatan otomatis aman diulang tanpa menghasilkan kembaran.
  final DateTime? recurringOn;

  bool get isDone => status == TaskStatus.done;

  bool get dariTemplate => recurringId != null;

  /// Selesai tepat waktu: statusnya done dan diselesaikan sebelum/sama dengan deadline.
  bool get isOnTime => isDone && completedAt != null && !completedAt!.isAfter(deadline);

  /// Salinan dengan status berbeda, untuk menampilkan perubahan yang sudah
  /// dikirim tapi belum dikonfirmasi server.
  ///
  /// `completedAt` ikut disesuaikan persis seperti yang ditulis repository,
  /// supaya bayangannya tidak berbeda dari hasil sebenarnya nanti.
  AcademicTask denganStatus(TaskStatus status) => AcademicTask(
        id: id,
        userId: userId,
        courseId: courseId,
        courseName: courseName,
        kind: kind,
        title: title,
        description: description,
        deadline: deadline,
        priority: priority,
        status: status,
        createdAt: createdAt,
        completedAt: status == TaskStatus.done ? (completedAt ?? DateTime.now()) : null,
        recurringId: recurringId,
        recurringOn: recurringOn,
      );

  factory AcademicTask.fromMap(Map<String, dynamic> map) => AcademicTask(
        id: map['id'] as String,
        userId: map['user_id'] as String,
        courseId: map['course_id'] as String?,
        courseName: (map['courses'] as Map<String, dynamic>?)?['name'] as String?,
        kind: TaskKind.fromDb(map['kind'] as String?),
        title: map['title'] as String,
        description: map['description'] as String?,
        deadline: DateTime.parse(map['deadline'] as String),
        priority: TaskPriority.fromDb(map['priority'] as String),
        status: TaskStatus.fromDb(map['status'] as String),
        createdAt: DateTime.parse(map['created_at'] as String),
        completedAt:
            map['completed_at'] == null ? null : DateTime.parse(map['completed_at'] as String),
        recurringId: map['recurring_id'] as String?,
        recurringOn: map['recurring_on'] == null
            ? null
            // Kolomnya bertipe date, jadi tidak ada zona waktu yang perlu
            // digeser — toLocal() di sini justru bisa memundurkannya sehari.
            : DateTime.parse(map['recurring_on'] as String),
      );
}
