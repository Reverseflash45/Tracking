import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../domain/food_photo.dart';

/// Kesalahan yang layak ditampilkan apa adanya ke user.
class FotoMakananException implements Exception {
  const FotoMakananException(this.message);
  final String message;

  @override
  String toString() => message;
}

class FoodPhotoRepository {
  FoodPhotoRepository(this._client);

  final SupabaseClient _client;

  /// Kirim foto ke Edge Function "foto-makanan" dan kembalikan taksirannya.
  ///
  /// API key tidak pernah menyentuh app ini — fungsi di Supabase yang
  /// memegangnya. Fotonya diharapkan sudah diperkecil oleh pemanggil.
  Future<HasilFotoMakanan> taksir(
    Uint8List foto, {
    String mediaType = 'image/jpeg',
    String? keterangan,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'foto-makanan',
        body: {
          'image': base64Encode(foto),
          'media_type': mediaType,
          if (keterangan != null && keterangan.trim().isNotEmpty) 'note': keterangan.trim(),
        },
      );

      final data = response.data;
      if (data is! Map) {
        throw const FotoMakananException('Jawaban dari server tidak dikenali.');
      }
      final error = data['error'];
      if (error is String && error.isNotEmpty) throw FotoMakananException(error);

      return HasilFotoMakanan.fromJson(Map<String, dynamic>.from(data));
    } on FunctionException catch (e) {
      // 404 hampir selalu berarti fungsinya belum di-deploy — pesan bawaannya
      // tidak menjelaskan itu sama sekali.
      if (e.status == 404) {
        throw const FotoMakananException(
          'Fitur ini belum aktif: fungsi "foto-makanan" belum ada di Supabase. '
          'Jalankan "supabase functions deploy foto-makanan" dulu.',
        );
      }
      final detail = e.details;
      if (detail is Map && detail['error'] is String) {
        throw FotoMakananException(detail['error'] as String);
      }
      throw FotoMakananException('Gagal menghubungi server (${e.status}).');
    }
  }
}

final foodPhotoRepositoryProvider = Provider<FoodPhotoRepository>((ref) {
  return FoodPhotoRepository(ref.watch(supabaseClientProvider));
});
