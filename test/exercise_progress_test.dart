import 'package:flutter_test/flutter_test.dart';
import 'package:tracking/features/workout/data/models/exercise_entry.dart';
import 'package:tracking/features/workout/data/models/workout_session.dart';
import 'package:tracking/features/workout/domain/exercise_progress.dart';

ExerciseEntry _entry(
  String name, {
  ExerciseType type = ExerciseType.beban,
  double? weight,
  int? sets,
  int? reps,
  int? holdSeconds,
  int? minutes,
}) {
  return ExerciseEntry(
    id: 'e',
    sessionId: 's',
    userId: 'u',
    exerciseName: name,
    type: type,
    weightKg: weight,
    sets: sets,
    reps: reps,
    durationSeconds: holdSeconds,
    durationMinutes: minutes,
  );
}

WorkoutSession _session(DateTime date, List<ExerciseEntry> exercises) {
  return WorkoutSession(
    id: date.toIso8601String(),
    userId: 'u',
    sessionDate: date,
    createdAt: date,
    exercises: exercises,
  );
}

ExerciseProgress _find(List<ExerciseProgress> list, String name) =>
    list.firstWhere((p) => p.name.toLowerCase() == name.toLowerCase());

void main() {
  final h1 = DateTime(2026, 7, 20);
  final h2 = DateTime(2026, 7, 25);
  final h3 = DateTime(2026, 7, 30);

  group('metrik per tipe latihan', () {
    test('beban memakai kilogram', () {
      final list = buildExerciseProgress([
        _session(h1, [_entry('Bench Press', weight: 40, sets: 3, reps: 8)]),
        _session(h2, [_entry('Bench Press', weight: 45, sets: 3, reps: 8)]),
      ]);

      final bench = _find(list, 'Bench Press');
      expect(bench.metric, ProgressMetric.beban);
      expect(bench.metric.unit, 'kg');
      expect(bench.latest, 45);
      expect(bench.delta, 5);
    });

    test('bodyweight memakai rep, bukan kilogram', () {
      // Ini kasus yang dulu bikin Push Up muncul di daftar tapi grafiknya kosong.
      final list = buildExerciseProgress([
        _session(h1, [_entry('Push Up', type: ExerciseType.bodyweight, sets: 3, reps: 10)]),
        _session(h2, [_entry('Push Up', type: ExerciseType.bodyweight, sets: 3, reps: 14)]),
      ]);

      final pushUp = _find(list, 'Push Up');
      expect(pushUp.metric, ProgressMetric.rep);
      expect(pushUp.points, hasLength(2));
      expect(pushUp.latest, 14);
      expect(pushUp.delta, 4);
    });

    test('isometrik memakai detik tahanan', () {
      final list = buildExerciseProgress([
        _session(h1, [_entry('Plank', type: ExerciseType.isometrik, sets: 3, holdSeconds: 40)]),
        _session(h2, [_entry('Plank', type: ExerciseType.isometrik, sets: 3, holdSeconds: 55)]),
      ]);

      final plank = _find(list, 'Plank');
      expect(plank.metric, ProgressMetric.tahanan);
      expect(plank.metric.unit, 'detik');
      expect(plank.best, 55);
    });

    test('cardio ikut terhitung dan memakai menit', () {
      final list = buildExerciseProgress([
        _session(h1, [_entry('Lari', type: ExerciseType.cardio, minutes: 20)]),
        _session(h2, [_entry('Lari', type: ExerciseType.cardio, minutes: 30)]),
      ]);

      final lari = _find(list, 'Lari');
      expect(lari.metric, ProgressMetric.durasi);
      expect(lari.latest, 30);
    });
  });

  group('volume', () {
    test('bodyweight tanpa beban tambahan tidak punya volume', () {
      final list = buildExerciseProgress([
        _session(h1, [_entry('Push Up', type: ExerciseType.bodyweight, sets: 3, reps: 10)]),
      ]);

      expect(_find(list, 'Push Up').hasVolume, isFalse);
    });

    test('bodyweight dengan beban tambahan punya volume', () {
      final list = buildExerciseProgress([
        _session(h1, [
          _entry('Dip', type: ExerciseType.bodyweight, weight: 10, sets: 3, reps: 8),
        ]),
      ]);

      expect(_find(list, 'Dip').hasVolume, isTrue);
    });

    test('isometrik tidak punya volume meski ada beban', () {
      final list = buildExerciseProgress([
        _session(h1, [
          _entry('Plank', type: ExerciseType.isometrik, weight: 5, sets: 3, holdSeconds: 40),
        ]),
      ]);

      expect(_find(list, 'Plank').hasVolume, isFalse);
    });
  });

  group('pengumpulan data', () {
    test('titik diurutkan dari sesi terlama meski input acak', () {
      final list = buildExerciseProgress([
        _session(h3, [_entry('Squat', weight: 70, sets: 3, reps: 8)]),
        _session(h1, [_entry('Squat', weight: 60, sets: 3, reps: 8)]),
        _session(h2, [_entry('Squat', weight: 65, sets: 3, reps: 8)]),
      ]);

      final squat = _find(list, 'Squat');
      expect([for (final p in squat.points) p.value], [60, 65, 70]);
      expect(squat.delta, 10);
    });

    test('nama latihan digabung tanpa memandang huruf besar/kecil', () {
      final list = buildExerciseProgress([
        _session(h1, [_entry('bench press', weight: 40, sets: 3, reps: 8)]),
        _session(h2, [_entry('Bench Press', weight: 45, sets: 3, reps: 8)]),
      ]);

      expect(list, hasLength(1));
      // Ejaan terbaru yang dipakai untuk ditampilkan.
      expect(list.first.name, 'Bench Press');
      expect(list.first.sessionCount, 2);
    });

    test('catatan tanpa angka metrik dilewati', () {
      final list = buildExerciseProgress([
        // Beban tanpa kg, bodyweight tanpa rep, isometrik tanpa detik.
        _session(h1, [
          _entry('Bench Press', sets: 3, reps: 8),
          _entry('Push Up', type: ExerciseType.bodyweight, sets: 3),
          _entry('Plank', type: ExerciseType.isometrik, sets: 3),
        ]),
      ]);

      expect(list, isEmpty);
    });

    test('daftar diurutkan dari latihan yang paling baru dicatat', () {
      final list = buildExerciseProgress([
        _session(h1, [_entry('Squat', weight: 60, sets: 3, reps: 8)]),
        _session(h3, [_entry('Bench Press', weight: 40, sets: 3, reps: 8)]),
      ]);

      expect(list.first.name, 'Bench Press');
      expect(list.last.name, 'Squat');
    });

    test('satu sesi tetap muncul dengan delta nol', () {
      final list = buildExerciseProgress([
        _session(h1, [_entry('Row', weight: 30, sets: 3, reps: 10)]),
      ]);

      final row = _find(list, 'Row');
      expect(row.sessionCount, 1);
      expect(row.delta, 0);
      expect(row.best, 30);
    });

    test('tanpa sesi mengembalikan daftar kosong', () {
      expect(buildExerciseProgress(const []), isEmpty);
    });
  });

  group('set ikut dihitung', () {
    test('bodyweight: 3x10 dan 5x10 tidak lagi tergambar sama', () {
      // Ini cacat yang diperbaiki. Metrik utama bodyweight adalah rep per set,
      // jadi keduanya sama-sama bernilai 10 — padahal yang kedua hampir dua
      // kali lipat kerjanya. Setnya tercatat sejak awal, cuma tidak pernah
      // ikut dihitung.
      final list = buildExerciseProgress([
        _session(h1, [_entry('Push Up', type: ExerciseType.bodyweight, sets: 3, reps: 10)]),
        _session(h3, [_entry('Push Up', type: ExerciseType.bodyweight, sets: 5, reps: 10)]),
      ]);

      final pushUp = _find(list, 'Push Up');

      // Metrik utamanya memang tetap sama — itu bukan bug, 10 rep per set ya 10.
      expect(pushUp.points.first.value, 10);
      expect(pushUp.points.last.value, 10);

      // Yang membedakan sekarang ada.
      expect(pushUp.metrikBeban, MetrikBeban.totalRep);
      expect(pushUp.points.first.bebanKerja, 30);
      expect(pushUp.points.last.bebanKerja, 50);
      expect(pushUp.punyaBeban, isTrue);
      expect(pushUp.bebanTerbaik, 50);
    });

    test('set dan rep terbawa untuk ditampilkan sebagai "3 x 10"', () {
      final list = buildExerciseProgress([
        _session(h1, [_entry('Squat', weight: 60, sets: 3, reps: 10)]),
      ]);

      final titik = _find(list, 'Squat').points.single;
      expect(titik.sets, 3);
      expect(titik.reps, 10);
      expect(titik.ringkasSetRep, '3 x 10');
    });

    test('set yang tidak diisi tidak ditebak jadi satu', () {
      final list = buildExerciseProgress([
        _session(h1, [_entry('Plank', type: ExerciseType.isometrik, holdSeconds: 45)]),
      ]);

      final plank = _find(list, 'Plank').points.single;
      expect(plank.sets, isNull);
      expect(plank.ringkasSetRep, isNull);
      expect(plank.bebanKerja, isNull,
          reason: 'tanpa set, total tahanan tidak bisa dihitung — dan menebaknya '
              'satu set akan membuat grafiknya berbohong');
    });

    test('catatan tanpa set dilewati, bukan dianggap nol', () {
      final list = buildExerciseProgress([
        _session(h1, [_entry('Pull Up', type: ExerciseType.bodyweight, reps: 8)]),
        _session(h2, [_entry('Pull Up', type: ExerciseType.bodyweight, sets: 3, reps: 8)]),
        _session(h3, [_entry('Pull Up', type: ExerciseType.bodyweight, sets: 4, reps: 8)]),
      ]);

      final pullUp = _find(list, 'Pull Up');
      expect(pullUp.sessionCount, 3);
      expect(pullUp.titikBeban.length, 2, reason: 'yang tanpa set tidak ikut digrafikkan');
      expect(pullUp.titikBeban.map((p) => p.bebanKerja), [24, 32]);
    });

    test('isometrik memakai set x detik, bukan rep', () {
      final list = buildExerciseProgress([
        _session(h1, [_entry('Plank', type: ExerciseType.isometrik, sets: 3, holdSeconds: 40)]),
        _session(h3, [_entry('Plank', type: ExerciseType.isometrik, sets: 3, holdSeconds: 60)]),
      ]);

      final plank = _find(list, 'Plank');
      expect(plank.metrikBeban, MetrikBeban.totalTahanan);
      expect(plank.titikBeban.map((p) => p.bebanKerja), [120, 180]);
    });

    test('beban tetap memakai kilogram x set x rep', () {
      final list = buildExerciseProgress([
        _session(h1, [_entry('Bench Press', weight: 40, sets: 3, reps: 10)]),
        _session(h3, [_entry('Bench Press', weight: 45, sets: 3, reps: 10)]),
      ]);

      final bench = _find(list, 'Bench Press');
      expect(bench.metrikBeban, MetrikBeban.volume);
      expect(bench.titikBeban.map((p) => p.bebanKerja), [1200, 1350]);
    });

    test('cardio tidak punya ukuran kerja total', () {
      final list = buildExerciseProgress([
        _session(h1, [_entry('Lari', type: ExerciseType.cardio, minutes: 30)]),
      ]);

      final lari = _find(list, 'Lari');
      expect(lari.metrikBeban, isNull,
          reason: 'durasi sudah jadi metrik utama; mengalikannya dengan set '
              'tidak berarti apa-apa');
      expect(lari.punyaBeban, isFalse);
    });

    test('satu titik saja belum layak digrafikkan sebagai kerja total', () {
      final list = buildExerciseProgress([
        _session(h1, [_entry('Dip', type: ExerciseType.bodyweight, sets: 3, reps: 8)]),
      ]);

      expect(_find(list, 'Dip').punyaBeban, isFalse);
    });
  });
}
