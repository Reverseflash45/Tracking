import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'smart_reminders.dart';

/// Tiap jenis pengingat punya kanal Android sendiri.
///
/// Bukan sekadar rapi: kanal terpisah membuat kamu bisa membisukan "catat
/// makan" langsung dari setelan HP tanpa ikut membisukan pengingat deadline.
/// Satu kanal untuk semuanya memaksa pilihan semua-atau-tidak sama sekali.
String _channelId(ReminderKind kind) => 'reminder_${kind.name}';

String _channelDescription(ReminderKind kind) => switch (kind) {
      ReminderKind.deadline => 'Pengingat H-7, H-3, H-1, dan hari-H sebelum deadline tugas',
      ReminderKind.kelas => 'Pengingat beberapa menit sebelum kelas dimulai',
      ReminderKind.streak => 'Pengingat malam hari kalau belum ada catatan olahraga',
      ReminderKind.tagihan => 'Pengingat sehari sebelum pengeluaran rutin jatuh tempo',
      ReminderKind.catatMakan => 'Pengingat mencatat makanan di penghujung hari',
    };

NotificationDetails _detailsFor(ReminderKind kind) => NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId(kind),
        kind.label,
        channelDescription: _channelDescription(kind),
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: const DarwinNotificationDetails(),
    );

/// Penjadwal pengingat lokal (tanpa server).
///
/// Di web seluruh method penjadwalan langsung keluar: plugin-nya memang punya
/// dukungan web lewat Notifications API, tapi hanya berjalan selama tab
/// terbuka — tidak ada gunanya untuk pengingat H-7. App tetap jalan normal di
/// Chrome, bagian ini saja yang jadi no-op.
class NotificationService {
  NotificationService(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  bool _initialized = false;

  bool get supported => !kIsWeb;

  Future<void> init() async {
    if (!supported || _initialized) return;

    tz_data.initializeTimeZones();
    // Tanpa ini tz.local = UTC dan pengingat akan meleset 7 jam di WIB.
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));
    }

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );

    _initialized = true;
  }

  /// Minta izin notifikasi. Mengembalikan true kalau diizinkan (atau tidak
  /// perlu izin di platform ini).
  Future<bool> requestPermission() async {
    if (!supported) return false;
    await init();

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      // Sengaja tidak meminta izin alarm presisi: penjadwalan memakai mode
      // inexact, dan requestExactAlarmsPermission() akan melempar user ke
      // layar setelan sistem untuk izin yang tidak kita pakai.
      return await android.requestNotificationsPermission() ?? false;
    }

    final darwin = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (darwin != null) {
      return await darwin.requestPermissions(alert: true, badge: true, sound: true) ?? false;
    }

    return true;
  }

  /// Hapus semua jadwal lama lalu pasang ulang seluruh rencana.
  ///
  /// Menjadwalkan ulang seluruhnya (bukan diff) karena jumlahnya kecil dan ini
  /// menghindari perlu melacak pengingat mana yang sudah/belum terpasang.
  /// Karena semuanya dibatalkan dulu, id cukup diberi berurutan — tidak ada
  /// jadwal lama tersisa yang bisa tertimpa.
  Future<void> syncReminders(List<PlannedReminder> reminders) async {
    if (!supported) return;
    await init();

    await _plugin.cancelAll();
    if (reminders.isEmpty) return;

    final now = tz.TZDateTime.now(tz.local);

    for (var i = 0; i < reminders.length; i++) {
      final reminder = reminders[i];
      final waktu = tz.TZDateTime.from(reminder.waktu, tz.local);
      if (!waktu.isAfter(now)) continue;

      await _plugin.zonedSchedule(
        id: i + 1,
        title: reminder.judul,
        body: reminder.isi,
        scheduledDate: waktu,
        notificationDetails: _detailsFor(reminder.kind),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  Future<void> showTestNotification() async {
    if (!supported) return;
    await init();
    await _plugin.show(
      id: 0,
      title: 'Pengingat aktif',
      body: 'Beginilah tampilan pengingat nanti.',
      notificationDetails: _detailsFor(ReminderKind.deadline),
    );
  }

  Future<void> cancelAll() async {
    if (!supported) return;
    await _plugin.cancelAll();
  }
}

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(FlutterLocalNotificationsPlugin());
});
