class Course {
  const Course({
    required this.id,
    required this.userId,
    required this.name,
    this.lecturer,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String name;
  final String? lecturer;
  final DateTime createdAt;

  factory Course.fromMap(Map<String, dynamic> map) => Course(
        id: map['id'] as String,
        userId: map['user_id'] as String,
        name: map['name'] as String,
        lecturer: map['lecturer'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}
