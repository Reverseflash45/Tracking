import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/offline/local_cache.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../domain/attendance.dart';

class AttendanceRepository {
  AttendanceRepository(this._client, this._cache);

  final SupabaseClient _client;
  final LocalCache _cache;

  Future<List<Attendance>> fetchAll(String userId) {
    return fetchWithCache(
      cache: _cache,
      key: 'attendance_$userId',
      parse: Attendance.fromMap,
      remote: () async => (await _client
              .from('attendance')
              .select()
              .eq('user_id', userId)
              .order('meeting_date', ascending: false))
          .cast<Map<String, dynamic>>(),
    );
  }

  /// Simpan kehadiran satu pertemuan.
  ///
  /// Upsert pada (user, mata kuliah, tanggal): mencatat ulang tanggal yang sama
  /// berarti mengoreksi, bukan menambah pertemuan kedua. Tanpa ini, menekan
  /// tombol dua kali diam-diam menggandakan hitungannya.
  Future<void> simpan({
    required String userId,
    required String courseId,
    required DateTime meetingDate,
    required StatusKehadiran status,
    String? scheduleId,
    String? note,
  }) {
    final catatan = note?.trim();
    return _client.from('attendance').upsert({
      'user_id': userId,
      'course_id': courseId,
      'schedule_id': scheduleId,
      'meeting_date': meetingDate.toIso8601String().substring(0, 10),
      'status': status.dbValue,
      'note': (catatan == null || catatan.isEmpty) ? null : catatan,
    }, onConflict: 'user_id,course_id,meeting_date');
  }

  Future<void> hapus(String id) {
    return _client.from('attendance').delete().eq('id', id);
  }
}

final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  return AttendanceRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(localCacheProvider),
  );
});

final attendanceProvider = FutureProvider<List<Attendance>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const [];
  return ref.watch(attendanceRepositoryProvider).fetchAll(user.id);
});
