import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/offline/local_cache.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../domain/routine.dart';

class RoutineRepository {
  RoutineRepository(this._client, this._cache);

  final SupabaseClient _client;
  final LocalCache _cache;

  Future<List<RoutineItem>> fetchAll(String userId) {
    return fetchWithCache(
      cache: _cache,
      key: 'routines_$userId',
      parse: RoutineItem.fromMap,
      remote: () async => (await _client
              .from('routines')
              .select()
              .eq('user_id', userId)
              .order('day_of_week')
              .order('start_time'))
          .cast<Map<String, dynamic>>(),
    );
  }

  Future<void> simpan({
    required String userId,
    String? id,
    required int dayOfWeek,
    required String startTime,
    String? endTime,
    required String title,
    required KategoriRutinitas category,
    String? note,
  }) {
    final catatan = note?.trim();
    final baris = {
      'day_of_week': dayOfWeek,
      'start_time': startTime,
      'end_time': endTime,
      'title': title.trim(),
      'category': category.dbValue,
      'note': (catatan == null || catatan.isEmpty) ? null : catatan,
    };

    if (id != null) {
      return _client.from('routines').update(baris).eq('id', id);
    }
    return _client.from('routines').insert({'user_id': userId, ...baris});
  }

  Future<void> hapus(String id) {
    return _client.from('routines').delete().eq('id', id);
  }

  /// Salin [item] ke [keHari].
  ///
  /// Menambah, bukan mengganti. Hari tujuan yang sudah berisi tidak dikosongkan
  /// diam-diam — menghapus isi hari yang sudah kamu susun itu kerugian yang
  /// jauh lebih besar daripada beberapa baris kembar yang bisa kamu geser
  /// hapus satu per satu.
  Future<int> salinKeHari({
    required String userId,
    required List<RoutineItem> item,
    required int keHari,
  }) async {
    if (item.isEmpty) return 0;

    await _client.from('routines').insert([
      for (final r in item)
        {
          'user_id': userId,
          'day_of_week': keHari,
          'start_time': r.startTime,
          'end_time': r.endTime,
          'title': r.title,
          'category': r.category.dbValue,
          'note': r.note,
        },
    ]);

    return item.length;
  }
}

final routineRepositoryProvider = Provider<RoutineRepository>((ref) {
  return RoutineRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(localCacheProvider),
  );
});

final routinesProvider = FutureProvider<List<RoutineItem>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const [];
  return ref.watch(routineRepositoryProvider).fetchAll(user.id);
});
