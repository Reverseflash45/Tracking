import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client_provider.dart';

class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  Future<void> signIn({required String email, required String password}) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signUp({
    required String email,
    required String password,
    String? fullName,
  }) async {
    // `full_name` dikirim sebagai user metadata, lalu dibaca oleh trigger
    // `handle_new_user` (lihat supabase/migrations/0002_auto_create_profile.sql)
    // untuk mengisi tabel profiles. Insert langsung dari client tidak dipakai
    // karena saat signUp belum tentu ada sesi aktif (mis. email confirmation
    // masih diwajibkan), sehingga akan ditolak RLS.
    await _client.auth.signUp(
      email: email,
      password: password,
      data: fullName != null && fullName.trim().isNotEmpty
          ? {'full_name': fullName.trim()}
          : null,
    );
  }

  Future<void> signOut() => _client.auth.signOut();
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(supabaseClientProvider));
});
