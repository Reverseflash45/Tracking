import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../features/academic/data/models/task.dart';

/// Berapa hari sebelum deadline pengingat dikirim. H-0 = hari-H.
const List<int> kReminderOffsetDays = [7, 3, 1, 0];

/// Android membatasi jumlah alarm terjadwal per aplikasi. Dengan 4 pengingat
/// per tugas, 50 tugas = 200 alarm — masih jauh di bawah batas.
const int kMaxTasksToSchedule = 50;

const _androidChannelId = 'deadline_reminders';
const _androidChannelName = 'Pengingat Deadline';

const _notificationDetails = NotificationDetails(
  android: AndroidNotificationDetails(
    _androidChannelId,
    _androidChannelName,
    channelDescription: 'Pengingat H-7, H-3, H-1, dan hari-H sebelum deadline tugas',
    importance: Importance.high,
    priority: Priority.high,
  ),
  iOS: DarwinNotificationDetails(),
);

/// Penjadwal pengingat deadline lokal (tanpa server).
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
      final granted = await android.requestNotificationsPermission() ?? false;
      // Izin alarm presisi opsional: kalau ditolak, penjadwalan tetap jalan
      // dengan mode inexact (lihat _scheduleMode).
      await android.requestExactAlarmsPermission();
      return granted;
    }

    final darwin = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (darwin != null) {
      return await darwin.requestPermissions(alert: true, badge: true, sound: true) ?? false;
    }

    return true;
  }

  /// Hapus semua jadwal lama lalu pasang ulang dari daftar tugas terkini.
  ///
  /// Menjadwalkan ulang seluruhnya (bukan diff) karena jumlahnya kecil dan ini
  /// menghindari perlu melacak pengingat mana yang sudah/belum terpasang.
  Future<void> syncTaskReminders(
    List<AcademicTask> tasks, {
    required bool aktif,
    required int menitDalamHari,
  }) async {
    if (!supported) return;
    await init();

    await _plugin.cancelAll();
    if (!aktif) return;

    final now = tz.TZDateTime.now(tz.local);

    final pending = tasks.where((task) => !task.isDone && task.deadline.isAfter(now)).toList()
      ..sort((a, b) => a.deadline.compareTo(b.deadline));

    for (final task in pending.take(kMaxTasksToSchedule)) {
      for (var i = 0; i < kReminderOffsetDays.length; i++) {
        final offset = kReminderOffsetDays[i];
        final deadline = task.deadline;
        final hari = DateTime(deadline.year, deadline.month, deadline.day)
            .subtract(Duration(days: offset));

        final waktu = tz.TZDateTime(
          tz.local,
          hari.year,
          hari.month,
          hari.day,
          menitDalamHari ~/ 60,
          menitDalamHari % 60,
        );

        // Lewati pengingat yang waktunya sudah lewat.
        if (!waktu.isAfter(now)) continue;

        await _plugin.zonedSchedule(
          id: _notificationId(task.id, i),
          title: _judul(offset),
          body: _isi(task, offset),
          scheduledDate: waktu,
          notificationDetails: _notificationDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    }
  }

  Future<void> showTestNotification() async {
    if (!supported) return;
    await init();
    await _plugin.show(
      id: 0,
      title: 'Pengingat aktif',
      body: 'Beginilah tampilan pengingat deadline nanti.',
      notificationDetails: _notificationDetails,
    );
  }

  Future<void> cancelAll() async {
    if (!supported) return;
    await _plugin.cancelAll();
  }

  /// ID notifikasi harus muat di int32 dan unik per (tugas, offset).
  /// Mask 0x0FFFFFFF menjaga hasil kali tetap positif dan di bawah 2^31.
  static int _notificationId(String taskId, int offsetIndex) =>
      ((taskId.hashCode & 0x00FFFFFF) * kReminderOffsetDays.length) + offsetIndex;

  static String _judul(int offset) => switch (offset) {
        0 => 'Deadline hari ini!',
        1 => 'Deadline besok',
        _ => 'Deadline $offset hari lagi',
      };

  static String _isi(AcademicTask task, int offset) {
    final matkul = task.courseName;
    final suffix = (matkul != null && matkul.trim().isNotEmpty) ? ' ($matkul)' : '';
    return switch (offset) {
      0 => '${task.title}$suffix jatuh tempo hari ini.',
      _ => '${task.title}$suffix menunggu diselesaikan.',
    };
  }
}

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(FlutterLocalNotificationsPlugin());
});
