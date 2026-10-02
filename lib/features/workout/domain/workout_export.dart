/// Ekspor riwayat latihan ke teks biasa.
///
/// Teks, bukan JSON atau CSV: tujuannya dibaca manusia — ditempel ke chat
/// pelatih, disimpan di catatan, atau dicetak. Cadangan data mentah untuk
/// dipulihkan sudah ada di Profil → Data.
library;

import 'package:intl/intl.dart';

import '../../run/data/run_repository.dart' show RunLog;
import '../../run/domain/run_stats.dart';
import '../data/models/exercise_entry.dart';
import '../data/models/workout_session.dart';

DateTime _hari(DateTime d) => DateTime(d.year, d.month, d.day);

String _angka(num value) {
  final bulat = value == value.roundToDouble();
  return NumberFormat(bulat ? '#,##0' : '#,##0.#', 'id_ID').format(value);
}

/// Satu baris latihan, bentuknya mengikuti jenisnya.
String barisLatihan(ExerciseEntry e) {
  final set = e.sets ?? 0;
  final buffer = StringBuffer(e.exerciseName);

  switch (e.type) {
    case ExerciseType.beban:
      final beban = e.weightKg;
      buffer.write(' — ');
      if (beban != null) buffer.write('${_angka(beban)} kg × ');
      buffer.write('$set×${e.reps ?? 0}');
      if (e.volume > 0) buffer.write(' (volume ${_angka(e.volume)} kg)');
    case ExerciseType.bodyweight:
      buffer.write(' — $set×${e.reps ?? 0}');
      final tambahan = e.weightKg;
      if (tambahan != null && tambahan > 0) buffer.write(' (+${_angka(tambahan)} kg)');
      if (e.progressionLevel > 0) buffer.write(' · tingkat ${e.progressionLevel + 1}');
    case ExerciseType.isometrik:
      final detik = e.durationSeconds ?? 0;
      buffer.write(' — ${set > 0 ? '$set× ' : ''}$detik dtk');
    case ExerciseType.cardio:
      buffer.write(' — ${e.durationMinutes ?? 0} menit');
  }

  final catatan = e.notes?.trim();
  if (catatan != null && catatan.isNotEmpty) buffer.write(' · $catatan');
  return buffer.toString();
}

/// Susun teks ekspor untuk rentang [dari]..[sampai], keduanya inklusif dan
/// dihitung per tanggal.
///
/// Urut dari yang paling lama: dibaca seperti buku harian, dari awal rentang
/// sampai akhir. Hari dengan latihan dan lari sekaligus digabung jadi satu
/// judul hari.
String eksporWorkoutTxt({
  required List<WorkoutSession> sessions,
  List<RunLog> runs = const [],
  required DateTime dari,
  required DateTime sampai,
  required DateTime dibuat,
}) {
  final awal = _hari(dari);
  final akhir = _hari(sampai);
  bool masuk(DateTime d) => !_hari(d).isBefore(awal) && !_hari(d).isAfter(akhir);

  final sesi = [for (final s in sessions) if (masuk(s.sessionDate)) s]
    ..sort((a, b) {
      final tgl = a.sessionDate.compareTo(b.sessionDate);
      return tgl != 0 ? tgl : a.createdAt.compareTo(b.createdAt);
    });
  final lari = [for (final r in runs) if (masuk(r.startedAt)) r]
    ..sort((a, b) => a.startedAt.compareTo(b.startedAt));

  final tanggal = DateFormat('d MMM yyyy', 'id_ID');
  final judulHari = DateFormat('EEEE, d MMMM yyyy', 'id_ID');

  final semuaLatihan = [for (final s in sesi) ...s.exercises];
  final volume = semuaLatihan.fold<double>(0, (t, e) => t + e.volume);
  final jarak = lari.fold<double>(0, (t, r) => t + r.distanceMeters);
  final hariAktif = {
    for (final s in sesi) _hari(s.sessionDate),
    for (final r in lari) _hari(r.startedAt),
  };

  final out = StringBuffer()
    ..writeln('RIWAYAT WORKOUT')
    ..writeln('${tanggal.format(awal)} – ${tanggal.format(akhir)}')
    ..writeln()
    ..writeln('Hari aktif   : ${hariAktif.length}')
    ..writeln('Sesi latihan : ${sesi.length} (${semuaLatihan.length} gerakan)');
  if (volume > 0) out.writeln('Total volume : ${_angka(volume)} kg');
  if (lari.isNotEmpty) {
    out.writeln('Lari         : ${lari.length}× · ${formatDistance(jarak)}');
  }

  if (hariAktif.isEmpty) {
    out
      ..writeln()
      ..writeln('Tidak ada latihan tercatat di rentang ini.');
  }

  for (final hari in hariAktif.toList()..sort()) {
    out
      ..writeln()
      ..writeln('═' * 40)
      ..writeln(judulHari.format(hari))
      ..writeln('═' * 40);

    final sesiHariIni = [for (final s in sesi) if (_hari(s.sessionDate) == hari) s];
    for (final (i, s) in sesiHariIni.indexed) {
      if (sesiHariIni.length > 1) out.writeln('Sesi ${i + 1}');
      final catatan = s.notes?.trim();
      if (catatan != null && catatan.isNotEmpty) out.writeln('Catatan: $catatan');
      for (final e in s.exercises) {
        out.writeln('• ${barisLatihan(e)}');
      }
      if (s.exercises.isEmpty) out.writeln('• (tanpa gerakan tercatat)');
    }

    for (final r in lari) {
      if (_hari(r.startedAt) != hari) continue;
      final pace = paceSecondsPerKm(distanceMeters: r.distanceMeters, seconds: r.durationSeconds);
      out.write('• Lari ${formatDistance(r.distanceMeters)} · ${formatDuration(r.durationSeconds)}');
      if (pace != null) out.write(' · ${formatPace(pace)}/km');
      final catatan = r.notes?.trim();
      if (catatan != null && catatan.isNotEmpty) out.write(' · $catatan');
      out.writeln();
    }
  }

  out
    ..writeln()
    ..writeln('—')
    ..writeln('Diekspor dari Tracking, ${DateFormat('d MMM yyyy HH.mm', 'id_ID').format(dibuat)}');
  return out.toString();
}

/// Nama berkas, misal `workout_2026-08-01_2026-10-02.txt`.
String namaBerkasEkspor(DateTime dari, DateTime sampai) {
  String t(DateTime d) => d.toIso8601String().substring(0, 10);
  return 'workout_${t(dari)}_${t(sampai)}.txt';
}
