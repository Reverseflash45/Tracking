import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client_provider.dart';

class ProfileData {
  const ProfileData({this.fullName, this.avatarUrl});

  final String? fullName;
  final String? avatarUrl;
}

class ProfileRepository {
  ProfileRepository(this._client);

  final SupabaseClient _client;

  Future<ProfileData?> fetchProfile(String userId) async {
    final row = await _client
        .from('profiles')
        .select('full_name, avatar_url')
        .eq('id', userId)
        .maybeSingle();
    if (row == null) return null;
    return ProfileData(
      fullName: row['full_name'] as String?,
      avatarUrl: row['avatar_url'] as String?,
    );
  }

  Future<String> uploadAvatar({
    required String userId,
    required Uint8List bytes,
    required String fileExt,
  }) async {
    final path = '$userId/avatar.$fileExt';
    await _client.storage.from('avatars').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );

    final publicUrl = _client.storage.from('avatars').getPublicUrl(path);
    final cacheBustedUrl = '$publicUrl?t=${DateTime.now().millisecondsSinceEpoch}';

    await _client.from('profiles').update({'avatar_url': cacheBustedUrl}).eq('id', userId);

    return cacheBustedUrl;
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(supabaseClientProvider));
});

final profileProvider = FutureProvider.autoDispose<ProfileData?>((ref) async {
  final userId = ref.watch(currentUserProvider)?.id;
  if (userId == null) return null;
  return ref.watch(profileRepositoryProvider).fetchProfile(userId);
});
