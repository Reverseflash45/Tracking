import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/offline/local_cache.dart';
import '../../../core/supabase/supabase_client_provider.dart';

const String kProgressBucket = 'progress-photos';

/// Berapa lama tautan foto berlaku.
///
/// Bucket-nya sengaja privat, jadi foto dibaca lewat tautan bertanda tangan.
/// Satu jam cukup panjang untuk satu sesi melihat-lihat, dan cukup pendek
/// supaya tautan yang tanpa sengaja tersalin tidak berlaku selamanya.
const int kSignedUrlSeconds = 3600;

class ProgressPhoto {
  const ProgressPhoto({
    required this.id,
    required this.takenOn,
    required this.storagePath,
    this.weightKg,
    this.note,
  });

  final String id;
  final DateTime takenOn;
  final String storagePath;
  final double? weightKg;
  final String? note;

  factory ProgressPhoto.fromMap(Map<String, dynamic> map) => ProgressPhoto(
        id: map['id'] as String,
        takenOn: DateTime.parse(map['taken_on'] as String),
        storagePath: map['storage_path'] as String,
        weightKg: (map['weight_kg'] as num?)?.toDouble(),
        note: map['note'] as String?,
      );
}

class ProgressPhotoRepository {
  ProgressPhotoRepository(this._client, this._cache);

  final SupabaseClient _client;
  final LocalCache _cache;

  Future<List<ProgressPhoto>> fetchPhotos(String userId) {
    return fetchWithCache(
      cache: _cache,
      key: 'progress_photos_$userId',
      remote: () async =>
          ((await _client
                      .from('progress_photos')
                      .select()
                      .eq('user_id', userId)
                      .order('taken_on', ascending: false))
                  as List)
              .cast<Map<String, dynamic>>(),
      parse: ProgressPhoto.fromMap,
    );
  }

  /// Tautan sementara untuk menampilkan foto.
  Future<String> signedUrl(String storagePath) {
    return _client.storage
        .from(kProgressBucket)
        .createSignedUrl(storagePath, kSignedUrlSeconds);
  }

  /// Unggah foto lalu catat barisnya.
  ///
  /// Kalau pencatatan barisnya gagal, filenya dihapus lagi — file yatim di
  /// storage tidak bisa dilihat maupun dihapus dari app, dan tetap memakan
  /// kuota.
  Future<void> addPhoto({
    required String userId,
    required XFile file,
    required DateTime takenOn,
    double? weightKg,
    String? note,
  }) async {
    final ext = file.path.split('.').last.toLowerCase();
    final path = '$userId/${DateTime.now().microsecondsSinceEpoch}.'
        '${ext.length <= 4 ? ext : 'jpg'}';

    await _client.storage.from(kProgressBucket).upload(path, File(file.path));

    try {
      await _client.from('progress_photos').insert({
        'user_id': userId,
        'taken_on': takenOn.toIso8601String().substring(0, 10),
        'storage_path': path,
        'weight_kg': weightKg,
        'note': note,
      });
    } catch (e) {
      await _client.storage.from(kProgressBucket).remove([path]);
      rethrow;
    }
  }

  /// Hapus baris dan filenya sekaligus.
  Future<void> deletePhoto(ProgressPhoto photo) async {
    await _client.from('progress_photos').delete().eq('id', photo.id);
    // Barisnya sudah hilang, jadi kegagalan menghapus file tidak boleh
    // menggagalkan seluruh operasi — fotonya sudah tidak terjangkau app.
    try {
      await _client.storage.from(kProgressBucket).remove([photo.storagePath]);
    } catch (_) {}
  }
}

final progressPhotoRepositoryProvider = Provider<ProgressPhotoRepository>((ref) {
  return ProgressPhotoRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(localCacheProvider),
  );
});

final progressPhotosProvider =
    FutureProvider.autoDispose<List<ProgressPhoto>>((ref) async {
  final userId = ref.watch(currentUserProvider)?.id;
  if (userId == null) return const [];
  return ref.watch(progressPhotoRepositoryProvider).fetchPhotos(userId);
});

/// Tautan bertanda tangan per foto, di-cache selama halaman terbuka supaya
/// tidak minta tautan baru tiap kali daftar digambar ulang.
final signedPhotoUrlProvider =
    FutureProvider.autoDispose.family<String, String>((ref, storagePath) async {
  return ref.watch(progressPhotoRepositoryProvider).signedUrl(storagePath);
});
