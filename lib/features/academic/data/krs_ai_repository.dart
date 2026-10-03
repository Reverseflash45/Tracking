import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../domain/krs_ai.dart';

/// Kesalahan yang layak ditampilkan apa adanya ke user.
class BacaKrsException implements Exception {
  const BacaKrsException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Batas ukuran gambar yang dikirim, sama dengan batas di Edge Function
/// (1,5 juta karakter base64). Yang lebih besar langsung dibaca on-device
/// saja, daripada ditolak server setelah menunggu unggahannya.
const int kMaksBytesKrs = 1100000;

class KrsAiRepository {
  KrsAiRepository(this._client);

  final SupabaseClient _client;

  /// Kirim gambar KRS ke Edge Function "baca-krs".
  ///
  /// API key tidak pernah menyentuh app ini — fungsi di Supabase yang
  /// memegangnya.
  Future<HasilBacaKrs> baca(Uint8List gambar, {required String mediaType}) async {
    if (gambar.length > kMaksBytesKrs) {
      throw const BacaKrsException('Gambarnya terlalu besar untuk dibaca AI.');
    }

    try {
      final response = await _client.functions.invoke(
        'baca-krs',
        body: {'image': base64Encode(gambar), 'media_type': mediaType},
      );

      final data = response.data;
      if (data is! Map) {
        throw const BacaKrsException('Jawaban dari server tidak dikenali.');
      }
      final error = data['error'];
      if (error is String && error.isNotEmpty) throw BacaKrsException(error);

      return HasilBacaKrs.fromJson(Map<String, dynamic>.from(data));
    } on FunctionException catch (e) {
      // 404 hampir selalu berarti fungsinya belum di-deploy — pesan bawaannya
      // tidak menjelaskan itu sama sekali.
      if (e.status == 404) {
        throw const BacaKrsException('Fungsi "baca-krs" belum ada di Supabase.');
      }
      final detail = e.details;
      if (detail is Map && detail['error'] is String) {
        throw BacaKrsException(detail['error'] as String);
      }
      throw BacaKrsException('Gagal menghubungi server (${e.status}).');
    }
  }
}

final krsAiRepositoryProvider = Provider<KrsAiRepository>((ref) {
  return KrsAiRepository(ref.watch(supabaseClientProvider));
});
