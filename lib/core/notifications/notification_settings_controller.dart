import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notification_service.dart';

const _aktifPrefsKey = 'reminder_enabled';
const _menitPrefsKey = 'reminder_minute_of_day';

/// Default jam 08.00 — cukup pagi untuk masih sempat mengerjakan.
const int kDefaultReminderMinute = 8 * 60;

@immutable
class NotificationSettings {
  const NotificationSettings({required this.aktif, required this.menitDalamHari});

  final bool aktif;

  /// Menit dari tengah malam, mis. 480 = 08:00.
  final int menitDalamHari;

  TimeOfDay get jam => TimeOfDay(hour: menitDalamHari ~/ 60, minute: menitDalamHari % 60);

  NotificationSettings copyWith({bool? aktif, int? menitDalamHari}) => NotificationSettings(
        aktif: aktif ?? this.aktif,
        menitDalamHari: menitDalamHari ?? this.menitDalamHari,
      );

  @override
  bool operator ==(Object other) =>
      other is NotificationSettings &&
      other.aktif == aktif &&
      other.menitDalamHari == menitDalamHari;

  @override
  int get hashCode => Object.hash(aktif, menitDalamHari);
}

class NotificationSettingsController extends Notifier<NotificationSettings> {
  @override
  NotificationSettings build() {
    _restore();
    return const NotificationSettings(aktif: false, menitDalamHari: kDefaultReminderMinute);
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    state = NotificationSettings(
      aktif: prefs.getBool(_aktifPrefsKey) ?? false,
      menitDalamHari: prefs.getInt(_menitPrefsKey) ?? kDefaultReminderMinute,
    );
  }

  /// Menyalakan pengingat butuh izin sistem dulu; kalau ditolak, state tetap
  /// mati supaya tampilan tidak menjanjikan sesuatu yang tidak akan muncul.
  /// Mengembalikan status akhir.
  Future<bool> setAktif(bool value) async {
    if (value) {
      final granted = await ref.read(notificationServiceProvider).requestPermission();
      if (!granted) return false;
    }

    state = state.copyWith(aktif: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_aktifPrefsKey, value);
    return value;
  }

  Future<void> setJam(TimeOfDay jam) async {
    final menit = jam.hour * 60 + jam.minute;
    state = state.copyWith(menitDalamHari: menit);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_menitPrefsKey, menit);
  }
}

final notificationSettingsProvider =
    NotifierProvider<NotificationSettingsController, NotificationSettings>(
  NotificationSettingsController.new,
);
