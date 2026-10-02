import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/offline/local_cache.dart';
import '../../../core/offline/pending_writes.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../domain/berkala.dart';

String _tanggal(DateTime date) => date.toIso8601String().substring(0, 10);

/// Baris riwayat "selesai" yang siap dikirim atau diantrekan.
Map<String, dynamic> barisLogBerkala({
  required String logId,
  required String routineId,
  required String userId,
  required DateTime doneOn,
}) =>
    {
      'id': logId,
      'routine_id': routineId,
      'user_id': userId,
      'done_on': _tanggal(doneOn),
    };

class BerkalaRepository {
  BerkalaRepository(this._client, this._cache, this._antrean);

  final SupabaseClient _client;
  final LocalCache _cache;
  final PendingWriteQueue _antrean;

  Future<List<RutinitasBerkala>> fetchAll(String userId) {
    return fetchWithCache(
      cache: _cache,
      key: 'periodic_routines_$userId',
      parse: RutinitasBerkala.fromMap,
      remote: () async => (await _client
              .from('periodic_routines')
              .select()
              .eq('user_id', userId)
              .order('last_done_on'))
          .cast<Map<String, dynamic>>(),
    );
  }

  /// Riwayat satu rutinitas, terbaru di atas.
  Future<List<LogBerkala>> riwayat(String routineId, {int batas = 20}) async {
    final rows = await _client
        .from(kTabelLogBerkala)
        .select()
        .eq('routine_id', routineId)
        .order('done_on', ascending: false)
        .order('created_at', ascending: false)
        .limit(batas);
    return [for (final row in rows) LogBerkala.fromMap(row)];
  }

  Future<void> simpan({
    required String userId,
    String? id,
    required String title,
    required int intervalDays,
    required DateTime lastDoneOn,
    String? remindAt,
    String? note,
  }) {
    final catatan = note?.trim();
    final baris = {
      'title': title.trim(),
      'interval_days': intervalDays,
      'last_done_on': _tanggal(lastDoneOn),
      'remind_at': remindAt,
      'note': (catatan == null || catatan.isEmpty) ? null : catatan,
    };

    if (id != null) {
      return _client.from('periodic_routines').update(baris).eq('id', id);
    }
    return _client.from('periodic_routines').insert({'user_id': userId, ...baris});
  }

  /// Tandai selesai pada [tanggal]. Mengembalikan id catatannya (untuk
  /// dibatalkan) dan apakah sudah terkirim atau masih di antrean.
  ///
  /// Lewat antrean offline, jadi tetap jalan tanpa sinyal.
  Future<({String logId, bool terkirim})> tandaiSelesai(
    RutinitasBerkala item,
    DateTime tanggal,
  ) async {
    final logId = uuidBaru();
    final terkirim = await _antrean.submit(
      table: kTabelLogBerkala,
      payload: barisLogBerkala(
        logId: logId,
        routineId: item.id,
        userId: item.userId,
        doneOn: tanggal,
      ),
      label: item.title,
    );
    return (logId: logId, terkirim: terkirim);
  }

  /// Batalkan satu catatan selesai. Yang masih di antrean cukup ditarik dari
  /// antrean; yang sudah terkirim dihapus, dan trigger di server memulihkan
  /// tanggal terakhirnya.
  Future<void> batalkan(String logId) async {
    for (final item in await _antrean.pending()) {
      if (item.table == kTabelLogBerkala && item.payload['id'] == logId) {
        await _antrean.hapus(item.id);
        return;
      }
    }
    await _client.from(kTabelLogBerkala).delete().eq('id', logId);
  }

  Future<void> hapus(String id) {
    return _client.from('periodic_routines').delete().eq('id', id);
  }
}

final berkalaRepositoryProvider = Provider<BerkalaRepository>((ref) {
  return BerkalaRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(localCacheProvider),
    ref.watch(pendingWriteQueueProvider),
  );
});

final berkalaProvider = FutureProvider<List<RutinitasBerkala>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const [];

  final semua = await ref.watch(berkalaRepositoryProvider).fetchAll(user.id);
  // Catatan yang belum terkirim tetap dihitung, supaya layar dan pengingat
  // tidak menagih sesuatu yang sudah kamu kerjakan.
  final tertunda = await ref.watch(pendingWritesProvider.future);
  return urutkanBerkala(terapkanAntrean(semua, [
    for (final item in tertunda)
      if (item.table == kTabelLogBerkala) item.payload,
  ]));
});

final riwayatBerkalaProvider =
    FutureProvider.autoDispose.family<List<LogBerkala>, String>((ref, routineId) {
  return ref.watch(berkalaRepositoryProvider).riwayat(routineId);
});
