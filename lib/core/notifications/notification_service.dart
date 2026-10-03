import 'dart:async';
import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../features/routine/data/berkala_repository.dart' show barisLogBerkala;
import '../../features/routine/domain/berkala.dart';
import '../offline/pending_writes.dart';
import 'smart_reminders.dart';

/// Id tombol "Sudah" di notifikasi rutinitas berkala.
const String kAksiSelesai = 'selesai';

/// Kategori iOS yang membawa tombol "Sudah". Di Android tombolnya menempel
/// langsung di notifikasinya.
const String _kategoriBerkala = 'berkala';

/// Id notifikasi yang dipasang dari luar app (tombol "Sudah"). Jauh di atas
/// id yang dipakai [NotificationService.syncReminders] (1..kMaxReminders),
/// supaya tidak saling menimpa sebelum app dibuka dan semuanya disusun ulang.
const int _kIdLatarAwal = 100000;

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
      ReminderKind.dokumen =>
        'Pengingat H-60, H-14, dan hari-H sebelum masa berlaku dokumen habis',
      ReminderKind.kendaraan =>
        'Pengingat jadwal servis, pajak tahunan, dan ganti plat kendaraan',
      ReminderKind.catatMakan => 'Pengingat mencatat makanan di penghujung hari',
      ReminderKind.berkala =>
        'Pengingat rutinitas tiap beberapa hari, diulang sampai ditandai selesai',
      ReminderKind.rekapMingguan =>
        'Ringkasan latihan, tidur, dan pengeluaran tiap Minggu malam',
    };

/// Tag Android untuk notifikasi milik satu rutinitas berkala. Dipakai mencari
/// notifikasi yang masih tampil di laci notifikasi — Android tidak
/// mengembalikan payload untuk itu, hanya tag.
String _tagBerkala(String routineId) => 'berkala:$routineId';

NotificationDetails _detailsFor(ReminderKind kind, {String? tag, String? isi}) {
  final berkala = kind == ReminderKind.berkala;
  return NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId(kind),
      kind.label,
      channelDescription: _channelDescription(kind),
      // Isi yang panjang (rekap mingguan, deadline dengan nama matkul) tetap
      // terbaca utuh saat notifikasinya dibentangkan.
      styleInformation: isi == null ? null : BigTextStyleInformation(isi),
      importance: Importance.high,
      priority: Priority.high,
      tag: tag,
      actions: berkala
          ? const [
              // Tanpa membuka app: tombol ini cukup mencatat lalu hilang.
              AndroidNotificationAction(kAksiSelesai, 'Sudah', cancelNotification: true),
            ]
          : null,
    ),
    iOS: DarwinNotificationDetails(categoryIdentifier: berkala ? _kategoriBerkala : null),
  );
}

final _initializationSettings = InitializationSettings(
  android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
  iOS: DarwinInitializationSettings(
    notificationCategories: [
      DarwinNotificationCategory(
        _kategoriBerkala,
        actions: [DarwinNotificationAction.plain(kAksiSelesai, 'Sudah')],
      ),
    ],
  ),
);

/// Kabar untuk app yang sedang terbuka: notifikasi diketuk, atau tombol
/// "Sudah" ditekan. App shell mendengarkannya untuk pindah halaman dan
/// memuat ulang data.
final StreamController<NotificationResponse> _responsDepan =
    StreamController<NotificationResponse>.broadcast();

Stream<NotificationResponse> get responsNotifikasi => _responsDepan.stream;

/// Dipanggil Android/iOS untuk tombol notifikasi saat app tidak berjalan di
/// depan. Berjalan di isolate terpisah: tidak ada provider, tidak ada sesi
/// login yang bisa diandalkan.
@pragma('vm:entry-point')
Future<void> tanggapiNotifikasiLatar(NotificationResponse respons) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  await _tanganiAksi(respons, FlutterLocalNotificationsPlugin());
}

Future<void> _tanggapiNotifikasiDepan(NotificationResponse respons) async {
  await _tanganiAksi(respons, FlutterLocalNotificationsPlugin());
  _responsDepan.add(respons);
}

Future<void> _tanganiAksi(
  NotificationResponse respons,
  FlutterLocalNotificationsPlugin plugin,
) async {
  if (respons.actionId != kAksiSelesai) return;
  final payload = PayloadBerkala.decode(respons.payload);
  if (payload == null) return;

  try {
    await catatSelesaiDariNotifikasi(payload, plugin);
  } catch (e) {
    debugPrint('Aksi "Sudah" dari notifikasi gagal: $e');
  }
}

/// Catat selesai dari tombol notifikasi, tanpa menyentuh jaringan.
///
/// Sengaja tidak login ke Supabase dari sini: kalau isolate ini dan app yang
/// sedang berjalan sama-sama me-refresh token, Supabase menganggap refresh
/// token-nya dipakai ulang dan bisa mencabut sesimu. Jadi catatannya masuk
/// antrean offline (terkirim begitu app dibuka), lalu yang benar-benar perlu
/// terjadi sekarang dikerjakan di HP: mematikan sisa pengingat telat dan
/// memasang pengingat siklus berikutnya.
Future<void> catatSelesaiDariNotifikasi(
  PayloadBerkala payload,
  FlutterLocalNotificationsPlugin plugin, {
  DateTime? sekarang,
}) async {
  final now = sekarang ?? DateTime.now();

  await PendingWriteQueue.lokal().antrekan(
    table: kTabelLogBerkala,
    payload: barisLogBerkala(
      logId: uuidBaru(),
      routineId: payload.routineId,
      userId: payload.userId,
      doneOn: now,
    ),
    label: payload.title,
  );

  final service = NotificationService(plugin);
  await service.init();
  await service.batalkanPengingatBerkala(payload.routineId);
  await service.pasangSiklusBerikutnya(payload, now);
}

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

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

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
      settings: _initializationSettings,
      onDidReceiveNotificationResponse: _tanggapiNotifikasiDepan,
      onDidReceiveBackgroundNotificationResponse: tanggapiNotifikasiLatar,
    );

    _initialized = true;
  }

  /// Notifikasi yang membuka app dari keadaan tertutup, kalau ada.
  Future<NotificationResponse?> responsPembuka() async {
    if (!supported) return null;
    await init();
    final detail = await _plugin.getNotificationAppLaunchDetails();
    return (detail?.didNotificationLaunchApp ?? false) ? detail!.notificationResponse : null;
  }

  /// Minta izin notifikasi. Mengembalikan true kalau diizinkan (atau tidak
  /// perlu izin di platform ini).
  Future<bool> requestPermission() async {
    if (!supported) return false;
    await init();

    final android = _android;
    if (android != null) {
      // Izin alarm presisi tidak diminta di sini — itu pilihan terpisah di
      // Profil, karena di Android 14 memintanya berarti melempar kamu ke
      // layar setelan sistem.
      return await android.requestNotificationsPermission() ?? false;
    }

    final darwin = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (darwin != null) {
      return await darwin.requestPermissions(alert: true, badge: true, sound: true) ?? false;
    }

    return true;
  }

  /// Apakah alarm presisi diizinkan. Di luar Android selalu true — iOS tidak
  /// membedakannya.
  Future<bool> bisaAlarmTepat() async {
    if (!supported) return false;
    await init();
    final android = _android;
    if (android == null) return true;
    return await android.canScheduleExactNotifications() ?? false;
  }

  /// Buka layar izin "Alarm & pengingat" (Android 12+). Hasilnya baru
  /// diketahui setelah kamu kembali ke app.
  Future<void> mintaIzinAlarmTepat() async {
    if (!supported) return;
    await init();
    await _android?.requestExactAlarmsPermission();
  }

  /// Hapus semua jadwal lama lalu pasang ulang seluruh rencana.
  ///
  /// Menjadwalkan ulang seluruhnya (bukan diff) karena jumlahnya kecil dan ini
  /// menghindari perlu melacak pengingat mana yang sudah/belum terpasang.
  /// Karena semuanya dibatalkan dulu, id cukup diberi berurutan — tidak ada
  /// jadwal lama tersisa yang bisa tertimpa.
  ///
  /// [tepatWaktu] memakai alarm presisi kalau izinnya ada. Kalau tidak ada,
  /// diam-diam turun ke mode biasa: memasang alarm presisi tanpa izin
  /// membuat plugin melempar, dan satu kegagalan itu akan membatalkan
  /// seluruh pengingat lain.
  Future<void> syncReminders(
    List<PlannedReminder> reminders, {
    bool tepatWaktu = false,
  }) async {
    if (!supported) return;
    await init();

    await _plugin.cancelAll();
    if (reminders.isEmpty) return;

    final mode = tepatWaktu && await bisaAlarmTepat()
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
    final now = tz.TZDateTime.now(tz.local);

    for (var i = 0; i < reminders.length; i++) {
      final reminder = reminders[i];
      final waktu = tz.TZDateTime.from(reminder.waktu, tz.local);
      if (!waktu.isAfter(now)) continue;

      final berkala = PayloadBerkala.decode(reminder.payload);
      await _plugin.zonedSchedule(
        id: i + 1,
        title: reminder.judul,
        body: reminder.isi,
        scheduledDate: waktu,
        payload: reminder.payload,
        notificationDetails: _detailsFor(
          reminder.kind,
          tag: berkala == null ? null : _tagBerkala(berkala.routineId),
          isi: reminder.isi,
        ),
        androidScheduleMode: mode,
      );
    }
  }

  /// Batalkan semua pengingat milik satu rutinitas berkala — yang masih
  /// terjadwal maupun yang sudah tampil di laci notifikasi.
  Future<void> batalkanPengingatBerkala(String routineId) async {
    if (!supported) return;
    await init();

    final awalan = PayloadBerkala.awalanUntuk(routineId);
    for (final p in await _plugin.pendingNotificationRequests()) {
      if (p.payload?.startsWith(awalan) ?? false) {
        await _plugin.cancel(id: p.id);
      }
    }

    final tag = _tagBerkala(routineId);
    try {
      for (final n in await _plugin.getActiveNotifications()) {
        final id = n.id;
        if (id == null) continue;
        if (n.tag == tag || (n.payload?.startsWith(awalan) ?? false)) {
          await _plugin.cancel(id: id, tag: n.tag);
        }
      }
    } catch (_) {
      // Tidak semua platform mendukung daftar notifikasi aktif. Yang
      // terjadwal sudah dibatalkan di atas, dan itu yang terpenting.
    }
  }

  /// Pasang pengingat siklus berikutnya setelah ditandai selesai dari
  /// notifikasi.
  ///
  /// Tanpa ini, kalau kamu tidak membuka app sampai jatuh tempo berikutnya,
  /// tidak ada yang mengingatkan — rencana lengkapnya baru disusun ulang saat
  /// app dibuka. Sengaja cuma H-1 dan hari-H: begitu app dibuka, semuanya
  /// diganti rencana lengkap dari [syncReminders].
  Future<void> pasangSiklusBerikutnya(PayloadBerkala payload, DateTime now) async {
    if (!supported) return;
    await init();

    final hariIni = DateTime(now.year, now.month, now.day);
    final tempo = hariIni.add(Duration(days: payload.intervalDays));
    final jam = Duration(minutes: payload.menitPengingat);

    final rencana = <(DateTime, String, String)>[
      if (payload.intervalDays >= kMinJarakUntukHMinus1)
        (
          tempo.subtract(const Duration(days: 1)).add(jam),
          'Besok: ${payload.title}',
          'Jadwal tiap ${payload.intervalDays} hari. Siapkan dari sekarang.',
        ),
      (
        tempo.add(jam),
        '${payload.title} hari ini',
        'Sudah ${payload.intervalDays} hari sejak terakhir. Tandai selesai '
            'supaya hitungannya mulai lagi.',
      ),
    ];

    final dasar = _kIdLatarAwal + (payload.routineId.hashCode & 0xFFFF) * 2;
    final tzNow = tz.TZDateTime.now(tz.local);
    for (final (i, (waktu, judul, isi)) in rencana.indexed) {
      final jadwal = tz.TZDateTime.from(waktu, tz.local);
      if (!jadwal.isAfter(tzNow)) continue;
      await _plugin.zonedSchedule(
        id: dasar + i,
        title: judul,
        body: isi,
        scheduledDate: jadwal,
        payload: payload.encode(),
        notificationDetails: _detailsFor(
          ReminderKind.berkala,
          tag: _tagBerkala(payload.routineId),
        ),
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

/// Status izin alarm presisi. Di-invalidate saat kembali ke app, karena
/// izinnya diberikan di layar setelan sistem.
final izinAlarmTepatProvider = FutureProvider.autoDispose<bool>((ref) {
  return ref.watch(notificationServiceProvider).bisaAlarmTepat();
});
