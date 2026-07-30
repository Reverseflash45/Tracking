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

class AcademicTask {
  const AcademicTask({
    required this.id,
    required this.userId,
    this.courseId,
    this.courseName,
    required this.title,
    this.description,
    required this.deadline,
    required this.priority,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String? courseId;
  final String? courseName;
  final String title;
  final String? description;
  final DateTime deadline;
  final TaskPriority priority;
  final TaskStatus status;
  final DateTime createdAt;

  bool get isDone => status == TaskStatus.done;

  factory AcademicTask.fromMap(Map<String, dynamic> map) => AcademicTask(
        id: map['id'] as String,
        userId: map['user_id'] as String,
        courseId: map['course_id'] as String?,
        courseName: (map['courses'] as Map<String, dynamic>?)?['name'] as String?,
        title: map['title'] as String,
        description: map['description'] as String?,
        deadline: DateTime.parse(map['deadline'] as String),
        priority: TaskPriority.fromDb(map['priority'] as String),
        status: TaskStatus.fromDb(map['status'] as String),
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}
