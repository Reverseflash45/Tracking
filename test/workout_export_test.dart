import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:tracking/features/run/data/run_repository.dart';
import 'package:tracking/features/workout/data/models/exercise_entry.dart';
import 'package:tracking/features/workout/data/models/workout_session.dart';
import 'package:tracking/features/workout/domain/workout_export.dart';

ExerciseEntry _gerak(
  String nama, {
  ExerciseType type = ExerciseType.beban,
  double? kg,
  int? set,
  int? rep,
  int? menit,
  int? detik,
  int level = 0,
  String? catatan,
}) =>
    ExerciseEntry(
      id: nama,
      sessionId: 's',
      userId: 'u',
      exerciseName: nama,
      type: type,
      weightKg: kg,
      sets: set,
      reps: rep,
      durationMinutes: menit,
      durationSeconds: detik,
      progressionLevel: level,
      notes: catatan,
    );

WorkoutSession _sesi(DateTime tgl, List<ExerciseEntry> gerak, {String? catatan}) => WorkoutSession(
      id: '$tgl',
      userId: 'u',
      sessionDate: tgl,
      notes: catatan,
      createdAt: tgl,
      exercises: gerak,
    );

void main() {
  setUpAll(() => initializeDateFormatting('id_ID', null));

  group('barisLatihan', () {
    test('tiap jenis punya bentuknya sendiri', () {
      expect(
        barisLatihan(_gerak('Bench press', kg: 60, set: 4, rep: 8)),
        'Bench press — 60 kg × 4×8 (volume 1.920 kg)',
      );
      expect(
        barisLatihan(_gerak('Push up', type: ExerciseType.bodyweight, set: 3, rep: 15, kg: 10, level: 2)),
        'Push up — 3×15 (+10 kg) · tingkat 3',
      );
      expect(
        barisLatihan(_gerak('Plank', type: ExerciseType.isometrik, set: 3, detik: 45)),
        'Plank — 3× 45 dtk',
      );
      expect(
        barisLatihan(_gerak('Sepeda', type: ExerciseType.cardio, menit: 30, catatan: 'santai')),
        'Sepeda — 30 menit · santai',
      );
      expect(barisLatihan(_gerak('Squat', kg: 62.5, set: 5, rep: 5)), contains('62,5 kg'));
    });
  });

  group('eksporWorkoutTxt', () {
    final sesi = [
      _sesi(DateTime(2026, 9, 1), [_gerak('Deadlift', kg: 100, set: 3, rep: 5)]),
      _sesi(DateTime(2026, 9, 15), [_gerak('Bench press', kg: 60, set: 4, rep: 8)], catatan: 'Push day'),
      _sesi(DateTime(2026, 10, 2), [_gerak('Squat', kg: 80, set: 5, rep: 5)]),
    ];
    final lari = [
      RunLog(
        id: 'r',
        startedAt: DateTime(2026, 9, 15, 6),
        durationSeconds: 1800,
        distanceMeters: 5000,
        route: const [],
      ),
    ];

    test('hanya isi rentang, urut dari terlama, hari sama digabung', () {
      final teks = eksporWorkoutTxt(
        sessions: sesi,
        runs: lari,
        dari: DateTime(2026, 9, 10),
        sampai: DateTime(2026, 10, 2, 23),
        dibuat: DateTime(2026, 10, 2, 20),
      );

      expect(teks, isNot(contains('Deadlift')));
      expect(teks.indexOf('Bench press'), lessThan(teks.indexOf('Squat')));
      expect(teks, contains('Catatan: Push day'));
      expect(teks, contains('• Lari 5.00 km · 30:00 · 6:00/km'));
      expect('Selasa, 15 September 2026'.allMatches(teks).length, 1);
      expect(teks, contains('Hari aktif   : 2'));
      expect(teks, contains('Sesi latihan : 2 (2 gerakan)'));
      expect(teks, contains('Total volume : 3.920 kg'));
    });

    test('rentang kosong tetap menghasilkan teks yang jelas', () {
      final teks = eksporWorkoutTxt(
        sessions: sesi,
        dari: DateTime(2025, 1, 1),
        sampai: DateTime(2025, 1, 31),
        dibuat: DateTime(2026, 10, 2),
      );
      expect(teks, contains('Tidak ada latihan tercatat di rentang ini.'));
    });

    test('nama berkas memuat rentangnya', () {
      expect(
        namaBerkasEkspor(DateTime(2026, 8, 1), DateTime(2026, 10, 2)),
        'workout_2026-08-01_2026-10-02.txt',
      );
    });
  });
}
