import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import 'models/exercise_entry.dart';
import 'models/workout_session.dart';

class WorkoutRepository {
  WorkoutRepository(this._client);

  final SupabaseClient _client;

  Future<List<WorkoutSession>> fetchSessions(String userId) async {
    final rows = await _client
        .from('workout_sessions')
        .select('*, workout_exercises(*)')
        .eq('user_id', userId)
        .order('session_date', ascending: false);
    return (rows as List)
        .map((row) => WorkoutSession.fromMap(row as Map<String, dynamic>))
        .toList();
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

    await _client.from('workout_exercises').insert(
          exercises.map((e) => e.toInsertMap(sessionId: sessionId, userId: userId)).toList(),
        );
  }

  Future<void> deleteSession(String id) {
    return _client.from('workout_sessions').delete().eq('id', id);
  }
}

final workoutRepositoryProvider = Provider<WorkoutRepository>((ref) {
  return WorkoutRepository(ref.watch(supabaseClientProvider));
});
