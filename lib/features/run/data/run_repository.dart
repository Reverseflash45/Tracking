import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/offline/local_cache.dart';
import '../../../core/offline/pending_writes.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../domain/geo.dart';
import '../domain/run_stats.dart';

class RunLog {
  const RunLog({
    required this.id,
    required this.startedAt,
    required this.durationSeconds,
    required this.distanceMeters,
    required this.route,
    this.notes,
  });

  final String id;
  final DateTime startedAt;

  /// Durasi bergerak, tidak termasuk jeda.
  final int durationSeconds;

  final double distanceMeters;
  final List<GeoPoint> route;
  final String? notes;

  /// Detik per kilometer, atau null kalau jaraknya nol.
  double? get pace =>
      paceSecondsPerKm(distanceMeters: distanceMeters, seconds: durationSeconds);

  factory RunLog.fromMap(Map<String, dynamic> map) => RunLog(
    id: map['id'] as String,
    startedAt: DateTime.parse(map['started_at'] as String).toLocal(),
    durationSeconds: (map['duration_seconds'] as num).toInt(),
    distanceMeters: (map['distance_meters'] as num).toDouble(),
    route: [
      for (final point in (map['route'] as List? ?? const []))
        GeoPoint.fromJson(point as Map<String, dynamic>),
    ],
    notes: map['notes'] as String?,
  );

  Map<String, dynamic> toInsertMap(String userId) => {
    'user_id': userId,
    'started_at': startedAt.toUtc().toIso8601String(),
    'duration_seconds': durationSeconds,
    'distance_meters': distanceMeters,
    'route': [for (final point in route) point.toJson()],
    'notes': notes,
  };
}

class RunRepository {
  RunRepository(this._client, this._cache);

  final SupabaseClient _client;
  final LocalCache _cache;

  Future<List<RunLog>> fetchRuns(String userId) async {
    return fetchWithCache(
      cache: _cache,
      key: 'runs_$userId',
      remote: () async =>
          ((await _client
                      .from('runs')
                      .select()
                      .eq('user_id', userId)
                      .order('started_at', ascending: false))
                  as List)
              .cast<Map<String, dynamic>>(),
      parse: RunLog.fromMap,
    );
  }

  /// Simpan lari. Kalau sinyalnya mati, masuk antrean — bukan hilang.
  ///
  /// Mengembalikan true kalau langsung terkirim. Inilah alasan antrean itu
  /// dibuat: lari itu justru dicatat di tempat yang sinyalnya paling jelek.
  Future<bool> addRun({
    required String userId,
    required RunLog run,
    required PendingWriteQueue queue,
  }) {
    final km = (run.distanceMeters / 1000).toStringAsFixed(2).replaceAll('.', ',');
    return queue.submit(
      table: 'runs',
      payload: run.toInsertMap(userId),
      label: 'Lari $km km',
    );
  }

  Future<void> deleteRun(String id) {
    return _client.from('runs').delete().eq('id', id);
  }
}

final runRepositoryProvider = Provider<RunRepository>((ref) {
  return RunRepository(ref.watch(supabaseClientProvider), ref.watch(localCacheProvider));
});

final runsProvider = FutureProvider.autoDispose<List<RunLog>>((ref) async {
  final userId = ref.watch(currentUserProvider)?.id;
  if (userId == null) return const [];
  return ref.watch(runRepositoryProvider).fetchRuns(userId);
});
