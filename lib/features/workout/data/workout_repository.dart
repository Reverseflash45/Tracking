import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/offline/local_cache.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import 'models/exercise_entry.dart';
import 'models/workout_session.dart';
import 'models/workout_template.dart';

class WorkoutRepository {
  WorkoutRepository(this._client, this._cache);

  final SupabaseClient _client;
  final LocalCache _cache;

  Future<List<WorkoutSession>> fetchSessions(String userId) async {
    return fetchWithCache(
      cache: _cache,
      key: 'workout_sessions_$userId',
      remote: () async =>
          ((await _client
                      .from('workout_sessions')
                      .select('*, workout_exercises(*)')
                      .eq('user_id', userId)
                      .order('session_date', ascending: false))
                  as List)
              .cast<Map<String, dynamic>>(),
      parse: WorkoutSession.fromMap,
    );
  }

  Future<void> addSession({
    required String userId,
    required DateTime sessionDate,
    String? notes,
    required List<ExerciseEntry> exercises,
  }) async {
    final sessionRow = await _client
        .from('workout_sessions')
        .insert({
          'user_id': userId,
          'session_date': sessionDate.toIso8601String().substring(0, 10),
          'notes': notes,
        })
        .select()
        .single();

    final sessionId = sessionRow['id'] as String;
    if (exercises.isEmpty) return;

    await _client
        .from('workout_exercises')
        .insert(
          exercises
              .map((e) => e.toInsertMap(sessionId: sessionId, userId: userId))
              .toList(),
        );
  }

  /// Latihan di dalam sesi diganti total (hapus lalu insert ulang) — jumlah
  /// barisnya sedikit, dan ini menghindari perlu melacak baris mana yang
  /// ditambah/diubah/dihapus di form.
  Future<void> updateSession({
    required String sessionId,
    required String userId,
    required DateTime sessionDate,
    String? notes,
    required List<ExerciseEntry> exercises,
  }) async {
    await _client
        .from('workout_sessions')
        .update({
          'session_date': sessionDate.toIso8601String().substring(0, 10),
          'notes': notes,
        })
        .eq('id', sessionId);

    await _client.from('workout_exercises').delete().eq('session_id', sessionId);

    if (exercises.isEmpty) return;
    await _client
        .from('workout_exercises')
        .insert(
          exercises
              .map((e) => e.toInsertMap(sessionId: sessionId, userId: userId))
              .toList(),
        );
  }

  Future<void> deleteSession(String id) {
    return _client.from('workout_sessions').delete().eq('id', id);
  }

  // --- Template ---

  Future<List<WorkoutTemplate>> fetchTemplates(String userId) async {
    return fetchWithCache(
      cache: _cache,
      key: 'workout_templates_$userId',
      remote: () async =>
          ((await _client
                      .from('workout_templates')
                      .select('*, workout_template_exercises(*)')
                      .eq('user_id', userId)
                      .order('created_at', ascending: false))
                  as List)
              .cast<Map<String, dynamic>>(),
      parse: WorkoutTemplate.fromMap,
    );
  }

  Future<void> addTemplate({
    required String userId,
    required String name,
    required List<TemplateExercise> exercises,
  }) async {
    final row = await _client
        .from('workout_templates')
        .insert({'user_id': userId, 'name': name})
        .select()
        .single();

    final templateId = row['id'] as String;
    if (exercises.isEmpty) return;

    await _client.from('workout_template_exercises').insert([
      for (var i = 0; i < exercises.length; i++)
        exercises[i].toInsertMap(templateId: templateId, userId: userId, position: i),
    ]);
  }

  Future<void> deleteTemplate(String id) {
    return _client.from('workout_templates').delete().eq('id', id);
  }
}

final workoutRepositoryProvider = Provider<WorkoutRepository>((ref) {
  return WorkoutRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(localCacheProvider),
  );
});
