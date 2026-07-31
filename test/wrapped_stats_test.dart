import 'package:flutter_test/flutter_test.dart';
import 'package:tracking/features/academic/data/models/task.dart';
import 'package:tracking/features/nutrition/domain/food_log.dart';
import 'package:tracking/features/workout/data/models/exercise_entry.dart';
import 'package:tracking/features/workout/data/models/workout_session.dart';
import 'package:tracking/features/wrapped/domain/wrapped_stats.dart';

AcademicTask _task({
  required DateTime deadline,
  DateTime? completedAt,
  String? courseName,
  String title = 'Tugas',
}) {
  return AcademicTask(
    id: '$title-${deadline.toIso8601String()}',
    userId: 'u',
    title: title,
    courseName: courseName,
    deadline: deadline,
    priority: TaskPriority.medium,
    status: completedAt == null ? TaskStatus.todo : TaskStatus.done,
    createdAt: deadline.subtract(const Duration(days: 7)),
    completedAt: completedAt,
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

ExerciseEntry _entry(
  String name, {
  double? weight,
  int? sets,
  int? reps,
  ExerciseType type = ExerciseType.beban,
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
  );
}

FoodLog _food(
  DateTime date, {
  String name = 'Nasi Goreng',
  double calories = 500,
  double protein = 20,
}) {
  return FoodLog(
    id: '$name-${date.toIso8601String()}-$calories',
    loggedOn: date,
    loggedAt: date,
    name: name,
    meal: Meal.makanSiang,
    calories: calories,
    proteinG: protein,
    carbsG: 60,
    fatG: 15,
  );
}

WaterLog _water(DateTime date, {int ml = 250}) {
  return WaterLog(
    id: '${date.toIso8601String()}-$ml',
    loggedOn: date,
    loggedAt: date,
    ml: ml,
  );
}

void main() {
  // Jumat, 31 Juli 2026. Minggu berjalan dimulai Senin 27 Juli.
  final now = DateTime(2026, 7, 31, 12);

  group('rangeFor', () {
    test('mingguan dimulai hari Senin', () {
      final range = rangeFor(WrappedPeriod.mingguan, now);
      expect(range.start, DateTime(2026, 7, 27));
      expect(range.contains(DateTime(2026, 7, 27)), isTrue);
      expect(range.contains(DateTime(2026, 7, 26, 23, 59)), isFalse);
    });

    test('bulanan dimulai tanggal 1', () {
      expect(rangeFor(WrappedPeriod.bulanan, now).start, DateTime(2026, 7));
    });

    test('tahunan dimulai 1 Januari', () {
      expect(rangeFor(WrappedPeriod.tahunan, now).start, DateTime(2026));
    });

    test('rentang berakhir di akhir hari ini, bukan akhir periode', () {
      final range = rangeFor(WrappedPeriod.bulanan, now);
      expect(range.contains(DateTime(2026, 7, 31, 23, 59)), isTrue);
      expect(range.contains(DateTime(2026, 8, 1)), isFalse);
    });
  });

  group('computeWrappedStats', () {
    test('hanya menghitung tugas yang selesai di dalam rentang', () {
      final tasks = [
        // Selesai minggu ini, tepat waktu.
        _task(deadline: DateTime(2026, 7, 30, 23, 59), completedAt: DateTime(2026, 7, 29)),
        // Selesai minggu ini, telat.
        _task(deadline: DateTime(2026, 7, 27), completedAt: DateTime(2026, 7, 28), title: 'B'),
        // Selesai minggu lalu, di luar rentang mingguan.
        _task(deadline: DateTime(2026, 7, 20), completedAt: DateTime(2026, 7, 20), title: 'C'),
        // Belum selesai.
        _task(deadline: DateTime(2026, 7, 31), title: 'D'),
      ];

      final stats = computeWrappedStats(
        period: WrappedPeriod.mingguan,
        now: now,
        tasks: tasks,
        sessions: const [],
      );

      expect(stats.tugasSelesai, 2);
      expect(stats.tugasTepatWaktu, 1);
      expect(stats.persenTepatWaktu, 50);
    });

    test('menghitung volume dan PR dari latihan non-cardio', () {
      final sessions = [
        _session(DateTime(2026, 7, 28), [
          _entry('Bench Press', weight: 40, sets: 3, reps: 10), // 1200
          _entry('Lari', type: ExerciseType.cardio),
        ]),
        _session(DateTime(2026, 7, 30), [
          _entry('Squat', weight: 60, sets: 3, reps: 8), // 1440
        ]),
      ];

      final stats = computeWrappedStats(
        period: WrappedPeriod.mingguan,
        now: now,
        tasks: const [],
        sessions: sessions,
      );

      expect(stats.sesiWorkout, 2);
      expect(stats.totalVolume, 2640);
      expect(stats.prBeban!.exerciseName, 'Squat');
      expect(stats.prBeban!.weightKg, 60);
    });

    test('hari aktif menghitung tanggal unik dari tugas dan workout', () {
      final tasks = [
        _task(deadline: DateTime(2026, 7, 29), completedAt: DateTime(2026, 7, 29, 8)),
        _task(deadline: DateTime(2026, 7, 29), completedAt: DateTime(2026, 7, 29, 20), title: 'B'),
      ];
      final sessions = [
        // Hari yang sama dengan tugas di atas, tidak boleh dihitung dua kali.
        _session(DateTime(2026, 7, 29), [_entry('Row', weight: 30, sets: 3, reps: 10)]),
        _session(DateTime(2026, 7, 30), [_entry('Row', weight: 30, sets: 3, reps: 10)]),
      ];

      final stats = computeWrappedStats(
        period: WrappedPeriod.mingguan,
        now: now,
        tasks: tasks,
        sessions: sessions,
      );

      expect(stats.hariAktif, 2);
    });

    test('menentukan matkul tersibuk dan hari paling produktif', () {
      final tasks = [
        _task(
          deadline: DateTime(2026, 7, 29),
          completedAt: DateTime(2026, 7, 29),
          courseName: 'Kalkulus',
        ),
        _task(
          deadline: DateTime(2026, 7, 29),
          completedAt: DateTime(2026, 7, 29),
          courseName: 'Kalkulus',
          title: 'B',
        ),
        _task(
          deadline: DateTime(2026, 7, 30),
          completedAt: DateTime(2026, 7, 30),
          courseName: 'Fisika',
          title: 'C',
        ),
      ];

      final stats = computeWrappedStats(
        period: WrappedPeriod.mingguan,
        now: now,
        tasks: tasks,
        sessions: const [],
      );

      expect(stats.matkulTersibuk!.label, 'Kalkulus');
      expect(stats.matkulTersibuk!.count, 2);
      // 29 Juli 2026 = Rabu.
      expect(stats.hariPalingProduktif, DateTime.wednesday);
    });

    test('data kosong ditandai dan tidak membagi dengan nol', () {
      final stats = computeWrappedStats(
        period: WrappedPeriod.mingguan,
        now: now,
        tasks: const [],
        sessions: const [],
      );

      expect(stats.kosong, isTrue);
      expect(stats.persenTepatWaktu, 0);
      expect(stats.matkulTersibuk, isNull);
      expect(stats.prBeban, isNull);
      expect(stats.hariPalingProduktif, isNull);
      expect(stats.persona, 'Baru Mulai');
    });

    test('persona mencerminkan kombinasi aktivitas', () {
      final tugasBanyakTepatWaktu = [
        for (var i = 0; i < 5; i++)
          _task(
            deadline: DateTime(2026, 7, 29, 23, 59),
            completedAt: DateTime(2026, 7, 29),
            title: 'T$i',
          ),
      ];

      final konsisten = computeWrappedStats(
        period: WrappedPeriod.mingguan,
        now: now,
        tasks: tugasBanyakTepatWaktu,
        sessions: const [],
      );
      expect(konsisten.persona, 'Si Konsisten');

      final banyakGym = [
        for (var i = 0; i < 5; i++)
          _session(DateTime(2026, 7, 27 + i), [_entry('Squat', weight: 60, sets: 3, reps: 8)]),
      ];

      final seimbang = computeWrappedStats(
        period: WrappedPeriod.mingguan,
        now: now,
        tasks: tugasBanyakTepatWaktu,
        sessions: banyakGym,
      );
      expect(seimbang.persona, 'Si Seimbang');

      final gymRat = computeWrappedStats(
        period: WrappedPeriod.mingguan,
        now: now,
        tasks: const [],
        sessions: banyakGym,
      );
      expect(gymRat.persona, 'Gym Rat');
    });
  });

  group('nutrisi', () {
    test('hanya menghitung catatan di dalam rentang', () {
      final stats = computeWrappedStats(
        period: WrappedPeriod.mingguan,
        now: now,
        tasks: const [],
        sessions: const [],
        foods: [
          _food(DateTime(2026, 7, 28)),
          // Minggu lalu, di luar rentang mingguan.
          _food(DateTime(2026, 7, 20)),
        ],
      );

      expect(stats.nutrisi.hariTercatat, 1);
      expect(stats.nutrisi.totalKalori, 500);
    });

    test('rata-rata dibagi hari tercatat, bukan jumlah entri', () {
      final stats = computeWrappedStats(
        period: WrappedPeriod.mingguan,
        now: now,
        tasks: const [],
        sessions: const [],
        foods: [
          _food(DateTime(2026, 7, 28), calories: 400, protein: 10),
          _food(DateTime(2026, 7, 28), calories: 600, protein: 30),
          _food(DateTime(2026, 7, 29), calories: 500, protein: 20),
        ],
      );

      expect(stats.nutrisi.hariTercatat, 2);
      // Hari pertama 1000, hari kedua 500 -> rata-rata 750.
      expect(stats.nutrisi.rataKalori, 750);
      expect(stats.nutrisi.rataProtein, 30);
    });

    test('makanan favorit tidak peduli huruf besar/kecil', () {
      final stats = computeWrappedStats(
        period: WrappedPeriod.mingguan,
        now: now,
        tasks: const [],
        sessions: const [],
        foods: [
          _food(DateTime(2026, 7, 28), name: 'Nasi Goreng'),
          _food(DateTime(2026, 7, 29), name: 'nasi goreng'),
          _food(DateTime(2026, 7, 30), name: 'Ayam Bakar'),
        ],
      );

      expect(stats.nutrisi.makananFavorit!.count, 2);
      // Ejaan yang ditampilkan mengikuti catatan terbaru.
      expect(stats.nutrisi.makananFavorit!.label, 'nasi goreng');
    });

    test('gelas air dihitung dari mililiter', () {
      final stats = computeWrappedStats(
        period: WrappedPeriod.mingguan,
        now: now,
        tasks: const [],
        sessions: const [],
        waters: [
          _water(DateTime(2026, 7, 28)),
          _water(DateTime(2026, 7, 28), ml: 600),
          _water(DateTime(2026, 7, 20)),
        ],
      );

      // 250 ml = 1 gelas, 600 ml dibulatkan jadi 2 gelas; yang di luar rentang
      // tidak ikut.
      expect(stats.nutrisi.totalGelas, 3);
    });

    test('catatan makan saja sudah membuat wrapped tidak kosong', () {
      final stats = computeWrappedStats(
        period: WrappedPeriod.mingguan,
        now: now,
        tasks: const [],
        sessions: const [],
        foods: [_food(DateTime(2026, 7, 28))],
      );

      expect(stats.kosong, isFalse);
    });

    test('tanpa data nutrisi tidak membagi dengan nol', () {
      final stats = computeWrappedStats(
        period: WrappedPeriod.mingguan,
        now: now,
        tasks: const [],
        sessions: const [],
      );

      expect(stats.nutrisi.kosong, isTrue);
      expect(stats.nutrisi.rataKalori, 0);
      expect(stats.nutrisi.makananFavorit, isNull);
    });

    test('mencatat makan beberapa hari memberi persona sendiri', () {
      final stats = computeWrappedStats(
        period: WrappedPeriod.mingguan,
        now: now,
        tasks: const [],
        sessions: const [],
        foods: [
          _food(DateTime(2026, 7, 28)),
          _food(DateTime(2026, 7, 29)),
          _food(DateTime(2026, 7, 30)),
        ],
      );

      expect(stats.persona, 'Pencatat Setia');
    });

    test('hari aktif tidak ikut naik hanya karena mencatat makan', () {
      final stats = computeWrappedStats(
        period: WrappedPeriod.mingguan,
        now: now,
        tasks: const [],
        sessions: const [],
        foods: [_food(DateTime(2026, 7, 28)), _food(DateTime(2026, 7, 29))],
      );

      expect(stats.hariAktif, 0);
    });
  });
}
