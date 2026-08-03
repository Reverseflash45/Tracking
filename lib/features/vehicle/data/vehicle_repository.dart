import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/offline/local_cache.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../domain/vehicle.dart';

String _tanggal(DateTime date) => date.toIso8601String().substring(0, 10);

class VehicleRepository {
  VehicleRepository(this._client, this._cache);

  final SupabaseClient _client;
  final LocalCache _cache;

  Future<List<Vehicle>> fetchVehicles(String userId) async {
    return fetchWithCache(
      cache: _cache,
      key: 'vehicles_$userId',
      remote: () async =>
          ((await _client
                      .from('vehicles')
                      .select()
                      .eq('user_id', userId)
                      .order('created_at'))
                  as List)
              .cast<Map<String, dynamic>>(),
      parse: Vehicle.fromMap,
    );
  }

  Future<List<ServiceLog>> fetchServices(String userId) async {
    return fetchWithCache(
      cache: _cache,
      key: 'vehicle_services_$userId',
      remote: () async =>
          ((await _client
                      .from('vehicle_services')
                      .select()
                      .eq('user_id', userId)
                      .order('done_on', ascending: false))
                  as List)
              .cast<Map<String, dynamic>>(),
      parse: ServiceLog.fromMap,
    );
  }

  Future<void> saveVehicle({
    required String userId,
    String? id,
    required String name,
    required VehicleType type,
    String? plate,
    int? year,
    int? odometerKm,
    DateTime? odometerOn,
    DateTime? taxDueOn,
    DateTime? plateDueOn,
  }) {
    final row = {
      'name': name,
      'type': type.name,
      'plate': plate,
      'year': year,
      // Odometer dan tanggalnya selalu ditulis berpasangan. Database menolak
      // salah satunya kosong, dan aturan itu memang yang diinginkan: angka
      // odometer tanpa tanggal tidak bisa dipakai menghitung apa pun.
      'odometer_km': odometerKm,
      'odometer_on': odometerKm == null ? null : _tanggal(odometerOn ?? DateTime.now()),
      'tax_due_on': taxDueOn == null ? null : _tanggal(taxDueOn),
      'plate_due_on': plateDueOn == null ? null : _tanggal(plateDueOn),
    };

    if (id != null) {
      return _client.from('vehicles').update(row).eq('id', id);
    }
    return _client.from('vehicles').insert({'user_id': userId, ...row});
  }

  Future<void> deleteVehicle(String id) {
    return _client.from('vehicles').delete().eq('id', id);
  }

  Future<void> saveService({
    required String userId,
    String? id,
    required String vehicleId,
    required ServiceKind kind,
    required DateTime doneOn,
    int? odometerKm,
    double? cost,
    String? note,
  }) {
    final row = {
      'vehicle_id': vehicleId,
      'kind': kind.name,
      'done_on': _tanggal(doneOn),
      'odometer_km': odometerKm,
      'cost': cost,
      'note': note,
    };

    if (id != null) {
      return _client.from('vehicle_services').update(row).eq('id', id);
    }
    return _client.from('vehicle_services').insert({'user_id': userId, ...row});
  }

  Future<void> deleteService(String id) {
    return _client.from('vehicle_services').delete().eq('id', id);
  }

  /// Majukan jatuh tempo pajak satu tahun setelah dibayar.
  Future<void> perpanjangPajak(String id, DateTime tempoLama) {
    return _client
        .from('vehicles')
        .update({'tax_due_on': _tanggal(DateTime(tempoLama.year + 1, tempoLama.month, tempoLama.day))})
        .eq('id', id);
  }
}

final vehicleRepositoryProvider = Provider<VehicleRepository>((ref) {
  return VehicleRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(localCacheProvider),
  );
});

final vehiclesProvider = FutureProvider.autoDispose<List<Vehicle>>((ref) async {
  final userId = ref.watch(currentUserProvider)?.id;
  if (userId == null) return const [];
  return ref.watch(vehicleRepositoryProvider).fetchVehicles(userId);
});

final vehicleServicesProvider = FutureProvider.autoDispose<List<ServiceLog>>((ref) async {
  final userId = ref.watch(currentUserProvider)?.id;
  if (userId == null) return const [];
  return ref.watch(vehicleRepositoryProvider).fetchServices(userId);
});

/// Riwayat servis satu kendaraan.
final servicesForVehicleProvider =
    Provider.autoDispose.family<List<ServiceLog>, String>((ref, vehicleId) {
  final semua = ref.watch(vehicleServicesProvider).value ?? const <ServiceLog>[];
  return [
    for (final log in semua)
      if (log.vehicleId == vehicleId) log,
  ];
});

/// Pengingat seluruh kendaraan, digabung dan diurut yang paling mendesak dulu.
///
/// Dipakai kartu ringkasan: yang perlu kamu lihat sekilas bukan "motor punya
/// enam jadwal", tapi "ada satu yang sudah lewat".
typedef PengingatKendaraan = ({Vehicle kendaraan, Pengingat pengingat});

final pengingatKendaraanProvider =
    Provider.autoDispose<List<PengingatKendaraan>>((ref) {
  final vehicles = ref.watch(vehiclesProvider).value ?? const <Vehicle>[];
  final services = ref.watch(vehicleServicesProvider).value ?? const <ServiceLog>[];
  final now = DateTime.now();

  final hasil = <PengingatKendaraan>[];
  for (final vehicle in vehicles) {
    final logs = [
      for (final log in services)
        if (log.vehicleId == vehicle.id) log,
    ];
    for (final pengingat in daftarPengingat(vehicle: vehicle, logs: logs, now: now)) {
      if (pengingat.status != StatusTempo.aman) {
        hasil.add((kendaraan: vehicle, pengingat: pengingat));
      }
    }
  }

  return hasil;
});
