/// Pelapor error tanpa layanan luar.
///
/// Error Dart/Flutter yang lolos ditangkap, ditampung di berkas lokal, lalu
/// dikirim ke tabel `crash_reports` di Supabase begitu ada sinyal dan sesi
/// login. Tanpa ini, crash di HP orang lain tidak pernah kamu ketahui.
///
/// Sengaja hanya di build rilis: saat mengembangkan, error sudah terlihat di
/// konsol, dan mengirimnya cuma memenuhi tabel dengan error setengah jadi.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const String kTabelCrash = 'crash_reports';

/// Paling banyak sekian laporan berbeda ditampung sebelum terkirim. Yang
/// paling lama dibuang duluan — HP yang berminggu-minggu offline tidak boleh
/// menumpuk berkas tanpa batas.
const int kMaksLaporanTertampung = 30;

const _aktifKey = 'crash_report_enabled';

String potong(String teks, int maks) => teks.length <= maks ? teks : '${teks.substring(0, maks - 1)}…';

class LaporanError {
  const LaporanError({
    required this.occurredAt,
    required this.error,
    this.stack,
    this.konteks,
    this.jumlah = 1,
  });

  final DateTime occurredAt;
  final String error;
  final String? stack;
  final String? konteks;

  /// Berapa kali error yang sama muncul sebelum terkirim.
  final int jumlah;

  /// Error dianggap sama kalau pesan dan baris stack pertamanya sama. Pesan
  /// saja terlalu kasar ("Null check operator" muncul di mana-mana); stack
  /// lengkap terlalu halus (nomor frame async bisa berbeda tiap kali).
  String get kunci {
    final barisPertama = stack
        ?.split('\n')
        .map((b) => b.trim())
        .firstWhere((b) => b.isNotEmpty, orElse: () => '');
    return '$error|$barisPertama';
  }

  LaporanError tambahSatu() => LaporanError(
        occurredAt: occurredAt,
        error: error,
        stack: stack,
        konteks: konteks,
        jumlah: jumlah + 1,
      );

  Map<String, dynamic> toJson() => {
        'occurred_at': occurredAt.toUtc().toIso8601String(),
        'error': error,
        'stack': stack,
        'context': konteks,
        'occurrences': jumlah,
      };

  static LaporanError fromJson(Map<String, dynamic> json) => LaporanError(
        occurredAt: DateTime.parse(json['occurred_at'] as String),
        error: json['error'] as String,
        stack: json['stack'] as String?,
        konteks: json['context'] as String?,
        jumlah: (json['occurrences'] as num?)?.toInt() ?? 1,
      );

  /// Dari error mentah, dengan batas panjang yang sama dengan kolom tabel.
  static LaporanError dari(Object error, StackTrace? stack, {String? konteks, DateTime? waktu}) =>
      LaporanError(
        occurredAt: waktu ?? DateTime.now(),
        error: potong('${error.runtimeType}: $error', 2000),
        stack: stack == null ? null : potong(stack.toString(), 8000),
        konteks: konteks == null ? null : potong(konteks, 500),
      );
}

/// Tambahkan [baru] ke tampungan: error yang sama hanya menaikkan hitungan,
/// dan tampungan tidak pernah lebih dari [maks].
List<LaporanError> gabungLaporan(
  List<LaporanError> ada,
  LaporanError baru, {
  int maks = kMaksLaporanTertampung,
}) {
  final hasil = [...ada];
  final i = hasil.indexWhere((l) => l.kunci == baru.kunci);
  if (i >= 0) {
    hasil[i] = hasil[i].tambahSatu();
    return hasil;
  }
  hasil.add(baru);
  return hasil.length > maks ? hasil.sublist(hasil.length - maks) : hasil;
}

class CrashReporter {
  CrashReporter._();

  static final CrashReporter instance = CrashReporter._();

  /// Saklar di Profil. Menyala secara bawaan; mematikannya juga membuang
  /// tampungan yang belum terkirim.
  final ValueNotifier<bool> aktif = ValueNotifier(true);

  String? _versi;
  File? _berkas;
  Future<void> _antrean = Future.value();

  bool get _didukung => !kIsWeb && kReleaseMode;

  /// Pasang penangkap error. Dipanggil sekali di awal `main`, sesudah binding
  /// Flutter siap.
  Future<void> pasang() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      aktif.value = prefs.getBool(_aktifKey) ?? true;
      _versi = (await PackageInfo.fromPlatform()).version;
    } catch (_) {
      // Tetap pasang penangkapnya; versi yang tidak diketahui bukan alasan
      // untuk melewatkan error.
    }

    final bawaanFlutter = FlutterError.onError;
    FlutterError.onError = (details) {
      bawaanFlutter?.call(details);
      catat(details.exception, details.stack, konteks: details.context?.toDescription());
    };

    final bawaanPlatform = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (error, stack) {
      catat(error, stack, konteks: 'tidak tertangkap (async)');
      // false: biarkan engine tetap mencatatnya seperti biasa.
      return bawaanPlatform?.call(error, stack) ?? false;
    };
  }

  void catat(Object error, StackTrace? stack, {String? konteks}) {
    if (!_didukung || !aktif.value) return;
    final laporan = LaporanError.dari(error, stack, konteks: konteks);
    _berurutan(() async {
      final ada = await _baca();
      await _tulis(gabungLaporan(ada, laporan));
    });
  }

  /// Kirim tampungan. Mengembalikan jumlah laporan yang terkirim.
  Future<int> kirim(SupabaseClient client) async {
    if (!_didukung) return 0;
    final userId = client.auth.currentUser?.id;
    if (userId == null || !aktif.value) return 0;

    var terkirim = 0;
    await _berurutan(() async {
      final ada = await _baca();
      if (ada.isEmpty) return;
      try {
        await client.from(kTabelCrash).insert([
          for (final l in ada)
            {
              ...l.toJson(),
              'user_id': userId,
              'app_version': _versi,
              'platform': '${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
            },
        ]);
        await _tulis(const []);
        terkirim = ada.length;
      } catch (e) {
        // Belum ada sinyal atau tabelnya belum dibuat — coba lagi lain kali.
        debugPrint('Laporan error belum terkirim: $e');
      }
    });
    return terkirim;
  }

  Future<void> setAktif(bool nilai) async {
    aktif.value = nilai;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_aktifKey, nilai);
    if (!nilai && _didukung) await _berurutan(() => _tulis(const []));
  }

  /// Baca-tulis berkas dijalankan satu per satu, supaya dua error yang muncul
  /// berdekatan tidak saling menimpa tampungannya.
  Future<void> _berurutan(Future<void> Function() kerja) {
    final berikut = _antrean.then((_) => kerja()).catchError((Object e) {
      debugPrint('Tampungan laporan error gagal: $e');
    });
    _antrean = berikut;
    return berikut;
  }

  Future<File> _file() async {
    final ada = _berkas;
    if (ada != null) return ada;
    final dir = await getApplicationSupportDirectory();
    return _berkas = File('${dir.path}/crash_reports.json');
  }

  Future<List<LaporanError>> _baca() async {
    try {
      final f = await _file();
      if (!await f.exists()) return const [];
      final isi = jsonDecode(await f.readAsString());
      if (isi is! List) return const [];
      return [for (final item in isi) LaporanError.fromJson(Map<String, dynamic>.from(item as Map))];
    } catch (_) {
      // Berkas rusak lebih baik dibuang daripada membuat pelapornya sendiri
      // terus gagal.
      return const [];
    }
  }

  Future<void> _tulis(List<LaporanError> isi) async {
    final f = await _file();
    await f.writeAsString(jsonEncode([for (final l in isi) l.toJson()]));
  }
}
