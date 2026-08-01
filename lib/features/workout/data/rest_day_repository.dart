import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/offline/local_cache.dart';
import '../../../core/supabase/supabase_client_provider.dart';

/// Riwayat dibatasi supaya query tidak membesar tanpa batas. Cukup panjang
/// untuk menghitung streak terpanjang selama lebih dari setahun.
const int _historyDays = 400;

/// Satu hari yang sengaja ditandai untuk pemulihan.
class RestDay {
  const RestDay({required this.id, required this.restOn, this.note});

  final String id;
  final DateTime restOn;
  final String? note;

  factory RestDay.fromMap(Map<String, dynamic> map) => RestDay(
    id: map['id'] as String,
    // Kolomnya bertipe date, jadi tidak ada zona waktu yang perlu digeser —
    // memakai toLocal() di sini justru bisa memundurkan tanggalnya sehari.
    restOn: DateTime.parse(map['rest_on'] as String),
    note: map['note'] as String?,
  );
}

String _dateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

class RestDayRepository {
  RestDayRepository(this._client, this._cache);

  final SupabaseClient _client;
  final LocalCache _cache;

  Future<List<RestDay>> fetchRestDays(String userId) async {
    final since = DateTime.now().subtract(const Duration(days: _historyDays));

    return fetchWithCache(
      cache: _cache,
      key: 'rest_days_$userId',
      remote: () async =>
          ((await _client
                      .from('rest_days')
                      .select()
                      .eq('user_id', userId)
                      .gte('rest_on', _dateKey(since))
                      .order('rest_on', ascending: false))
                  as List)
              .cast<Map<String, dynamic>>(),
      parse: RestDay.fromMap,
    );
  }

  /// Tandai satu hari sebagai hari istirahat.
  ///
  /// Memakai upsert supaya menandai hari yang sama dua kali tidak menabrak
  /// unique constraint dan tidak perlu diperlakukan sebagai error.
  Future<void> addRestDay({required String userId, required DateTime date, String? note}) {
    return _client.from('rest_days').upsert({
      'user_id': userId,
      'rest_on': _dateKey(date),
      'note': note,
    }, onConflict: 'user_id,rest_on');
  }

  Future<void> deleteRestDay(String id) {
    return _client.from('rest_days').delete().eq('id', id);
  }
}

final restDayRepositoryProvider = Provider<RestDayRepository>((ref) {
  return RestDayRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(localCacheProvider),
  );
});

final restDaysProvider = FutureProvider.autoDispose<List<RestDay>>((ref) async {
  final userId = ref.watch(currentUserProvider)?.id;
  if (userId == null) return const [];
  return ref.watch(restDayRepositoryProvider).fetchRestDays(userId);
});
