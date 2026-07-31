import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../domain/body_profile.dart';

class BodyRepository {
  BodyRepository(this._client);

  final SupabaseClient _client;

  Future<BodyProfile?> fetchProfile(String userId) async {
    final row = await _client
        .from('body_profiles')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    if (row == null) return null;
    return BodyProfile.fromMap(row);
  }

  Future<void> saveProfile({required String userId, required BodyProfile profile}) {
    return _client.from('body_profiles').upsert(
          profile.toUpsertMap(userId),
          onConflict: 'user_id',
        );
  }

  /// Riwayat berat, terbaru dulu.
  Future<List<WeightLog>> fetchWeightLogs(String userId) async {
    final rows = await _client
        .from('weight_logs')
        .select('logged_on, weight_kg')
        .eq('user_id', userId)
        .order('logged_on', ascending: false);
    return (rows as List)
        .map((row) => WeightLog.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  /// Satu catatan berat per hari — mencatat ulang di hari yang sama menimpa
  /// nilai sebelumnya, bukan menambah baris baru.
  Future<void> logWeight({
    required String userId,
    required double weightKg,
    DateTime? loggedOn,
  }) {
    final date = loggedOn ?? DateTime.now();
    return _client.from('weight_logs').upsert(
      {
        'user_id': userId,
        'logged_on': date.toIso8601String().substring(0, 10),
        'weight_kg': weightKg,
      },
      onConflict: 'user_id,logged_on',
    );
  }
}

final bodyRepositoryProvider = Provider<BodyRepository>((ref) {
  return BodyRepository(ref.watch(supabaseClientProvider));
});

final bodyProfileProvider = FutureProvider.autoDispose<BodyProfile?>((ref) async {
  final userId = ref.watch(currentUserProvider)?.id;
  if (userId == null) return null;
  return ref.watch(bodyRepositoryProvider).fetchProfile(userId);
});

final weightLogsProvider = FutureProvider.autoDispose<List<WeightLog>>((ref) async {
  final userId = ref.watch(currentUserProvider)?.id;
  if (userId == null) return const [];
  return ref.watch(bodyRepositoryProvider).fetchWeightLogs(userId);
});

/// Berat terbaru yang tercatat, dipakai kalkulator kalori sebagai berat kini.
final currentWeightProvider = Provider.autoDispose<AsyncValue<double?>>((ref) {
  final logs = ref.watch(weightLogsProvider);
  return logs.whenData((list) => list.isEmpty ? null : list.first.weightKg);
});
