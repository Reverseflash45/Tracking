import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/offline/local_cache.dart';
import '../../../core/supabase/supabase_client_provider.dart';

/// Sama panjangnya dengan riwayat lain supaya rekap tahunan tidak terpotong
/// diam-diam.
const int _historyDays = 400;

class SleepLog {
  const SleepLog({
    required this.id,
    required this.loggedOn,
    required this.hours,
    this.quality,
    this.note,
  });

  final String id;

  /// Tanggal bangun, bukan tanggal mulai tidur.
  final DateTime loggedOn;

  final double hours;

  /// 1-5, opsional.
  final int? quality;

  final String? note;

  factory SleepLog.fromMap(Map<String, dynamic> map) => SleepLog(
        id: map['id'] as String,
        loggedOn: DateTime.parse(map['logged_on'] as String),
        hours: (map['hours'] as num).toDouble(),
        quality: (map['quality'] as num?)?.toInt(),
        note: map['note'] as String?,
      );
}

String _dateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

class SleepRepository {
  SleepRepository(this._client, this._cache);

  final SupabaseClient _client;
  final LocalCache _cache;

  Future<List<SleepLog>> fetchSleep(String userId) {
    final since = DateTime.now().subtract(const Duration(days: _historyDays));

    return fetchWithCache(
      cache: _cache,
      key: 'sleep_logs_$userId',
      remote: () async =>
          ((await _client
                      .from('sleep_logs')
                      .select()
                      .eq('user_id', userId)
                      .gte('logged_on', _dateKey(since))
                      .order('logged_on', ascending: false))
                  as List)
              .cast<Map<String, dynamic>>(),
      parse: SleepLog.fromMap,
    );
  }

  /// Upsert supaya mengoreksi tidur hari yang sama tidak menabrak unique
  /// constraint — orang sering mencatat kira-kira dulu lalu membetulkan.
  Future<void> saveSleep({
    required String userId,
    required DateTime date,
    required double hours,
    int? quality,
    String? note,
  }) {
    return _client.from('sleep_logs').upsert(
      {
        'user_id': userId,
        'logged_on': _dateKey(date),
        'hours': hours,
        'quality': quality,
        'note': note,
      },
      onConflict: 'user_id,logged_on',
    );
  }

  Future<void> deleteSleep(String id) {
    return _client.from('sleep_logs').delete().eq('id', id);
  }
}

final sleepRepositoryProvider = Provider<SleepRepository>((ref) {
  return SleepRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(localCacheProvider),
  );
});

final sleepLogsProvider = FutureProvider.autoDispose<List<SleepLog>>((ref) async {
  final userId = ref.watch(currentUserProvider)?.id;
  if (userId == null) return const [];
  return ref.watch(sleepRepositoryProvider).fetchSleep(userId);
});

/// Catatan tidur untuk hari ini, kalau sudah diisi.
final todaySleepProvider = Provider.autoDispose<SleepLog?>((ref) {
  final logs = ref.watch(sleepLogsProvider).value ?? const <SleepLog>[];
  final today = DateTime.now();
  for (final log in logs) {
    if (log.loggedOn.year == today.year &&
        log.loggedOn.month == today.month &&
        log.loggedOn.day == today.day) {
      return log;
    }
  }
  return null;
});
