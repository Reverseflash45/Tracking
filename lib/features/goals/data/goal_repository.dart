import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/offline/local_cache.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../../academic/data/models/task.dart';
import '../../academic/presentation/academic_providers.dart';
import '../../finance/data/finance_repository.dart';
import '../../finance/domain/transaction.dart';
import '../../run/data/run_repository.dart';
import '../../sleep/data/sleep_repository.dart';
import '../../workout/data/models/workout_session.dart';
import '../../workout/presentation/workout_providers.dart';
import '../domain/goal.dart';

class GoalRepository {
  GoalRepository(this._client, this._cache);

  final SupabaseClient _client;
  final LocalCache _cache;

  Future<List<Goal>> fetchGoals(String userId) async {
    final rows = await fetchWithCache<Map<String, dynamic>>(
      cache: _cache,
      key: 'goals_$userId',
      remote: () async =>
          ((await _client
                      .from('goals')
                      .select()
                      .eq('user_id', userId)
                      .order('created_at'))
                  as List)
              .cast<Map<String, dynamic>>(),
      parse: (map) => map,
    );

    // Baris dengan metrik yang tidak dikenal dilewati, bukan membuat seluruh
    // daftar gagal dimuat.
    return [
      for (final row in rows) ?Goal.fromMap(row),
    ];
  }

  Future<void> saveGoal({
    required String userId,
    String? id,
    required String title,
    required GoalMetric metric,
    required double targetValue,
    required GoalPeriod period,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    final row = {
      'title': title,
      'metric': metric.name,
      'target_value': targetValue,
      'period': period.name,
      // Target berulang tidak menyimpan tanggal: jendelanya selalu dihitung
      // dari hari ini, dan tanggal sisa cuma jadi data yang membingungkan.
      'start_date': period == GoalPeriod.sekali
          ? startDate?.toIso8601String().substring(0, 10)
          : null,
      'end_date':
          period == GoalPeriod.sekali ? endDate?.toIso8601String().substring(0, 10) : null,
    };

    if (id != null) {
      return _client.from('goals').update(row).eq('id', id);
    }
    return _client.from('goals').insert({'user_id': userId, ...row});
  }

  Future<void> setArchived(String id, bool archived) {
    return _client.from('goals').update({'archived': archived}).eq('id', id);
  }

  Future<void> deleteGoal(String id) {
    return _client.from('goals').delete().eq('id', id);
  }
}

final goalRepositoryProvider = Provider<GoalRepository>((ref) {
  return GoalRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(localCacheProvider),
  );
});

final goalsProvider = FutureProvider.autoDispose<List<Goal>>((ref) async {
  final userId = ref.watch(currentUserProvider)?.id;
  if (userId == null) return const [];
  return ref.watch(goalRepositoryProvider).fetchGoals(userId);
});

/// Kemajuan tiap target, dihitung ulang dari data yang sudah dimuat.
///
/// Semuanya di HP — tidak ada query tambahan, jadi halaman Target juga terbaca
/// tanpa sinyal selama datanya masih ada di cache.
final goalProgressProvider = Provider.autoDispose<AsyncValue<List<GoalProgress>>>((ref) {
  final goals = ref.watch(goalsProvider);

  return goals.whenData(
    (list) => evaluateGoals(
      goals: list,
      now: DateTime.now(),
      data: GoalData(
        runs: ref.watch(runsProvider).value ?? const <RunLog>[],
        sessions: ref.watch(workoutSessionsProvider).value ?? const <WorkoutSession>[],
        tasks: ref.watch(tasksProvider).value ?? const <AcademicTask>[],
        sleeps: ref.watch(sleepLogsProvider).value ?? const <SleepLog>[],
        transactions: ref.watch(transactionsProvider).value ?? const <Transaction>[],
      ),
    ),
  );
});
