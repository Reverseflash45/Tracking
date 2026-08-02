import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notification_service.dart';
import 'smart_reminders.dart';

const _aktifPrefsKey = 'reminder_enabled';
const _menitPrefsKey = 'reminder_minute_of_day';
const _jenisPrefsKey = 'reminder_kinds';
const _sebelumKelasPrefsKey = 'reminder_minutes_before_class';

/// Default jam 08.00 — cukup pagi untuk masih sempat mengerjakan.
const int kDefaultReminderMinute = 8 * 60;

/// Jenis yang menyala kalau user belum pernah memilih apa pun.
///
/// "Catat makan" tidak termasuk: itu satu-satunya yang menegur soal kebiasaan
/// mencatat, bukan soal kejadian nyata yang akan kamu lewatkan.
const Set<ReminderKind> kDefaultReminderKinds = {
  ReminderKind.deadline,
  ReminderKind.kelas,
  ReminderKind.streak,
  ReminderKind.tagihan,
};

class NotificationSettingsController extends Notifier<NotificationSettings> {
  @override
  NotificationSettings build() {
    _restore();
    return const NotificationSettings(
      aktif: false,
      menitDalamHari: kDefaultReminderMinute,
      jenisAktif: kDefaultReminderKinds,
    );
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final tersimpan = prefs.getStringList(_jenisPrefsKey);

    state = NotificationSettings(
      aktif: prefs.getBool(_aktifPrefsKey) ?? false,
      menitDalamHari: prefs.getInt(_menitPrefsKey) ?? kDefaultReminderMinute,
      // Daftar kosong yang memang disimpan user berbeda artinya dari "belum
      // pernah memilih" — yang pertama harus tetap kosong.
      jenisAktif: tersimpan == null ? kDefaultReminderKinds : _parseJenis(tersimpan),
      menitSebelumKelas: prefs.getInt(_sebelumKelasPrefsKey) ?? kMenitSebelumKelasDefault,
    );
  }

  /// Nama jenis yang tidak dikenal (mis. sisa versi lama) diabaikan diam-diam.
  static Set<ReminderKind> _parseJenis(List<String> names) {
    final byName = {for (final kind in ReminderKind.values) kind.name: kind};
    return {
      for (final name in names)
        if (byName[name] != null) byName[name]!,
    };
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

  Future<void> setJenis(ReminderKind kind, bool nyala) async {
    final jenis = {...state.jenisAktif};
    if (nyala) {
      jenis.add(kind);
    } else {
      jenis.remove(kind);
    }

    state = state.copyWith(jenisAktif: jenis);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_jenisPrefsKey, jenis.map((k) => k.name).toList());
  }

  Future<void> setMenitSebelumKelas(int menit) async {
    state = state.copyWith(menitSebelumKelas: menit);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_sebelumKelasPrefsKey, menit);
  }
}

final notificationSettingsProvider =
    NotifierProvider<NotificationSettingsController, NotificationSettings>(
  NotificationSettingsController.new,
);
