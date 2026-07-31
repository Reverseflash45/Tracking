import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/academic/presentation/academic_providers.dart';
import 'notification_service.dart';
import 'notification_settings_controller.dart';

/// Menjadwalkan ulang pengingat setiap kali daftar tugas atau setelan berubah.
///
/// Dibuat sebagai provider (bukan `ref.listen` di widget) supaya efeknya ikut
/// berjalan ulang saat dependensinya berubah — mis. user menggeser jam
/// pengingat, atau menandai sebuah tugas selesai.
///
/// Di web fungsi ini berhenti sebelum menyentuh [tasksProvider], jadi perilaku
/// caching di Chrome sama sekali tidak berubah.
final reminderSyncProvider = Provider<void>((ref) {
  final service = ref.watch(notificationServiceProvider);
  if (!service.supported) return;

  final settings = ref.watch(notificationSettingsProvider);
  final tasks = ref.watch(tasksProvider).value;
  if (tasks == null) return;

  unawaited(
    service.syncTaskReminders(
      tasks,
      aktif: settings.aktif,
      menitDalamHari: settings.menitDalamHari,
    ),
  );
});
