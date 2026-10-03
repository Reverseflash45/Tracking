import 'package:flutter/foundation.dart'
    show TargetPlatform, debugPrint, defaultTargetPlatform, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../sleep/data/sleep_repository.dart';
import '../domain/kesehatan.dart';

/// Health Connect hanya ada di Android.
bool get healthConnectDidukung => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

enum StatusHealthConnect {
  /// Bukan Android.
  tidakDidukung,

  /// App Health Connect belum terpasang atau perlu diperbarui (Android 13 ke
  /// bawah; di Android 14+ dia bagian dari sistem).
  perluPasang,

  /// Terpasang, tapi izin membaca belum diberikan.
  perluIzin,

  siap,
}

/// Yang dibaca. Hanya membaca: app ini tidak menulis apa pun ke Health Connect.
const List<HealthDataType> _jenis = [
  HealthDataType.STEPS,
  HealthDataType.SLEEP_SESSION,
  HealthDataType.HEART_RATE,
  HealthDataType.RESTING_HEART_RATE,
];

/// Izin yang wajib ada supaya fitur ini berguna. Detak jantung opsional:
/// banyak gelang tidak mencatat detak istirahat sama sekali.
const List<HealthDataType> _jenisWajib = [HealthDataType.STEPS, HealthDataType.SLEEP_SESSION];

const _tersambungKey = 'health_connect_tersambung';

class RingkasanKesehatan {
  const RingkasanKesehatan({
    required this.status,
    this.langkah = const [],
    this.detakIstirahat,
  });

  final StatusHealthConnect status;

  /// Tujuh hari terakhir, hari ini paling akhir.
  final List<LangkahHarian> langkah;

  /// Rata-rata detak jantung istirahat 7 hari terakhir, kalau dicatat.
  final int? detakIstirahat;

  int? get langkahHariIni => langkah.isEmpty ? null : langkah.last.langkah;
}

class HealthConnectService {
  final Health _health = Health();
  bool _siap = false;

  Future<void> _konfigurasi() async {
    if (_siap) return;
    await _health.configure();
    _siap = true;
  }

  Future<StatusHealthConnect> status() async {
    if (!healthConnectDidukung) return StatusHealthConnect.tidakDidukung;
    try {
      await _konfigurasi();
      final sdk = await _health.getHealthConnectSdkStatus();
      if (sdk != HealthConnectSdkStatus.sdkAvailable) return StatusHealthConnect.perluPasang;
      final izin = await _health.hasPermissions(_jenisWajib);
      return izin == true ? StatusHealthConnect.siap : StatusHealthConnect.perluIzin;
    } catch (e) {
      debugPrint('Status Health Connect gagal: $e');
      return StatusHealthConnect.perluPasang;
    }
  }

  Future<void> pasang() async {
    await _konfigurasi();
    await _health.installHealthConnect();
  }

  /// Buka layar izin Health Connect. True kalau izin wajibnya diberikan.
  Future<bool> mintaIzin() async {
    await _konfigurasi();
    await _health.requestAuthorization(
      _jenis,
      permissions: [for (final _ in _jenis) HealthDataAccess.READ],
    );
    final ok = await _health.hasPermissions(_jenisWajib) == true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_tersambungKey, ok);
    return ok;
  }

  /// Pernah disambungkan dari app ini. Dipakai supaya impor latar tidak
  /// menyentuh Health Connect sama sekali untuk yang tidak memakainya.
  Future<bool> pernahDisambungkan() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_tersambungKey) ?? false;
  }

  Future<void> putuskan() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_tersambungKey, false);
    try {
      await _konfigurasi();
      await _health.revokePermissions();
    } catch (e) {
      debugPrint('Mencabut izin Health Connect gagal: $e');
    }
  }

  Future<RingkasanKesehatan> ringkasan() async {
    final st = await status();
    if (st != StatusHealthConnect.siap) return RingkasanKesehatan(status: st);

    final sekarang = DateTime.now();
    final hariIni = DateTime(sekarang.year, sekarang.month, sekarang.day);

    final langkah = <LangkahHarian>[];
    for (var i = 6; i >= 0; i--) {
      final mulai = hariIni.subtract(Duration(days: i));
      final selesai = i == 0 ? sekarang : mulai.add(const Duration(days: 1));
      int? jumlah;
      try {
        jumlah = await _health.getTotalStepsInInterval(mulai, selesai);
      } catch (e) {
        debugPrint('Langkah $mulai gagal: $e');
      }
      langkah.add(LangkahHarian(tanggal: mulai, langkah: jumlah ?? 0));
    }

    int? detak;
    try {
      final titik = await _health.getHealthDataFromTypes(
        types: const [HealthDataType.RESTING_HEART_RATE],
        startTime: hariIni.subtract(const Duration(days: 7)),
        endTime: sekarang,
      );
      final nilai = [
        for (final t in titik)
          if (t.value is NumericHealthValue) (t.value as NumericHealthValue).numericValue,
      ];
      if (nilai.isNotEmpty) {
        detak = (nilai.fold<num>(0, (a, b) => a + b) / nilai.length).round();
      }
    } catch (e) {
      // Izin detak jantung memang opsional.
      debugPrint('Detak istirahat gagal: $e');
    }

    return RingkasanKesehatan(status: st, langkah: langkah, detakIstirahat: detak);
  }

  /// Sesi tidur [hari] hari terakhir.
  Future<List<SesiTidur>> sesiTidur({int hari = 14}) async {
    await _konfigurasi();
    final sekarang = DateTime.now();
    final titik = await _health.getHealthDataFromTypes(
      types: const [HealthDataType.SLEEP_SESSION],
      startTime: sekarang.subtract(Duration(days: hari)),
      endTime: sekarang,
    );
    return [
      for (final t in _health.removeDuplicates(titik))
        SesiTidur(mulai: t.dateFrom, selesai: t.dateTo),
    ];
  }
}

final healthConnectProvider = Provider<HealthConnectService>((ref) => HealthConnectService());

final ringkasanKesehatanProvider = FutureProvider.autoDispose<RingkasanKesehatan>((ref) {
  return ref.watch(healthConnectProvider).ringkasan();
});

/// Impor tidur dari Health Connect ke catatan tidur. Mengembalikan jumlah hari
/// yang ditulis; 0 kalau tidak ada yang baru atau fiturnya tidak dipakai.
Future<int> imporTidurHealthConnect({
  required HealthConnectService hc,
  required SleepRepository repo,
  required String userId,
}) async {
  if (!healthConnectDidukung || !await hc.pernahDisambungkan()) return 0;
  if (await hc.status() != StatusHealthConnect.siap) return 0;

  final perHari = tidurPerHari(await hc.sesiTidur());
  if (perHari.isEmpty) return 0;

  final logs = await repo.fetchSleep(userId);
  final rencana = rencanaImporTidur(
    dariHealthConnect: perHari,
    tercatat: [
      for (final l in logs)
        TidurTercatat(tanggal: l.loggedOn, jam: l.hours, kualitas: l.quality, catatan: l.note),
    ],
  );

  for (final r in rencana) {
    await repo.saveSleep(
      userId: userId,
      date: r.tanggal,
      hours: r.jam,
      quality: r.kualitas,
      note: kPenandaHealthConnect,
    );
  }
  return rencana.length;
}
