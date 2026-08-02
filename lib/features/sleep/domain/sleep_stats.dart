/// Ringkasan tidur.
///
/// Ambang batasnya mengikuti anjuran umum dewasa muda (7–9 jam). App tidak
/// menilai apakah tidurmu "sehat" — itu bukan urusan aplikasi catatan — cuma
/// menyandingkan angkamu dengan rentang itu.
library;

import '../data/sleep_repository.dart';

const double kSleepTargetMin = 7;
const double kSleepTargetMax = 9;

/// Berapa hari terakhir yang dipakai untuk rata-rata.
const int kSleepWindowDays = 14;

/// Satu malam dihitung cukup kalau mencapai batas bawah.
///
/// Sengaja tidak menuntut juga di bawah [kSleepTargetMax]: tidur sembilan
/// setengah jam bukan malam yang gagal, dan menghitungnya begitu akan membuat
/// angkanya menghukum hal yang salah.
bool tidurCukup(double hours) => hours >= kSleepTargetMin;

class SleepSummary {
  const SleepSummary({
    required this.rataJam,
    required this.hariTercatat,
    required this.hariCukup,
    required this.hariKurang,
  });

  final double rataJam;

  /// Berapa hari yang benar-benar ada catatannya dalam jendela.
  final int hariTercatat;

  final int hariCukup;
  final int hariKurang;

  bool get kosong => hariTercatat == 0;

  /// Persentase hari cukup, dari hari yang tercatat — bukan dari 14.
  ///
  /// Hari yang tidak dicatat bukan hari kurang tidur; menganggapnya begitu
  /// membuat angkanya menghukum kelupaan mencatat, bukan kurang tidur.
  double get persenCukup =>
      hariTercatat == 0 ? 0 : hariCukup * 100 / hariTercatat;
}

SleepSummary summarizeSleep(
  List<SleepLog> logs, {
  DateTime? now,
  int windowDays = kSleepWindowDays,
}) {
  final today = now ?? DateTime.now();
  final batas = DateTime(today.year, today.month, today.day)
      .subtract(Duration(days: windowDays - 1));

  var total = 0.0;
  var tercatat = 0;
  var cukup = 0;
  var kurang = 0;

  for (final log in logs) {
    final hari = DateTime(log.loggedOn.year, log.loggedOn.month, log.loggedOn.day);
    if (hari.isBefore(batas)) continue;
    if (hari.isAfter(DateTime(today.year, today.month, today.day))) continue;

    total += log.hours;
    tercatat++;
    if (tidurCukup(log.hours)) {
      cukup++;
    } else {
      kurang++;
    }
  }

  return SleepSummary(
    rataJam: tercatat == 0 ? 0 : total / tercatat,
    hariTercatat: tercatat,
    hariCukup: cukup,
    hariKurang: kurang,
  );
}

/// Tulis jam sebagai "7j 30m", bukan 7.5 — lebih cepat dibaca sekilas.
String formatJamTidur(double hours) {
  final jam = hours.floor();
  final menit = ((hours - jam) * 60).round();
  if (menit == 0) return '${jam}j';
  if (menit == 60) return '${jam + 1}j';
  return '${jam}j ${menit}m';
}
