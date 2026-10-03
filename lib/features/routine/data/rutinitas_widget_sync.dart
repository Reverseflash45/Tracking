import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import '../../../core/notifications/notification_service.dart';
import '../../../core/notifications/notification_settings_controller.dart';
import '../../academic/data/models/class_schedule.dart';
import '../../academic/presentation/academic_providers.dart';
import '../../nutrition/data/catat_cepat_widget.dart';
import '../domain/berkala.dart';
import '../domain/routine.dart';
import 'berkala_repository.dart';
import 'routine_repository.dart';

/// Kunci data widget. Harus sama dengan `KUNCI_DATA` di RutinitasWidget.kt.
const String kKunciWidget = 'rutinitas_widget';

/// Nama kelas provider widget di Android.
const String _kWidgetAndroid = 'RutinitasWidget';

String _tanggal(DateTime date) => date.toIso8601String().substring(0, 10);

/// Data mentah untuk widget layar utama.
///
/// Sengaja bukan teks jadi: widget memperbarui dirinya sendiri tiap beberapa
/// jam tanpa app, jadi "Hari ini" / "Besok" dihitung di sisi widget dari
/// tanggal jatuh temponya.
///
/// Tiap rutinitas berkala membawa payload yang sama dengan notifikasinya
/// (`p`), supaya tombol "Sudah" di widget bisa mencatat selesai tanpa membuka
/// app — persis seperti tombol di notifikasi. [menitPengingatUmum] dipakai
/// untuk pengingat siklus berikutnya kalau rutinitasnya tidak punya jam sendiri.
String dataWidgetRutinitas({
  required List<RutinitasBerkala> berkala,
  required List<RoutineItem> rutinitas,
  required List<ClassSchedule> jadwal,
  int menitPengingatUmum = 8 * 60,
}) {
  return jsonEncode({
    'berkala': [
      for (final r in urutkanBerkala(berkala))
        {
          't': r.title,
          'd': _tanggal(r.jatuhTempo),
          'p': PayloadBerkala(
            routineId: r.id,
            userId: r.userId,
            title: r.title,
            intervalDays: r.intervalDays,
            menitPengingat: r.remindAt == null ? menitPengingatUmum : menitDariJam(r.remindAt!),
          ).encode(),
        },
    ],
    'harian': {
      for (var hari = 1; hari <= 7; hari++)
        '$hari': [
          for (final b in lineMasaHarian(hari: hari, rutinitas: rutinitas, jadwal: jadwal))
            {'m': b.mulai, 't': b.judul},
        ],
    },
  });
}

/// Mengirim ulang isi widget setiap kali rutinitasnya berubah. Hanya Android —
/// widget iOS butuh target Xcode tersendiri yang belum ada.
final rutinitasWidgetSyncProvider = Provider<void>((ref) {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;

  // Tunggu dua sumber utama termuat, supaya widget tidak sempat dikosongkan
  // oleh daftar yang sebenarnya cuma belum selesai dimuat.
  final berkala = ref.watch(berkalaProvider).value;
  final rutinitas = ref.watch(routinesProvider).value;
  if (berkala == null || rutinitas == null) return;
  final jadwal = ref.watch(classSchedulesProvider).value ?? const <ClassSchedule>[];
  final menit = ref.watch(notificationSettingsProvider).menitDalamHari;

  unawaited(_kirim(dataWidgetRutinitas(
    berkala: berkala,
    rutinitas: rutinitas,
    jadwal: jadwal,
    menitPengingatUmum: menit,
  )));
});

/// Isi widget setelah [routineId] ditandai selesai pada [now]: jatuh temponya
/// maju satu siklus dan urutannya disusun ulang. Data lain tidak disentuh.
///
/// Dipakai tombol "Sudah" di widget, yang berjalan tanpa app — tidak ada data
/// segar dari server, jadi widget menyesuaikan isinya sendiri sampai app
/// dibuka dan mengirim data lengkap.
String majukanDiWidget(String data, String routineId, DateTime now) {
  final json = jsonDecode(data) as Map<String, dynamic>;
  final hariIni = DateTime(now.year, now.month, now.day);
  final daftar = [
    for (final item in (json['berkala'] as List? ?? const []))
      Map<String, dynamic>.from(item as Map),
  ];
  for (final item in daftar) {
    final payload = PayloadBerkala.decode(item['p'] as String?);
    if (payload?.routineId == routineId) {
      item['d'] = _tanggal(hariIni.add(Duration(days: payload!.intervalDays)));
    }
  }
  daftar.sort((a, b) {
    final d = (a['d'] as String).compareTo(b['d'] as String);
    return d != 0 ? d : (a['t'] as String).compareTo(b['t'] as String);
  });
  json['berkala'] = daftar;
  return jsonEncode(json);
}

/// Host URI tombol "Sudah" di widget. Harus sama dengan RutinitasWidget.kt.
const String _kHostSelesai = 'berkala-selesai';

/// Pasang penanggap tombol di widget. Dipanggil sekali saat app mulai.
Future<void> daftarkanAksiWidget() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  try {
    await HomeWidget.registerInteractivityCallback(tanggapiWidget);
  } catch (e) {
    debugPrint('Gagal mendaftarkan aksi widget: $e');
  }
}

/// Dipanggil Android saat tombol "Sudah" di widget ditekan, di isolate latar
/// tanpa app. Jalurnya sama dengan tombol di notifikasi.
@pragma('vm:entry-point')
Future<void> tanggapiWidget(Uri? uri) async {
  // Satu callback untuk semua widget: home_widget hanya menyimpan satu.
  if (uri?.host == kHostCatatAir) return catatAirDariWidget(uri!);
  if (uri == null || uri.host != _kHostSelesai) return;
  final payload = PayloadBerkala.decode(uri.queryParameters['p']);
  if (payload == null) return;

  WidgetsFlutterBinding.ensureInitialized();
  final now = DateTime.now();
  try {
    await catatSelesaiDariNotifikasi(payload, FlutterLocalNotificationsPlugin(), sekarang: now);

    final data = await HomeWidget.getWidgetData<String>(kKunciWidget);
    if (data != null) {
      await HomeWidget.saveWidgetData<String>(
        kKunciWidget,
        majukanDiWidget(data, payload.routineId, now),
      );
      await HomeWidget.updateWidget(androidName: _kWidgetAndroid);
    }
  } catch (e) {
    debugPrint('Tombol "Sudah" di widget gagal: $e');
  }
}

String? _terakhirDikirim;

Future<void> _kirim(String data) async {
  if (data == _terakhirDikirim) return;
  try {
    await HomeWidget.saveWidgetData<String>(kKunciWidget, data);
    await HomeWidget.updateWidget(androidName: _kWidgetAndroid);
    _terakhirDikirim = data;
  } catch (e) {
    // Widget hanya pelengkap; gagal memperbaruinya tidak boleh mengganggu app.
    debugPrint('Widget rutinitas gagal diperbarui: $e');
  }
}
