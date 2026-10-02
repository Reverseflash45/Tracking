import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import '../../academic/data/models/class_schedule.dart';
import '../../academic/presentation/academic_providers.dart';
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
String dataWidgetRutinitas({
  required List<RutinitasBerkala> berkala,
  required List<RoutineItem> rutinitas,
  required List<ClassSchedule> jadwal,
}) {
  return jsonEncode({
    'berkala': [
      for (final r in urutkanBerkala(berkala)) {'t': r.title, 'd': _tanggal(r.jatuhTempo)},
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

  unawaited(_kirim(dataWidgetRutinitas(berkala: berkala, rutinitas: rutinitas, jadwal: jadwal)));
});

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
