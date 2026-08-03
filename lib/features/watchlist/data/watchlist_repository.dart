import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/offline/local_cache.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../domain/watchlist.dart';

class WatchlistRepository {
  WatchlistRepository(this._client, this._cache);

  final SupabaseClient _client;
  final LocalCache _cache;

  Future<List<MediaItem>> fetchItems(String userId) async {
    return fetchWithCache(
      cache: _cache,
      key: 'media_items_$userId',
      remote: () async =>
          ((await _client
                      .from('media_items')
                      .select()
                      .eq('user_id', userId)
                      .order('created_at'))
                  as List)
              .cast<Map<String, dynamic>>(),
      parse: MediaItem.fromMap,
    );
  }

  Future<void> saveItem({
    required String userId,
    String? id,
    required String title,
    required MediaKind kind,
    required MediaOrigin origin,
    required WatchStatus status,
    int? year,
    required int progress,
    int? total,
    int? rating,
    String? url,
    String? note,
    DateTime? finishedOn,
  }) {
    final row = {
      'title': title,
      'kind': kind.name,
      'origin': origin.name,
      'status': status.name,
      'year': year,
      'progress': progress,
      'total': total,
      'rating': rating,
      'url': url,
      'note': note,
      'finished_on': finishedOn?.toIso8601String().substring(0, 10),
    };

    if (id != null) {
      return _client.from('media_items').update(row).eq('id', id);
    }
    return _client.from('media_items').insert({'user_id': userId, ...row});
  }

  /// Simpan hasil [majuSatu] dan perubahan status lain.
  ///
  /// Yang dikirim keadaan akhirnya, bukan "tambah satu": menekan tombolnya dua
  /// kali karena jaringan lambat tidak boleh melompat dua episode.
  Future<void> updateProgres(MediaItem item) {
    return _client
        .from('media_items')
        .update({
          'progress': item.progress,
          'status': item.status.name,
          'finished_on': item.finishedOn?.toIso8601String().substring(0, 10),
        })
        .eq('id', item.id);
  }

  Future<void> setRating(String id, int? rating) {
    return _client.from('media_items').update({'rating': rating}).eq('id', id);
  }

  Future<void> deleteItem(String id) {
    return _client.from('media_items').delete().eq('id', id);
  }
}

final watchlistRepositoryProvider = Provider<WatchlistRepository>((ref) {
  return WatchlistRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(localCacheProvider),
  );
});

final watchlistProvider = FutureProvider.autoDispose<List<MediaItem>>((ref) async {
  final userId = ref.watch(currentUserProvider)?.id;
  if (userId == null) return const [];
  final items = await ref.watch(watchlistRepositoryProvider).fetchItems(userId);
  return sortWatchlist(items);
});

/// Penyaring yang sedang aktif di halaman Watchlist.
final watchFilterProvider =
    NotifierProvider.autoDispose<WatchFilterController, WatchFilter>(
  WatchFilterController.new,
);

class WatchFilterController extends Notifier<WatchFilter> {
  @override
  WatchFilter build() => const WatchFilter();

  void setKind(MediaKind? kind) =>
      state = state.copyWith(kind: kind, hapusKind: kind == null);

  void setOrigin(MediaOrigin? origin) =>
      state = state.copyWith(origin: origin, hapusOrigin: origin == null);

  void setStatus(WatchStatus? status) =>
      state = state.copyWith(status: status, hapusStatus: status == null);

  void setQuery(String query) => state = state.copyWith(query: query);

  void bersihkan() => state = const WatchFilter();
}

/// Daftar yang sudah disaring, siap ditampilkan.
final watchlistTersaringProvider =
    Provider.autoDispose<AsyncValue<List<MediaItem>>>((ref) {
  final filter = ref.watch(watchFilterProvider);
  return ref.watch(watchlistProvider).whenData(
        (items) => filterWatchlist(items, filter),
      );
});
