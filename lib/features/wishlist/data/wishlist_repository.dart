import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/offline/local_cache.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../../finance/data/finance_repository.dart';
import '../../finance/domain/transaction.dart';
import '../domain/wishlist.dart';

class WishlistRepository {
  WishlistRepository(this._client, this._cache);

  final SupabaseClient _client;
  final LocalCache _cache;

  Future<List<WishlistItem>> fetchItems(String userId) async {
    return fetchWithCache(
      cache: _cache,
      key: 'wishlist_$userId',
      remote: () async =>
          ((await _client
                      .from('wishlist_items')
                      .select()
                      .eq('user_id', userId)
                      .order('created_at'))
                  as List)
              .cast<Map<String, dynamic>>(),
      parse: WishlistItem.fromMap,
    );
  }

  Future<void> saveItem({
    required String userId,
    String? id,
    required String name,
    double? price,
    required TxCategory category,
    required WishPriority priority,
    String? url,
    String? note,
    DateTime? targetDate,
  }) {
    final row = {
      'name': name,
      'price': price,
      'category': category.dbValue,
      'priority': priority.name,
      'url': url,
      'note': note,
      'target_date': targetDate?.toIso8601String().substring(0, 10),
    };

    if (id != null) {
      return _client.from('wishlist_items').update(row).eq('id', id);
    }
    return _client.from('wishlist_items').insert({'user_id': userId, ...row});
  }

  /// Ubah jumlah yang sudah disisihkan.
  ///
  /// Nilai akhirnya dikirim, bukan selisihnya, supaya menekan tombol dua kali
  /// karena jaringan lambat tidak menambah tabungan dua kali.
  Future<void> setSaved(String id, double saved) {
    return _client
        .from('wishlist_items')
        .update({'saved': saved < 0 ? 0 : saved})
        .eq('id', id);
  }

  Future<void> setBought(String id, DateTime? tanggal) {
    return _client
        .from('wishlist_items')
        .update({'bought_on': tanggal?.toIso8601String().substring(0, 10)})
        .eq('id', id);
  }

  Future<void> deleteItem(String id) {
    return _client.from('wishlist_items').delete().eq('id', id);
  }
}

final wishlistRepositoryProvider = Provider<WishlistRepository>((ref) {
  return WishlistRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(localCacheProvider),
  );
});

final wishlistProvider = FutureProvider.autoDispose<List<WishlistItem>>((ref) async {
  final userId = ref.watch(currentUserProvider)?.id;
  if (userId == null) return const [];
  final items = await ref.watch(wishlistRepositoryProvider).fetchItems(userId);
  return sortWishlist(items);
});

/// Sisa uang per bulan, dari riwayat transaksi yang sudah dimuat.
final surplusBulananProvider = Provider.autoDispose<double>((ref) {
  final transactions = ref.watch(transactionsProvider).value ?? const <Transaction>[];
  return surplusBulanan(transactions, now: DateTime.now());
});

/// Wishlist lengkap dengan perkiraan kapan tiap barang terjangkau.
final wishlistPlanProvider = Provider.autoDispose<AsyncValue<List<WishlistPlan>>>((ref) {
  final surplus = ref.watch(surplusBulananProvider);
  final now = DateTime.now();

  return ref.watch(wishlistProvider).whenData(
        (items) => [
          for (final item in items) planFor(item, surplus: surplus, now: now),
        ],
      );
});
