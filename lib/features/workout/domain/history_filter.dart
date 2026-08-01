/// Penyaring riwayat latihan.
///
/// Dipisah dari halamannya supaya bisa diuji tanpa membuka layar. Aturan
/// "sesi mana yang masuk hitungan" itu yang paling gampang salah dan paling
/// tidak kelihatan salahnya kalau cuma dilihat sekilas.
library;

import '../data/models/exercise_entry.dart';
import '../data/models/workout_session.dart';
import '../data/rest_day_repository.dart';

/// Rentang waktu yang bisa dipilih.
enum HistoryPeriod {
  tigaPuluhHari('30 Hari', 30),
  tigaBulan('3 Bulan', 90),
  tahunIni('Tahun Ini', null),
  semua('Semua', null);

  const HistoryPeriod(this.label, this.days);

  final String label;

  /// Null untuk rentang yang tidak dihitung mundur dari hari ini.
  final int? days;

  bool contains(DateTime date, DateTime now) {
    switch (this) {
      case HistoryPeriod.semua:
        return true;
      case HistoryPeriod.tahunIni:
        return date.year == now.year;
      case HistoryPeriod.tigaPuluhHari:
      case HistoryPeriod.tigaBulan:
        final batas = DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: days! - 1));
        final hari = DateTime(date.year, date.month, date.day);
        return !hari.isBefore(batas);
    }
  }
}

/// Jenis catatan yang ditampilkan.
enum HistoryKind {
  semua('Semua', null),
  beban('Beban', ExerciseType.beban),
  bodyweight('Bodyweight', ExerciseType.bodyweight),
  isometrik('Isometrik', ExerciseType.isometrik),
  cardio('Cardio', ExerciseType.cardio),
  istirahat('Istirahat', null);

  const HistoryKind(this.label, this.type);

  final String label;

  /// Null untuk [semua] dan [istirahat], yang tidak menyaring per tipe latihan.
  final ExerciseType? type;
}

class HistoryFilter {
  const HistoryFilter({
    this.period = HistoryPeriod.tigaPuluhHari,
    this.kind = HistoryKind.semua,
    this.query = '',
  });

  final HistoryPeriod period;
  final HistoryKind kind;

  /// Pencarian nama latihan. Kosong berarti tidak menyaring.
  final String query;

  bool get aktif =>
      period != HistoryPeriod.semua ||
      kind != HistoryKind.semua ||
      query.trim().isNotEmpty;

  HistoryFilter copyWith({HistoryPeriod? period, HistoryKind? kind, String? query}) =>
      HistoryFilter(
        period: period ?? this.period,
        kind: kind ?? this.kind,
        query: query ?? this.query,
      );
}

/// Satu baris riwayat: sesi latihan atau hari istirahat.
class HistoryRow {
  const HistoryRow.sesi(WorkoutSession this.session) : rest = null;

  const HistoryRow.istirahat(RestDay this.rest) : session = null;

  final WorkoutSession? session;
  final RestDay? rest;

  DateTime get tanggal => session?.sessionDate ?? rest!.restOn;
  bool get isRest => rest != null;
}

/// Ringkasan dari baris yang lolos saringan.
///
/// Sengaja dihitung dari hasil saringan, bukan dari seluruh riwayat — angka
/// yang tidak sejalan dengan daftar di bawahnya lebih membingungkan daripada
/// tidak ada angka sama sekali.
class HistorySummary {
  const HistorySummary({
    required this.sesi,
    required this.hariIstirahat,
    required this.volumeKg,
    required this.menitCardio,
    required this.jumlahLatihan,
  });

  final int sesi;
  final int hariIstirahat;
  final double volumeKg;
  final int menitCardio;
  final int jumlahLatihan;

  bool get kosong => sesi == 0 && hariIstirahat == 0;
}

bool _cocokQuery(WorkoutSession session, String query) {
  final cari = query.trim().toLowerCase();
  if (cari.isEmpty) return true;
  return session.exercises
      .any((exercise) => exercise.exerciseName.toLowerCase().contains(cari));
}

/// Saring dan urutkan riwayat, terbaru dulu.
List<HistoryRow> filterHistory({
  required List<WorkoutSession> sessions,
  required List<RestDay> restDays,
  required HistoryFilter filter,
  required DateTime now,
}) {
  final rows = <HistoryRow>[];

  // Hari istirahat cuma muncul di "Semua" dan "Istirahat". Menyaring per tipe
  // latihan lalu tetap menampilkan hari tanpa latihan itu jawaban yang salah.
  final restDitampilkan =
      filter.kind == HistoryKind.semua || filter.kind == HistoryKind.istirahat;
  // Pencarian nama latihan juga membuang hari istirahat, karena hari istirahat
  // tidak punya nama latihan untuk dicocokkan.
  final adaQuery = filter.query.trim().isNotEmpty;

  if (filter.kind != HistoryKind.istirahat) {
    for (final session in sessions) {
      if (!filter.period.contains(session.sessionDate, now)) continue;
      if (!_cocokQuery(session, filter.query)) continue;

      final tipe = filter.kind.type;
      if (tipe != null &&
          !session.exercises.any((exercise) => exercise.type == tipe)) {
        continue;
      }

      rows.add(HistoryRow.sesi(session));
    }
  }

  if (restDitampilkan && !adaQuery) {
    for (final day in restDays) {
      if (!filter.period.contains(day.restOn, now)) continue;
      rows.add(HistoryRow.istirahat(day));
    }
  }

  rows.sort((a, b) => b.tanggal.compareTo(a.tanggal));
  return rows;
}

HistorySummary summarizeHistory(List<HistoryRow> rows, {HistoryKind? kind}) {
  var sesi = 0;
  var istirahat = 0;
  var volume = 0.0;
  var menit = 0;
  var latihan = 0;

  for (final row in rows) {
    final session = row.session;
    if (session == null) {
      istirahat++;
      continue;
    }

    sesi++;
    // Kalau saringannya per tipe, yang dihitung hanya latihan bertipe itu —
    // menjumlahkan seluruh isi sesi membuat angkanya tidak menjawab
    // pertanyaan yang barusan ditanyakan lewat saringan.
    final tipe = kind?.type;
    for (final exercise in session.exercises) {
      if (tipe != null && exercise.type != tipe) continue;
      latihan++;
      volume += exercise.volume;
      if (exercise.type == ExerciseType.cardio) {
        menit += exercise.durationMinutes ?? 0;
      }
    }
  }

  return HistorySummary(
    sesi: sesi,
    hariIstirahat: istirahat,
    volumeKg: volume,
    menitCardio: menit,
    jumlahLatihan: latihan,
  );
}
