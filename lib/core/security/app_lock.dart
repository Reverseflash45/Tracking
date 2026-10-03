import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb, visibleForTesting;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Kunci app memakai sidik jari, wajah, atau PIN layar HP.
///
/// Yang dikunci tampilannya saja — data di Supabase tetap dilindungi login dan
/// RLS seperti biasa. Tujuannya mencegah orang yang meminjam HP-mu membuka
/// dokumen, keuangan, dan catatan begitu saja.
bool get kunciDidukung {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
}

const _kunciAktifKey = 'kunci_aktif';
const _kunciJedaKey = 'kunci_jeda_detik';

/// Berapa lama app boleh di latar sebelum terkunci lagi.
///
/// Tanpa jeda, membuka kamera untuk foto KRS atau share sheet untuk ekspor
/// pun langsung mengunci app saat kembali — app lain itu membuat app ini
/// masuk latar. Satu menit cukup untuk itu.
const List<Duration> kPilihanJeda = [
  Duration.zero,
  Duration(seconds: 30),
  Duration(minutes: 1),
  Duration(minutes: 5),
];
const Duration kJedaBawaan = Duration(minutes: 1);

String labelJeda(Duration jeda) {
  if (jeda == Duration.zero) return 'Segera';
  if (jeda.inMinutes == 0) return '${jeda.inSeconds} detik';
  return '${jeda.inMinutes} menit';
}

/// Apakah app harus terkunci saat kembali dari latar.
@visibleForTesting
bool perluKunciLagi({
  required bool aktif,
  required DateTime keLatar,
  required DateTime sekarang,
  required Duration jeda,
}) {
  if (!aktif) return false;
  // Jam HP yang dimundurkan tidak boleh jadi cara melewati kunci.
  final lama = sekarang.difference(keLatar);
  return lama.isNegative || lama >= jeda;
}

class KunciState {
  const KunciState({
    this.siap = false,
    this.aktif = false,
    this.jeda = kJedaBawaan,
    this.terkunci = false,
  });

  /// Setelan sudah dibaca dari penyimpanan. Sebelum itu layar ditutup polos
  /// supaya isi app tidak sempat terlihat sekilas.
  final bool siap;
  final bool aktif;
  final Duration jeda;
  final bool terkunci;

  KunciState copyWith({bool? siap, bool? aktif, Duration? jeda, bool? terkunci}) => KunciState(
        siap: siap ?? this.siap,
        aktif: aktif ?? this.aktif,
        jeda: jeda ?? this.jeda,
        terkunci: terkunci ?? this.terkunci,
      );
}

class KunciController extends Notifier<KunciState> {
  final _auth = LocalAuthentication();

  /// Dialog sidik jari sedang tampil. Di beberapa HP dialog itu membuat app
  /// "masuk latar" sebentar; tanpa penanda ini, membuka kunci justru
  /// mengunci lagi.
  bool sedangAuth = false;

  @override
  KunciState build() {
    if (!kunciDidukung) return const KunciState(siap: true);
    _muat();
    return const KunciState();
  }

  Future<void> _muat() async {
    var aktif = false;
    var jeda = kJedaBawaan;
    try {
      final prefs = await SharedPreferences.getInstance();
      aktif = prefs.getBool(_kunciAktifKey) ?? false;
      final detik = prefs.getInt(_kunciJedaKey);
      if (detik != null) jeda = Duration(seconds: detik);
    } catch (_) {
      // Penyimpanan tidak terbaca: anggap kunci mati daripada app tidak bisa
      // dibuka sama sekali.
    }
    // Baru dibuka dari nol: terkunci kalau fiturnya aktif.
    state = KunciState(siap: true, aktif: aktif, jeda: jeda, terkunci: aktif);
  }

  /// Dipanggil saat app kembali dari latar.
  void kembaliDariLatar(DateTime keLatar) {
    if (sedangAuth || state.terkunci) return;
    if (perluKunciLagi(
      aktif: state.aktif,
      keLatar: keLatar,
      sekarang: DateTime.now(),
      jeda: state.jeda,
    )) {
      state = state.copyWith(terkunci: true);
    }
  }

  /// Tampilkan dialog sidik jari / PIN. Null kalau berhasil, atau pesan
  /// kesalahan yang layak ditampilkan.
  Future<String?> autentikasi(String alasan) async {
    if (sedangAuth) return null;
    sedangAuth = true;
    try {
      final ok = await _auth.authenticate(
        localizedReason: alasan,
        persistAcrossBackgrounding: true,
      );
      return ok ? null : 'Belum berhasil. Coba lagi.';
    } on LocalAuthException catch (e) {
      return switch (e.code) {
        LocalAuthExceptionCode.userCanceled ||
        LocalAuthExceptionCode.systemCanceled ||
        LocalAuthExceptionCode.timeout =>
          'Dibatalkan.',
        LocalAuthExceptionCode.noCredentialsSet =>
          'HP-mu belum punya kunci layar. Atur PIN atau sidik jari di setelan HP dulu.',
        LocalAuthExceptionCode.temporaryLockout =>
          'Terlalu banyak percobaan. Tunggu sebentar, lalu coba lagi.',
        LocalAuthExceptionCode.biometricLockout =>
          'Sidik jari terkunci. Buka dengan PIN layar HP.',
        _ => 'Gagal membuka kunci (${e.code.name}).',
      };
    } on PlatformException catch (e) {
      return 'Gagal membuka kunci: ${e.message ?? e.code}';
    } finally {
      sedangAuth = false;
    }
  }

  Future<String?> buka() async {
    final galat = await autentikasi('Buka Tracking');
    if (galat == null) state = state.copyWith(terkunci: false);
    return galat;
  }

  /// Menyalakan atau mematikan kunci selalu butuh autentikasi: menyalakan
  /// memastikan HP-nya memang punya kunci layar (kalau tidak, app bisa
  /// terkunci selamanya), mematikan mencegah orang lain melepasnya.
  Future<String?> setAktif(bool aktif) async {
    if (!kunciDidukung) return 'Kunci app hanya ada di HP.';
    if (aktif) {
      try {
        if (!await _auth.isDeviceSupported()) {
          return 'HP-mu belum punya kunci layar. Atur PIN atau sidik jari di setelan HP dulu.';
        }
      } on PlatformException catch (e) {
        return 'Tidak bisa memeriksa kunci layar: ${e.message ?? e.code}';
      }
    }

    final galat = await autentikasi(aktif ? 'Nyalakan kunci app' : 'Matikan kunci app');
    if (galat != null) return galat;

    state = state.copyWith(aktif: aktif, terkunci: false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kunciAktifKey, aktif);
    return null;
  }

  Future<void> setJeda(Duration jeda) async {
    state = state.copyWith(jeda: jeda);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kunciJedaKey, jeda.inSeconds);
  }
}

final kunciProvider = NotifierProvider<KunciController, KunciState>(KunciController.new);
