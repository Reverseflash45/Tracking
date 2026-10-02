/// Cek versi terbaru di GitHub Releases.
///
/// App ini dibagikan lewat GitHub, bukan Play Store, jadi tidak ada yang
/// memberi tahu pengguna kalau ada versi baru. Pemeriksaan ini memakai API
/// publik GitHub — tanpa token, tanpa server sendiri.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String kRepoGithub = 'Reverseflash45/Tracking';

/// Jarak minimal antar pemeriksaan otomatis. API publik GitHub membatasi 60
/// permintaan per jam per IP, dan versi baru paling sering keluar beberapa
/// hari sekali — memeriksa tiap kali app dibuka cuma membuang kuota.
const Duration kJedaCekUpdate = Duration(hours: 12);

const _cekTerakhirKey = 'update_last_check';
const _lewatiKey = 'update_skipped_version';

/// Versi semantik sederhana: "1.2.0", "v1.10.3". Bagian di luar angka (mis.
/// "-beta") diabaikan; rilis app ini memang tidak memakainya.
List<int>? bacaVersi(String teks) {
  final cocok = RegExp(r'(\d+)\.(\d+)\.(\d+)').firstMatch(teks);
  if (cocok == null) return null;
  return [for (var i = 1; i <= 3; i++) int.parse(cocok.group(i)!)];
}

/// True kalau [baru] lebih tinggi dari [sekarang]. Versi yang tidak bisa
/// dibaca tidak pernah dianggap lebih baru.
bool lebihBaru(String baru, String sekarang) {
  final a = bacaVersi(baru);
  final b = bacaVersi(sekarang);
  if (a == null || b == null) return false;
  for (var i = 0; i < 3; i++) {
    if (a[i] != b[i]) return a[i] > b[i];
  }
  return false;
}

class InfoRilis {
  const InfoRilis({
    required this.versi,
    required this.judul,
    required this.catatan,
    required this.halaman,
    this.apkArm64,
  });

  /// Tanpa awalan "v", misal "1.3.0".
  final String versi;
  final String judul;
  final String catatan;

  /// Halaman rilis di GitHub — di sana kamu memilih APK yang cocok.
  final String halaman;

  /// Tautan langsung APK arm64, kalau ada.
  final String? apkArm64;

  static InfoRilis? fromGithub(Map<String, dynamic> json) {
    if (json['draft'] == true || json['prerelease'] == true) return null;
    final tag = json['tag_name'] as String?;
    final halaman = json['html_url'] as String?;
    if (tag == null || halaman == null || bacaVersi(tag) == null) return null;

    String? arm64;
    for (final aset in (json['assets'] as List? ?? const [])) {
      if (aset is! Map) continue;
      final nama = aset['name'] as String? ?? '';
      if (nama.endsWith('.apk') && nama.contains('arm64')) {
        arm64 = aset['browser_download_url'] as String?;
      }
    }

    return InfoRilis(
      versi: tag.startsWith('v') ? tag.substring(1) : tag,
      judul: (json['name'] as String?)?.trim().isNotEmpty == true ? json['name'] as String : tag,
      catatan: (json['body'] as String?)?.trim() ?? '',
      halaman: halaman,
      apkArm64: arm64,
    );
  }
}

/// Hasil satu pemeriksaan.
class HasilCekUpdate {
  const HasilCekUpdate({required this.versiSekarang, this.rilisBaru});

  final String versiSekarang;

  /// Null kalau sudah versi terbaru (atau pemeriksaannya gagal).
  final InfoRilis? rilisBaru;
}

class UpdateChecker {
  UpdateChecker({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Versi yang sedang terpasang, misal "1.2.0".
  Future<String> versiTerpasang() async => (await PackageInfo.fromPlatform()).version;

  /// Periksa sekarang. Gagal jaringan bukan error yang perlu ditampilkan —
  /// hasilnya cukup "tidak ada versi baru".
  Future<HasilCekUpdate> cek() async {
    final sekarang = await versiTerpasang();
    try {
      final res = await _client
          .get(
            Uri.parse('https://api.github.com/repos/$kRepoGithub/releases/latest'),
            headers: const {'Accept': 'application/vnd.github+json'},
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return HasilCekUpdate(versiSekarang: sekarang);

      final rilis = InfoRilis.fromGithub(jsonDecode(res.body) as Map<String, dynamic>);
      if (rilis == null || !lebihBaru(rilis.versi, sekarang)) {
        return HasilCekUpdate(versiSekarang: sekarang);
      }
      return HasilCekUpdate(versiSekarang: sekarang, rilisBaru: rilis);
    } catch (e) {
      debugPrint('Cek update gagal: $e');
      return HasilCekUpdate(versiSekarang: sekarang);
    }
  }

  /// Pemeriksaan otomatis saat app dibuka: dibatasi [kJedaCekUpdate], dan
  /// versi yang sudah kamu tolak ("Nanti saja") tidak ditawarkan lagi.
  Future<InfoRilis?> cekOtomatis({DateTime? now}) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;

    final prefs = await SharedPreferences.getInstance();
    final waktu = now ?? DateTime.now();
    final terakhir = prefs.getInt(_cekTerakhirKey);
    if (terakhir != null &&
        waktu.difference(DateTime.fromMillisecondsSinceEpoch(terakhir)) < kJedaCekUpdate) {
      return null;
    }
    await prefs.setInt(_cekTerakhirKey, waktu.millisecondsSinceEpoch);

    final rilis = (await cek()).rilisBaru;
    if (rilis == null || prefs.getString(_lewatiKey) == rilis.versi) return null;
    return rilis;
  }

  /// "Nanti saja": versi ini tidak ditawarkan otomatis lagi. Versi berikutnya
  /// tetap ditawarkan, dan cek manual di Profil tetap menampilkannya.
  Future<void> lewati(String versi) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lewatiKey, versi);
  }
}

final updateCheckerProvider = Provider<UpdateChecker>((ref) => UpdateChecker());

/// Versi terpasang, untuk ditampilkan di Profil.
final versiAppProvider = FutureProvider<String>((ref) {
  return ref.watch(updateCheckerProvider).versiTerpasang();
});

/// Ringkas catatan rilis Markdown jadi beberapa baris teks biasa untuk dialog.
String ringkasCatatan(String markdown, {int maksBaris = 8}) {
  final baris = <String>[];
  for (final mentah in const LineSplitter().convert(markdown)) {
    var b = mentah.trim();
    if (b.isEmpty) continue;
    if (b.startsWith('**Pasang')) break;
    b = b.replaceAll('**', '').replaceAll('`', '');
    if (b.startsWith('- ')) b = '• ${b.substring(2)}';
    baris.add(b);
    if (baris.length >= maksBaris) break;
  }
  return baris.join('\n');
}
