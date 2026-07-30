import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import 'models/class_schedule.dart';
import 'models/course.dart';
import 'models/task.dart';

class AcademicRepository {
  AcademicRepository(this._client);

  final SupabaseClient _client;

  Future<List<Course>> fetchCourses(String userId) async {
    final rows = await _client.from('courses').select().eq('user_id', userId).order('name');
    return (rows as List)
        .map((row) => Course.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<void> addCourse({required String userId, required String name, String? lecturer}) {
    return _client.from('courses').insert({
      'user_id': userId,
      'name': name,
      'lecturer': lecturer,
    });
  }

  Future<List<ClassSchedule>> fetchSchedules(String userId) async {
    final rows = await _client
        .from('class_schedules')
        .select('*, courses(name)')
        .eq('user_id', userId)
        .order('day_of_week')
        .order('start_time');
    return (rows as List)
        .map((row) => ClassSchedule.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<void> addSchedule({
    required String userId,
    required String courseId,
    required int dayOfWeek,
    required String startTime,
    required String endTime,
    String? room,
    bool isPhl = false,
    DateTime? specificDate,
  }) {
    return _client.from('class_schedules').insert({
      'user_id': userId,
      'course_id': courseId,
      'day_of_week': dayOfWeek,
      'start_time': startTime,
      'end_time': endTime,
      'room': room,
      'is_phl': isPhl,
      'specific_date': specificDate?.toIso8601String().substring(0, 10),
    });
  }

  Future<void> deleteSchedule(String id) {
    return _client.from('class_schedules').delete().eq('id', id);
  }

  Future<List<AcademicTask>> fetchTasks(String userId) async {
    final rows = await _client
        .from('tasks')
        .select('*, courses(name)')
        .eq('user_id', userId)
        .order('deadline');
    return (rows as List)
        .map((row) => AcademicTask.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<void> addTask({
    required String userId,
    String? courseId,
    required String title,
    String? description,
    required DateTime deadline,
    required TaskPriority priority,
  }) {
    return _client.from('tasks').insert({
      'user_id': userId,
      'course_id': courseId,
      'title': title,
      'description': description,
      'deadline': deadline.toIso8601String(),
      'priority': priority.dbValue,
      'status': TaskStatus.todo.dbValue,
    });
  }

  Future<void> updateTaskStatus(String id, TaskStatus status) {
    return _client.from('tasks').update({'status': status.dbValue}).eq('id', id);
  }

  Future<void> deleteTask(String id) {
    return _client.from('tasks').delete().eq('id', id);
  }
}

final academicRepositoryProvider = Provider<AcademicRepository>((ref) {
  return AcademicRepository(ref.watch(supabaseClientProvider));
});
