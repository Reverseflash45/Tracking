import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import '../../../core/offline/pending_writes.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../../routine/domain/berkala.dart' show uuidBaru;
import 'nutrition_repository.dart';

/// Kunci data widget "Catat cepat". Sama dengan KUNCI_DATA di
/// CatatCepatWidget.kt.
const String kKunciCatatCepat = 'catat_cepat_widget';

/// Host URI tombol air. Sama dengan HOST_AIR di CatatCepatWidget.kt.
const String kHostCatatAir = 'catat-air';

const String _kWidgetAndroid = 'CatatCepatWidget';

String _tanggal(DateTime date) => date.toIso8601String().substring(0, 10);

/// Isi widget: siapa yang login dan berapa ml diminum hari ini.
///
/// [userId] null berarti belum login — tombol airnya lalu tidak mencatat apa
/// pun, dan widget hanya bertuliskan "Catat cepat".
@visibleForTesting
String dataWidgetCatat({required String? userId, required DateTime hariIni, required int ml}) {
  return jsonEncode({
    'u': ?userId,
    'tanggal': _tanggal(hariIni),
    'ml': ml,
  });
}

/// Tambah [ml] ke angka di widget tanpa menunggu app dibuka. Angka hari
/// sebelumnya dibuang.
@visibleForTesting
String tambahAirDiWidget(String data, int ml, DateTime sekarang) {
  final json = Map<String, dynamic>.from(jsonDecode(data) as Map);
  final hariIni = _tanggal(sekarang);
  final lama = json['tanggal'] == hariIni ? (json['ml'] as num? ?? 0).toInt() : 0;
  json['tanggal'] = hariIni;
  json['ml'] = lama + ml;
  return jsonEncode(json);
}

/// Menjaga isi widget tetap sama dengan catatan minum di app.
final catatCepatWidgetSyncProvider = Provider<void>((ref) {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;

  final userId = ref.watch(currentUserProvider)?.id;
  final hariIni = DateTime.now();
  var ml = 0;
  if (userId != null) {
    final waters = ref.watch(waterLogsProvider).value;
    // Belum termuat: jangan menimpa angka yang mungkin sudah ditambah tombol
    // widget dengan nol.
    if (waters == null) return;
    for (final w in waters) {
      if (_tanggal(w.loggedOn) == _tanggal(hariIni)) ml += w.ml;
    }
  }

  unawaited(_kirim(dataWidgetCatat(userId: userId, hariIni: hariIni, ml: ml)));
});

String? _terakhirDikirim;

Future<void> _kirim(String data) async {
  if (data == _terakhirDikirim) return;
  try {
    await HomeWidget.saveWidgetData<String>(kKunciCatatCepat, data);
    await HomeWidget.updateWidget(androidName: _kWidgetAndroid);
    _terakhirDikirim = data;
  } catch (e) {
    debugPrint('Widget catat cepat gagal diperbarui: $e');
  }
}

/// Tombol "+ Air" di widget, dijalankan di latar tanpa membuka app.
///
/// Sama seperti tombol "Sudah" di notifikasi: hanya menulis ke antrean
/// offline, tidak menyentuh sesi login (lihat [PendingWriteQueue.lokal]).
/// App mengirimnya ke server begitu dibuka.
Future<void> catatAirDariWidget(Uri uri) async {
  final ml = int.tryParse(uri.queryParameters['ml'] ?? '');
  if (ml == null || ml <= 0 || ml > 2000) return;

  WidgetsFlutterBinding.ensureInitialized();
  try {
    final data = await HomeWidget.getWidgetData<String>(kKunciCatatCepat);
    if (data == null) return;
    final userId = (jsonDecode(data) as Map)['u'];
    if (userId is! String) return;

    final sekarang = DateTime.now();
    await PendingWriteQueue.lokal().antrekan(
      table: 'water_logs',
      payload: {
        'id': uuidBaru(),
        'user_id': userId,
        'logged_on': _tanggal(sekarang),
        'logged_at': sekarang.toUtc().toIso8601String(),
        'ml': ml,
      },
      label: 'Minum $ml ml',
    );

    final baru = tambahAirDiWidget(data, ml, sekarang);
    await HomeWidget.saveWidgetData<String>(kKunciCatatCepat, baru);
    _terakhirDikirim = baru;
    await HomeWidget.updateWidget(androidName: _kWidgetAndroid);
  } catch (e) {
    debugPrint('Tombol air di widget gagal: $e');
  }
}
