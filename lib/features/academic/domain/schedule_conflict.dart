/// Deteksi jadwal kuliah yang waktunya bertabrakan.
///
/// Sebelum ini app diam saja waktu kamu memasukkan dua kelas di jam yang sama —
/// dan kamu baru tahu waktu sudah berdiri di depan pintu ruangan yang salah.
/// Penyebab paling sering bukan salah ketik, tapi import KRS yang dijalankan
/// dua kali.
library;

import '../data/models/class_schedule.dart';

/// Ubah 'HH:mm:ss' dari kolom `time` Postgres jadi menit dari tengah malam.
///
/// Format yang tidak terbaca dikembalikan sebagai null, bukan 0 — jam 00:00
/// adalah waktu yang sah dan tidak boleh tertukar dengan "gagal baca".
int? menitDariJam(String value) {
  final parts = value.split(':');
  if (parts.length < 2) return null;
  final jam = int.tryParse(parts[0]);
  final menit = int.tryParse(parts[1]);
  if (jam == null || menit == null) return null;
  if (jam < 0 || jam > 23 || menit < 0 || menit > 59) return null;
  return jam * 60 + menit;
}

/// Satu petak waktu di kalender mingguan.
class JadwalSlot {
  const JadwalSlot({
    required this.dayOfWeek,
    required this.mulai,
    required this.selesai,
    this.tanggal,
  });

  /// 1 = Senin ... 7 = Minggu.
  final int dayOfWeek;

  /// Menit dari tengah malam.
  final int mulai;
  final int selesai;

  /// Diisi hanya untuk PHL. Kalau ada, slot ini cuma berlaku di tanggal itu.
  final DateTime? tanggal;

  bool get isPhl => tanggal != null;

  /// Slot dari jadwal tersimpan. Null kalau jamnya tidak terbaca.
  static JadwalSlot? dari(ClassSchedule schedule) {
    final mulai = menitDariJam(schedule.startTime);
    final selesai = menitDariJam(schedule.endTime);
    if (mulai == null || selesai == null) return null;
    return JadwalSlot(
      dayOfWeek: schedule.dayOfWeek,
      mulai: mulai,
      selesai: selesai,
      tanggal: schedule.isPhl ? schedule.specificDate : null,
    );
  }
}

/// Apakah kedua slot bisa jatuh di hari yang sama.
///
/// PHL yang jatuh di hari Rabu tetap bertabrakan dengan kelas rutin hari Rabu:
/// kelas pengganti tidak membatalkan kelas reguler yang lain di hari itu.
bool _hariSama(JadwalSlot a, JadwalSlot b) {
  if (a.isPhl && b.isPhl) {
    final x = a.tanggal!;
    final y = b.tanggal!;
    return x.year == y.year && x.month == y.month && x.day == y.day;
  }
  return a.dayOfWeek == b.dayOfWeek;
}

/// Berapa menit kedua slot saling menimpa. 0 berarti tidak bentrok.
///
/// Bersentuhan tidak dihitung bentrok: kelas 10:00–12:00 dan 12:00–14:00 itu
/// berurutan, bukan tabrakan.
int menitBeririsan(JadwalSlot a, JadwalSlot b) {
  if (!_hariSama(a, b)) return 0;
  final mulai = a.mulai > b.mulai ? a.mulai : b.mulai;
  final selesai = a.selesai < b.selesai ? a.selesai : b.selesai;
  final irisan = selesai - mulai;
  return irisan > 0 ? irisan : 0;
}

/// Satu bentrokan terhadap sebuah jadwal yang sudah tersimpan.
class ScheduleConflict {
  const ScheduleConflict({required this.lawan, required this.menit});

  final ClassSchedule lawan;

  /// Lama irisan dalam menit.
  final int menit;

  String get durasiLabel {
    if (menit >= 60) {
      final jam = menit ~/ 60;
      final sisa = menit % 60;
      return sisa == 0 ? '$jam jam' : '$jam jam $sisa menit';
    }
    return '$menit menit';
  }
}

/// PHL yang tanggalnya sudah lewat bukan lagi masalah yang bisa diperbaiki.
bool _sudahLewat(JadwalSlot slot, DateTime hariIni) {
  final tanggal = slot.tanggal;
  if (tanggal == null) return false;
  final batas = DateTime(hariIni.year, hariIni.month, hariIni.day);
  return DateTime(tanggal.year, tanggal.month, tanggal.day).isBefore(batas);
}

/// Bentrokan untuk satu slot yang sedang diisi di form.
///
/// [lain] harus sudah tidak memuat jadwal yang sedang diedit — pemanggilnya
/// yang tahu id mana yang harus dikecualikan.
List<ScheduleConflict> conflictsForSlot(
  JadwalSlot slot,
  List<ClassSchedule> lain, {
  DateTime? now,
}) {
  final hariIni = now ?? DateTime.now();
  if (_sudahLewat(slot, hariIni)) return const [];

  final hasil = <ScheduleConflict>[];
  for (final schedule in lain) {
    final pembanding = JadwalSlot.dari(schedule);
    if (pembanding == null || _sudahLewat(pembanding, hariIni)) continue;
    final menit = menitBeririsan(slot, pembanding);
    if (menit > 0) hasil.add(ScheduleConflict(lawan: schedule, menit: menit));
  }
  hasil.sort((a, b) => b.menit.compareTo(a.menit));
  return hasil;
}

/// Peta id jadwal → daftar jadwal lain yang bentrok dengannya.
///
/// Jadwal yang aman tidak muncul sebagai key sama sekali, jadi
/// `map.containsKey(id)` cukup untuk memutuskan menampilkan tanda peringatan,
/// dan `map.length` langsung jadi jumlah jadwal bermasalah.
Map<String, List<ScheduleConflict>> conflictMap(
  List<ClassSchedule> schedules, {
  DateTime? now,
}) {
  final hariIni = now ?? DateTime.now();

  final slots = <String, JadwalSlot>{};
  for (final schedule in schedules) {
    final slot = JadwalSlot.dari(schedule);
    if (slot == null || _sudahLewat(slot, hariIni)) continue;
    slots[schedule.id] = slot;
  }

  final hasil = <String, List<ScheduleConflict>>{};
  final daftar = schedules.where((s) => slots.containsKey(s.id)).toList();

  for (var i = 0; i < daftar.length; i++) {
    for (var j = i + 1; j < daftar.length; j++) {
      final a = daftar[i];
      final b = daftar[j];
      final menit = menitBeririsan(slots[a.id]!, slots[b.id]!);
      if (menit == 0) continue;
      hasil.putIfAbsent(a.id, () => []).add(ScheduleConflict(lawan: b, menit: menit));
      hasil.putIfAbsent(b.id, () => []).add(ScheduleConflict(lawan: a, menit: menit));
    }
  }
  return hasil;
}

/// Jumlah pasangan yang bentrok — bukan jumlah jadwal.
///
/// Dua kelas yang saling menimpa itu satu masalah, bukan dua.
int totalPasanganBentrok(Map<String, List<ScheduleConflict>> map) {
  var total = 0;
  for (final daftar in map.values) {
    total += daftar.length;
  }
  return total ~/ 2;
}
