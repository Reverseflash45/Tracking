import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/offline/local_cache.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../domain/document.dart';

String _tanggal(DateTime date) => date.toIso8601String().substring(0, 10);

class DocumentRepository {
  DocumentRepository(this._client, this._cache);

  final SupabaseClient _client;
  final LocalCache _cache;

  Future<List<Document>> fetchDocuments(String userId) async {
    return fetchWithCache(
      cache: _cache,
      key: 'documents_$userId',
      remote: () async =>
          ((await _client
                      .from('documents')
                      .select()
                      .eq('user_id', userId)
                      .order('created_at'))
                  as List)
              .cast<Map<String, dynamic>>(),
      parse: Document.fromMap,
    );
  }

  Future<void> saveDocument({
    required String userId,
    String? id,
    required String name,
    required DocKind kind,
    String? number,
    DateTime? issuedOn,
    DateTime? expiresOn,
    required bool noExpiry,
    String? note,
  }) {
    final row = {
      'name': name,
      'kind': kind.name,
      'number': number,
      'issued_on': issuedOn == null ? null : _tanggal(issuedOn),
      // Database menolak keduanya terisi bersamaan, jadi tanggalnya dibuang di
      // sini kalau ditandai seumur hidup — bukan dibiarkan bentrok lalu gagal
      // saat disimpan.
      'expires_on': noExpiry || expiresOn == null ? null : _tanggal(expiresOn),
      'no_expiry': noExpiry,
      'note': note,
    };

    if (id != null) {
      return _client.from('documents').update(row).eq('id', id);
    }
    return _client.from('documents').insert({'user_id': userId, ...row});
  }

  Future<void> deleteDocument(String id) {
    return _client.from('documents').delete().eq('id', id);
  }
}

final documentRepositoryProvider = Provider<DocumentRepository>((ref) {
  return DocumentRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(localCacheProvider),
  );
});

final documentsProvider = FutureProvider.autoDispose<List<Document>>((ref) async {
  final userId = ref.watch(currentUserProvider)?.id;
  if (userId == null) return const [];
  final items = await ref.watch(documentRepositoryProvider).fetchDocuments(userId);
  return sortDocuments(items, now: DateTime.now());
});
