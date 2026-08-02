import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/offline/local_cache.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../domain/grade.dart';
import '../domain/recurring_task.dart';
import 'models/class_schedule.dart';
import 'models/course.dart';
import 'models/task.dart';

class AcademicRepository {
  AcademicRepository(this._client, this._cache);

  final SupabaseClient _client;
  final LocalCache _cache;

  Future<List<Course>> fetchCourses(String userId) async {
    return fetchWithCache(
      cache: _cache,
      key: 'courses_$userId',
      remote: () async =>
          ((await _client.from('courses').select().eq('user_id', userId).order('name'))
                  as List)
              .cast<Map<String, dynamic>>(),
      parse: Course.fromMap,
    );
  }

  Future<void> addCourse({required String userId, required String name, String? lecturer}) {
    return _client.from('courses').insert({
      'user_id': userId,
      'name': name,
      'lecturer': lecturer,
    });
  }

  /// Cari mata kuliah bernama [name], buat kalau belum ada, lalu kembalikan
  /// id-nya.
  ///
  /// Dipakai import KRS. Tanpa pencocokan nama, mengimpor ulang KRS yang sama
  /// akan membuat "Basis Data" berkali-kali dan memecah jadwalnya ke beberapa
  /// mata kuliah kembar.
  Future<String> ensureCourse({
    required String userId,
    required String name,
    String? lecturer,
  }) async {
    final trimmed = name.trim();

    final existing = await _client
        .from('courses')
        .select('id')
        .eq('user_id', userId)
        .ilike('name', trimmed)
        .maybeSingle();

    if (existing != null) return existing['id'] as String;

    final created = await _client
        .from('courses')
        .insert({'user_id': userId, 'name': trimmed, 'lecturer': lecturer})
        .select('id')
        .single();

    return created['id'] as String;
  }

  Future<void> updateCourse({required String id, required String name, String? lecturer}) {
    return _client
        .from('courses')
        .update({'name': name, 'lecturer': lecturer})
        .eq('id', id);
  }

  /// Sks dan semester dipisah dari [updateCourse] karena diisi dari halaman
  /// Nilai, dan menumpangkannya ke update biasa akan menimpa nama/dosen dengan
  /// nilai lama yang kebetulan ada di halaman itu.
  Future<void> updateCourseAkademik({
    required String id,
    int? sks,
    String? semester,
  }) {
    return _client
        .from('courses')
        .update({'sks': sks, 'semester': semester})
        .eq('id', id);
  }

  Future<List<GradeComponent>> fetchGradeComponents(String userId) async {
    return fetchWithCache(
      cache: _cache,
      key: 'grade_components_$userId',
      remote: () async =>
          ((await _client
                      .from('grade_components')
                      .select()
                      .eq('user_id', userId)
                      .order('created_at'))
                  as List)
              .cast<Map<String, dynamic>>(),
      parse: GradeComponent.fromMap,
    );
  }

  Future<void> saveGradeComponent({
    required String userId,
    String? id,
    required String courseId,
    required String name,
    required double weight,
    required double? score,
  }) {
    final row = {
      'course_id': courseId,
      'name': name,
      'weight': weight,
      'score': score,
    };

    if (id != null) {
      return _client.from('grade_components').update(row).eq('id', id);
    }
    return _client.from('grade_components').insert({'user_id': userId, ...row});
  }

  Future<void> deleteGradeComponent(String id) {
    return _client.from('grade_components').delete().eq('id', id);
  }

  Future<List<ClassSchedule>> fetchSchedules(String userId) async {
    return fetchWithCache(
      cache: _cache,
      key: 'schedules_$userId',
      remote: () async =>
          ((await _client
                      .from('class_schedules')
                      .select('*, courses(name, lecturer)')
                      .eq('user_id', userId)
                      .order('day_of_week')
                      .order('start_time'))
                  as List)
              .cast<Map<String, dynamic>>(),
      parse: ClassSchedule.fromMap,
    );
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

  Future<void> updateSchedule({
    required String id,
    required String courseId,
    required int dayOfWeek,
    required String startTime,
    required String endTime,
    String? room,
    bool isPhl = false,
    DateTime? specificDate,
  }) {
    return _client
        .from('class_schedules')
        .update({
          'course_id': courseId,
          'day_of_week': dayOfWeek,
          'start_time': startTime,
          'end_time': endTime,
          'room': room,
          'is_phl': isPhl,
          'specific_date': specificDate?.toIso8601String().substring(0, 10),
        })
        .eq('id', id);
  }

  Future<void> deleteSchedule(String id) {
    return _client.from('class_schedules').delete().eq('id', id);
  }

  Future<List<AcademicTask>> fetchTasks(String userId) async {
    return fetchWithCache(
      cache: _cache,
      key: 'tasks_$userId',
      remote: () async =>
          ((await _client
                      .from('tasks')
                      .select('*, courses(name)')
                      .eq('user_id', userId)
                      .order('deadline'))
                  as List)
              .cast<Map<String, dynamic>>(),
      parse: AcademicTask.fromMap,
    );
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

  Future<void> updateTask({
    required String id,
    String? courseId,
    required String title,
    String? description,
    required DateTime deadline,
    required TaskPriority priority,
  }) {
    return _client
        .from('tasks')
        .update({
          'course_id': courseId,
          'title': title,
          'description': description,
          'deadline': deadline.toIso8601String(),
          'priority': priority.dbValue,
        })
        .eq('id', id);
  }

  Future<void> updateTaskStatus(String id, TaskStatus status) {
    return _client
        .from('tasks')
        .update({
          'status': status.dbValue,
          'completed_at': status == TaskStatus.done
              ? DateTime.now().toIso8601String()
              : null,
        })
        .eq('id', id);
  }

  Future<void> deleteTask(String id) {
    return _client.from('tasks').delete().eq('id', id);
  }

  Future<List<RecurringTask>> fetchRecurringTasks(String userId) async {
    return fetchWithCache(
      cache: _cache,
      key: 'recurring_tasks_$userId',
      remote: () async =>
          ((await _client
                      .from('recurring_tasks')
                      .select('*, courses(name)')
                      .eq('user_id', userId)
                      .order('weekday'))
                  as List)
              .cast<Map<String, dynamic>>(),
      parse: RecurringTask.fromMap,
    );
  }

  Future<void> saveRecurringTask({
    required String userId,
    String? id,
    String? courseId,
    required String title,
    String? description,
    required TaskPriority priority,
    required int weekday,
    required int deadlineMinute,
    required bool active,
  }) {
    final row = {
      'course_id': courseId,
      'title': title,
      'description': description,
      'priority': priority.dbValue,
      'weekday': weekday,
      'deadline_minute': deadlineMinute,
      'active': active,
    };

    if (id != null) {
      return _client.from('recurring_tasks').update(row).eq('id', id);
    }
    return _client.from('recurring_tasks').insert({'user_id': userId, ...row});
  }

  /// Menghapus template tidak menghapus tugas yang sudah terlanjur dibuat —
  /// `recurring_id` di tabel tugas jadi null, isinya tetap ada. Pekerjaan yang
  /// sudah kamu catat tidak boleh hilang karena template-nya dirapikan.
  Future<void> deleteRecurringTask(String id) {
    return _client.from('recurring_tasks').delete().eq('id', id);
  }

  /// Buat tugas untuk kejadian yang belum ada.
  ///
  /// Memakai upsert dengan `ignoreDuplicates`, jadi dua HP yang membuka app
  /// bersamaan tidak menghasilkan tugas kembar: yang kedua ditolak indeks unik
  /// di database, bukan sekadar dihindari oleh kode di sini.
  ///
  /// Mengembalikan jumlah yang dikirim.
  Future<int> createOccurrences(String userId, List<TugasTerjadwal> occurrences) async {
    if (occurrences.isEmpty) return 0;

    await _client.from('tasks').upsert(
      [
        for (final item in occurrences)
          {
            'user_id': userId,
            'course_id': item.sumber.courseId,
            'title': item.sumber.title,
            'description': item.sumber.description,
            'deadline': item.deadline.toIso8601String(),
            'priority': item.sumber.priority.dbValue,
            'status': TaskStatus.todo.dbValue,
            'recurring_id': item.sumber.id,
            'recurring_on': item.tanggal.toIso8601String().substring(0, 10),
          },
      ],
      onConflict: 'recurring_id,recurring_on',
      ignoreDuplicates: true,
    );

    return occurrences.length;
  }
}

final academicRepositoryProvider = Provider<AcademicRepository>((ref) {
  return AcademicRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(localCacheProvider),
  );
});
