import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/offline/local_cache.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../domain/note.dart';

class NoteRepository {
  NoteRepository(this._client, this._cache);

  final SupabaseClient _client;
  final LocalCache _cache;

  Future<List<Note>> fetchAll(String userId) {
    return fetchWithCache(
      cache: _cache,
      key: 'notes_$userId',
      parse: Note.fromMap,
      remote: () async => (await _client
              .from('notes')
              .select()
              .eq('user_id', userId)
              .order('updated_at', ascending: false))
          .cast<Map<String, dynamic>>(),
    );
  }

  /// Membuat catatan baru dan mengembalikan id-nya.
  ///
  /// Id-nya dikembalikan supaya editor bisa langsung berpindah ke mode ubah —
  /// tanpa itu, menekan simpan dua kali di catatan baru menghasilkan dua
  /// catatan yang isinya sama.
  Future<String> buat({
    required String userId,
    String? title,
    required String body,
  }) async {
    final dibuat = await _client
        .from('notes')
        .insert({
          'user_id': userId,
          'title': _bersih(title),
          'body': body,
        })
        .select('id')
        .single();

    return dibuat['id'] as String;
  }

  /// `updated_at` diisi dari sini, bukan dibiarkan pada nilai bawaannya.
  ///
  /// Tanpa ini kolomnya berhenti di waktu pembuatan, dan daftar yang diurut
  /// "terakhir diubah" jadi mengurut waktu yang tidak pernah berubah.
  Future<void> perbarui({
    required String id,
    String? title,
    required String body,
  }) {
    return _client
        .from('notes')
        .update({
          'title': _bersih(title),
          'body': body,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', id);
  }

  /// Menyematkan tidak mengubah `updated_at`: yang berubah letaknya di daftar,
  /// bukan isinya. Kalau ikut diubah, menyematkan catatan lama membuatnya
  /// seolah-olah baru saja ditulis.
  Future<void> sematkan(String id, bool pinned) {
    return _client.from('notes').update({'pinned': pinned}).eq('id', id);
  }

  Future<void> hapus(String id) {
    return _client.from('notes').delete().eq('id', id);
  }

  /// Judul kosong disimpan sebagai null, bukan string kosong, supaya "tidak
  /// berjudul" cuma punya satu bentuk di database.
  String? _bersih(String? teks) {
    final hasil = teks?.trim();
    return (hasil == null || hasil.isEmpty) ? null : hasil;
  }
}

final noteRepositoryProvider = Provider<NoteRepository>((ref) {
  return NoteRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(localCacheProvider),
  );
});

final notesProvider = FutureProvider<List<Note>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const [];
  return ref.watch(noteRepositoryProvider).fetchAll(user.id);
});
