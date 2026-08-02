import 'package:flutter_test/flutter_test.dart';
import 'package:tracking/features/academic/data/models/task.dart';
import 'package:tracking/features/academic/domain/grade.dart';
import 'package:tracking/features/assistant/domain/preset_answers.dart';
import 'package:tracking/features/finance/domain/finance_stats.dart';
import 'package:tracking/features/finance/domain/transaction.dart';
import 'package:tracking/features/nutrition/domain/food_log.dart';
import 'package:tracking/features/run/data/run_repository.dart';
import 'package:tracking/features/workout/data/models/exercise_entry.dart';
import 'package:tracking/features/workout/data/models/workout_session.dart';

/// Senin, 3 Agustus 2026.
final _now = DateTime(2026, 8, 3, 12);

DateTime _daysAgo(int days) => DateTime(2026, 8, 3).subtract(Duration(days: days));

AcademicTask _task({
  required DateTime deadline,
  DateTime? completedAt,
  String title = 'Tugas',
  String? courseName,
}) {
  return AcademicTask(
    id: '$title-${deadline.toIso8601String()}-${completedAt?.toIso8601String()}',
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

WorkoutSession _session(DateTime date, [List<ExerciseEntry> exercises = const []]) {
  return WorkoutSession(
    id: date.toIso8601String(),
    userId: 'u',
    sessionDate: date,
    createdAt: date,
    exercises: exercises,
  );
}

ExerciseEntry _entry(String name, {double? weight, int? sets, int? reps}) {
  return ExerciseEntry(
    id: 'e-$name-$weight',
    sessionId: 's',
    userId: 'u',
    exerciseName: name,
    weightKg: weight,
    sets: sets,
    reps: reps,
  );
}

RunLog _run(DateTime date, double meters, int seconds) => RunLog(
      id: date.toIso8601String(),
      startedAt: date,
      durationSeconds: seconds,
      distanceMeters: meters,
      route: const [],
    );

FoodLog _food(DateTime date, {String name = 'Nasi', double calories = 500}) => FoodLog(
      id: '${date.toIso8601String()}-$name-$calories',
      loggedOn: date,
      loggedAt: date,
      name: name,
      meal: Meal.makanSiang,
      calories: calories,
      proteinG: 20,
      carbsG: 60,
      fatG: 15,
    );

Transaction _tx(DateTime date, double amount, {TxCategory category = TxCategory.makan}) =>
    Transaction(
      id: '${date.toIso8601String()}-$amount',
      occurredOn: date,
      kind: TxKind.pengeluaran,
      category: category,
      amount: amount,
    );

WaterLog _air(DateTime date, int ml) => WaterLog(
      id: '${date.toIso8601String()}-$ml',
      loggedOn: date,
      loggedAt: date,
      ml: ml,
    );

/// Mata kuliah dengan nilai resmi — bentuk paling ringkas untuk pengujian.
CourseGrade _matkul(String id, String nama, String huruf, {int sks = 3}) => CourseGrade(
      courseId: id,
      courseName: nama,
      sks: sks,
      semester: null,
      finalLetter: huruf,
      components: const [],
    );

AcademicTask _tugasMatkul(
  String courseId, {
  required DateTime deadline,
  required DateTime selesai,
}) =>
    AcademicTask(
      id: '$courseId-${deadline.toIso8601String()}-${selesai.toIso8601String()}',
      userId: 'u',
      courseId: courseId,
      title: 'Tugas',
      deadline: deadline,
      priority: TaskPriority.medium,
      status: TaskStatus.done,
      createdAt: deadline.subtract(const Duration(days: 7)),
      completedAt: selesai,
    );

Answer _jawab(String id, QuestionInput input) =>
    questionCatalog.firstWhere((q) => q.id == id).answer(input);

void main() {
  group('katalog', () {
    test('semua id unik', () {
      final ids = [for (final q in questionCatalog) q.id];
      expect(ids.toSet().length, ids.length);
    });

    test('tiap kategori punya minimal satu pertanyaan', () {
      final grouped = questionsByCategory;
      for (final category in QuestionCategory.values) {
        expect(grouped[category], isNotEmpty, reason: category.label);
      }
    });

    test('data kosong tidak pernah error dan selalu ditandai kosong', () {
      final input = QuestionInput(now: _now);
      for (final question in questionCatalog) {
        final answer = question.answer(input);
        expect(answer.kosong, isTrue, reason: question.id);
        // Meski kosong, detailnya harus menjelaskan apa yang perlu diisi —
        // bukan layar kosong tanpa penjelasan.
        expect(answer.detail, isNotEmpty, reason: question.id);
      }
    });
  });

  group('tugas mendesak', () {
    test('memilih tenggat terdekat yang belum selesai', () {
      final input = QuestionInput(
        now: _now,
        tasks: [
          _task(deadline: _daysAgo(-10), title: 'Jauh'),
          _task(deadline: _daysAgo(-2), title: 'Dekat'),
          _task(deadline: _daysAgo(-1), title: 'Selesai', completedAt: _daysAgo(3)),
        ],
      );

      final answer = _jawab('tugas-mendesak', input);
      expect(answer.headline, 'Dekat');
      expect(answer.detail, contains('2 hari lagi'));
    });

    test('tugas lewat tenggat ditandai perhatian', () {
      final input = QuestionInput(
        now: _now,
        tasks: [_task(deadline: _daysAgo(3), title: 'Telat')],
      );

      final answer = _jawab('tugas-mendesak', input);
      expect(answer.detail, contains('Sudah lewat 3 hari'));
      expect(answer.tone, AnswerTone.perhatian);
    });

    test('semua selesai bukan keadaan kosong', () {
      final input = QuestionInput(
        now: _now,
        tasks: [_task(deadline: _daysAgo(5), completedAt: _daysAgo(6))],
      );

      final answer = _jawab('tugas-mendesak', input);
      expect(answer.kosong, isFalse);
      expect(answer.tone, AnswerTone.bagus);
    });
  });

  group('ketepatan waktu', () {
    test('dihitung dari tugas yang selesai saja', () {
      final input = QuestionInput(
        now: _now,
        tasks: [
          _task(deadline: _daysAgo(5), completedAt: _daysAgo(7)),
          _task(deadline: _daysAgo(5), completedAt: _daysAgo(6)),
          _task(deadline: _daysAgo(5), completedAt: _daysAgo(3)),
          _task(deadline: _daysAgo(-3)),
        ],
      );

      final answer = _jawab('tepat-waktu', input);
      expect(answer.headline, '67%');
      expect(answer.detail, contains('2 dari 3'));
    });

    test('nilai tinggi ditandai bagus, rendah ditandai perhatian', () {
      final bagus = QuestionInput(
        now: _now,
        tasks: [
          for (var i = 0; i < 5; i++)
            _task(deadline: _daysAgo(5), completedAt: _daysAgo(6)),
        ],
      );
      expect(_jawab('tepat-waktu', bagus).tone, AnswerTone.bagus);

      final buruk = QuestionInput(
        now: _now,
        tasks: [
          for (var i = 0; i < 5; i++)
            _task(deadline: _daysAgo(6), completedAt: _daysAgo(3)),
        ],
      );
      expect(_jawab('tepat-waktu', buruk).tone, AnswerTone.perhatian);
    });
  });

  group('latihan', () {
    test('beban terberat menyebut nama latihannya', () {
      final input = QuestionInput(
        now: _now,
        sessions: [
          _session(_daysAgo(5), [_entry('Bench Press', weight: 60)]),
          _session(_daysAgo(3), [_entry('Deadlift', weight: 100)]),
        ],
      );

      final answer = _jawab('beban-terberat', input);
      expect(answer.headline, '100 kg');
      expect(answer.detail, contains('Deadlift'));
    });

    test('hari olahraga tidak dihitung dua kali', () {
      final hari = _daysAgo(2);
      final input = QuestionInput(
        now: _now,
        sessions: [_session(hari), _session(hari)],
        runs: [_run(hari, 5000, 1800)],
      );

      // Satu hari yang sama, tiga catatan — tetap satu hari.
      expect(_jawab('olahraga-bulan-ini', input).headline, '1 hari');
    });

    test('volume hanya dari latihan berbeban', () {
      final input = QuestionInput(
        now: _now,
        sessions: [
          _session(_daysAgo(2), [_entry('Bench Press', weight: 40, sets: 3, reps: 10)]),
        ],
      );

      expect(_jawab('total-volume', input).headline, '1.200 kg');
    });
  });

  group('lari', () {
    test('pace terbaik mengabaikan lari di bawah 1 km', () {
      final input = QuestionInput(
        now: _now,
        runs: [
          // 200 m dalam 30 detik = pace 2:30/km. Terlalu pendek untuk dipercaya.
          _run(_daysAgo(5), 200, 30),
          // 5 km dalam 25 menit = 5:00/km.
          _run(_daysAgo(3), 5000, 1500),
        ],
      );

      final answer = _jawab('pace-terbaik', input);
      expect(answer.headline, '5:00 /km');
    });

    test('tanpa lari sejauh 1 km, jawabannya kosong', () {
      final input = QuestionInput(
        now: _now,
        runs: [_run(_daysAgo(2), 500, 120)],
      );

      expect(_jawab('pace-terbaik', input).kosong, isTrue);
    });

    test('lari terjauh menyebut durasinya', () {
      final input = QuestionInput(
        now: _now,
        runs: [_run(_daysAgo(5), 3000, 1200), _run(_daysAgo(2), 8000, 2700)],
      );

      final answer = _jawab('lari-terjauh', input);
      expect(answer.headline, '8.00 km');
      expect(answer.detail, contains('45:00'));
    });
  });

  group('makan', () {
    test('rata-rata dibagi hari tercatat, bukan panjang periode', () {
      // Satu hari 2000 kkal dalam 30 hari: rata-ratanya 2000, bukan 2000/30.
      final input = QuestionInput(
        now: _now,
        foods: [_food(_daysAgo(2), calories: 2000)],
      );

      final answer = _jawab('rata-kalori', input);
      expect(answer.headline, '2.000 kkal');
      expect(answer.detail, contains('1 hari'));
    });

    test('beberapa catatan di hari sama dijumlahkan dulu', () {
      final hari = _daysAgo(2);
      final input = QuestionInput(
        now: _now,
        foods: [
          _food(hari, calories: 600),
          _food(hari, calories: 400),
          _food(_daysAgo(3), calories: 500),
        ],
      );

      // Hari pertama 1000, hari kedua 500 -> rata-rata 750.
      expect(_jawab('rata-kalori', input).headline, '750 kkal');
    });

    test('hari terlewat dihitung dari rentang 30 hari', () {
      final input = QuestionInput(
        now: _now,
        foods: [_food(_daysAgo(1)), _food(_daysAgo(2))],
      );

      final answer = _jawab('hari-lupa-catat', input);
      expect(answer.headline, '28 hari');
      expect(answer.tone, AnswerTone.perhatian);
    });
  });

  group('keuangan', () {
    test('hari terboros menjumlahkan transaksi di hari yang sama', () {
      final input = QuestionInput(
        now: _now,
        transactions: [
          _tx(_daysAgo(5), 30000),
          _tx(_daysAgo(5), 40000),
          _tx(_daysAgo(2), 60000),
        ],
      );

      // 70.000 di hari ke-5 mengalahkan 60.000 di hari ke-2.
      expect(_jawab('hari-terboros', input).headline, 'Rp70.000');
    });

    test('kategori terbesar menyebut persentasenya', () {
      final summary = summarize(
        transactions: [
          _tx(DateTime(2026, 8, 1), 750000, category: TxCategory.belanja),
          _tx(DateTime(2026, 8, 2), 250000, category: TxCategory.makan),
        ],
        now: _now,
      );

      final answer = _jawab(
        'kategori-terbesar',
        QuestionInput(now: _now, finance: summary),
      );

      expect(answer.headline, 'Belanja');
      expect(answer.detail, contains('75%'));
    });
  });

  group('lintas data — pengaman sampel kecil', () {
    test('kurang dari 3 tugas per kelompok tidak disimpulkan', () {
      final input = QuestionInput(
        now: _now,
        sessions: [_session(_daysAgo(5))],
        tasks: [
          _task(deadline: _daysAgo(3), completedAt: _daysAgo(5)),
          _task(deadline: _daysAgo(3), completedAt: _daysAgo(4)),
        ],
      );

      expect(_jawab('olahraga-vs-tugas', input).kosong, isTrue);
    });

    test('selisih di bawah setengah hari dianggap tidak berbeda', () {
      final sessions = <WorkoutSession>[];
      final tasks = <AcademicTask>[];

      // Tiga tugas di hari olahraga, tiga di hari biasa — sama-sama 2 hari awal.
      for (var i = 0; i < 3; i++) {
        final hari = _daysAgo(20 - i);
        sessions.add(_session(hari));
        tasks.add(_task(deadline: hari.add(const Duration(days: 2)), completedAt: hari));
      }
      for (var i = 0; i < 3; i++) {
        final hari = _daysAgo(10 - i);
        tasks.add(_task(deadline: hari.add(const Duration(days: 2)), completedAt: hari));
      }

      final answer = _jawab(
        'olahraga-vs-tugas',
        QuestionInput(now: _now, sessions: sessions, tasks: tasks),
      );
      expect(answer.headline, 'Tidak berbeda');
    });

    test('perbedaan nyata dilaporkan beserta ukuran sampelnya', () {
      final sessions = <WorkoutSession>[];
      final tasks = <AcademicTask>[];

      // Hari olahraga: selesai 4 hari sebelum tenggat.
      for (var i = 0; i < 3; i++) {
        final hari = _daysAgo(20 - i);
        sessions.add(_session(hari));
        tasks.add(_task(deadline: hari.add(const Duration(days: 4)), completedAt: hari));
      }
      // Hari biasa: selesai tepat di tenggat.
      for (var i = 0; i < 3; i++) {
        final hari = _daysAgo(10 - i);
        tasks.add(_task(deadline: hari, completedAt: hari));
      }

      final answer = _jawab(
        'olahraga-vs-tugas',
        QuestionInput(now: _now, sessions: sessions, tasks: tasks),
      );

      expect(answer.headline, contains('lebih awal'));
      expect(answer.detail, contains('bukan sebab-akibat'));
      expect(answer.detail, contains('3 tugas di hari olahraga'));
    });

    test('arah sebaliknya dilaporkan apa adanya', () {
      final sessions = <WorkoutSession>[];
      final tasks = <AcademicTask>[];

      // Hari olahraga justru lebih mepet.
      for (var i = 0; i < 3; i++) {
        final hari = _daysAgo(20 - i);
        sessions.add(_session(hari));
        tasks.add(_task(deadline: hari, completedAt: hari));
      }
      for (var i = 0; i < 3; i++) {
        final hari = _daysAgo(10 - i);
        tasks.add(_task(deadline: hari.add(const Duration(days: 4)), completedAt: hari));
      }

      expect(
        _jawab(
          'olahraga-vs-tugas',
          QuestionInput(now: _now, sessions: sessions, tasks: tasks),
        ).headline,
        contains('lebih mepet'),
      );
    });

    test('kalori di hari olahraga dibanding hari biasa', () {
      final sessions = <WorkoutSession>[];
      final foods = <FoodLog>[];

      for (var i = 0; i < 3; i++) {
        final hari = _daysAgo(20 - i);
        sessions.add(_session(hari));
        foods.add(_food(hari, calories: 2500));
      }
      for (var i = 0; i < 3; i++) {
        foods.add(_food(_daysAgo(10 - i), calories: 1800));
      }

      final answer = _jawab(
        'olahraga-vs-makan',
        QuestionInput(now: _now, sessions: sessions, foods: foods),
      );

      expect(answer.headline, contains('700 kkal'));
      expect(answer.headline, contains('lebih banyak'));
    });

    test('selisih kalori di bawah 100 dianggap sama', () {
      final sessions = <WorkoutSession>[];
      final foods = <FoodLog>[];

      for (var i = 0; i < 3; i++) {
        final hari = _daysAgo(20 - i);
        sessions.add(_session(hari));
        foods.add(_food(hari, calories: 2050));
      }
      for (var i = 0; i < 3; i++) {
        foods.add(_food(_daysAgo(10 - i), calories: 2000));
      }

      expect(
        _jawab(
          'olahraga-vs-makan',
          QuestionInput(now: _now, sessions: sessions, foods: foods),
        ).headline,
        'Kurang lebih sama',
      );
    });
  });

  group('nilai', () {
    test('IPK ditimbang sks, dan matkul tanpa nilai dilaporkan', () {
      final jawaban = _jawab(
        'ipk-sekarang',
        QuestionInput(
          now: _now,
          grades: [
            _matkul('a', 'Basis Data', 'A', sks: 4),
            _matkul('b', 'Kalkulus', 'B', sks: 2),
            const CourseGrade(
              courseId: 'c',
              courseName: 'Belum dinilai',
              sks: 3,
              semester: null,
              components: [],
            ),
          ],
        ),
      );

      // (4.0*4 + 3.0*2) / 6 = 3.67
      expect(jawaban.headline, '3.67');
      expect(jawaban.detail, contains('1 mata kuliah lain'));
    });

    test('tanpa nilai apa pun mengarahkan ke halaman Nilai', () {
      final jawaban = _jawab('ipk-sekarang', QuestionInput(now: _now));
      expect(jawaban.kosong, isTrue);
      expect(jawaban.detail, contains('KHS'));
    });

    test('matkul terbaik dan terlemah', () {
      final input = QuestionInput(
        now: _now,
        grades: [
          _matkul('a', 'Basis Data', 'A'),
          _matkul('b', 'Kalkulus', 'C'),
          _matkul('c', 'Jaringan', 'B'),
        ],
      );

      expect(_jawab('matkul-terbaik', input).headline, 'Basis Data');
      expect(_jawab('matkul-terlemah', input).headline, 'Kalkulus');
    });

    test('skala yang dipilih menentukan bobotnya', () {
      // AB tidak ada di skala plus-minus, tapi bobotnya tetap terbaca 3.50.
      final jawaban = _jawab(
        'ipk-sekarang',
        QuestionInput(
          now: _now,
          grades: [_matkul('a', 'Basis Data', 'AB', sks: 2)],
          gradeScale: GradeScale.setengah,
        ),
      );
      expect(jawaban.headline, '3.50');
    });
  });

  group('nilai-vs-telat', () {
    /// Empat matkul: dua tugasnya selalu telat, dua selalu tepat waktu.
    QuestionInput susun({required String hurufTelat, required String hurufTepat}) {
      final tasks = <AcademicTask>[];
      for (final id in ['telat1', 'telat2']) {
        for (var i = 0; i < 3; i++) {
          tasks.add(_tugasMatkul(
            id,
            deadline: _daysAgo(20 - i),
            selesai: _daysAgo(18 - i), // lewat deadline
          ));
        }
      }
      for (final id in ['tepat1', 'tepat2']) {
        for (var i = 0; i < 3; i++) {
          tasks.add(_tugasMatkul(
            id,
            deadline: _daysAgo(20 - i),
            selesai: _daysAgo(22 - i), // sebelum deadline
          ));
        }
      }

      return QuestionInput(
        now: _now,
        tasks: tasks,
        grades: [
          _matkul('telat1', 'Telat A', hurufTelat),
          _matkul('telat2', 'Telat B', hurufTelat),
          _matkul('tepat1', 'Tepat A', hurufTepat),
          _matkul('tepat2', 'Tepat B', hurufTepat),
        ],
      );
    }

    test('selisih nyata dilaporkan beserta peringatan bukan sebab-akibat', () {
      final jawaban = _jawab(
        'nilai-vs-telat',
        susun(hurufTelat: 'C', hurufTepat: 'A'),
      );

      expect(jawaban.headline, '2.00 poin lebih rendah');
      expect(jawaban.detail, contains('bukan sebab-akibat'));
      expect(jawaban.tone, AnswerTone.perhatian);
    });

    test('selisih terlalu kecil disebut tidak berbeda', () {
      final jawaban = _jawab(
        'nilai-vs-telat',
        susun(hurufTelat: 'A', hurufTepat: 'A'),
      );
      expect(jawaban.headline, 'Tidak berbeda');
    });

    test('kurang dari dua matkul per kelompok belum bisa dibandingkan', () {
      final jawaban = _jawab(
        'nilai-vs-telat',
        QuestionInput(
          now: _now,
          grades: [_matkul('a', 'Basis Data', 'A')],
          tasks: [
            _tugasMatkul('a', deadline: _daysAgo(10), selesai: _daysAgo(12)),
            _tugasMatkul('a', deadline: _daysAgo(9), selesai: _daysAgo(11)),
          ],
        ),
      );
      expect(jawaban.kosong, isTrue);
    });

    test('matkul dengan satu tugas saja tidak ikut dinilai kebiasaannya', () {
      // Satu tugas telat itu satu kejadian, bukan pola.
      final input = susun(hurufTelat: 'C', hurufTepat: 'A');
      final hanyaSatu = QuestionInput(
        now: _now,
        grades: input.grades,
        tasks: [input.tasks.first],
      );
      expect(_jawab('nilai-vs-telat', hanyaSatu).kosong, isTrue);
    });
  });

  group('air', () {
    test('rata-rata dibagi hari yang tercatat, bukan 30', () {
      // Dua hari tercatat 2000 ml. Kalau dibagi 30, hasilnya 133 ml.
      final jawaban = _jawab(
        'air-harian',
        QuestionInput(
          now: _now,
          waters: [_air(_daysAgo(1), 2000), _air(_daysAgo(2), 2000)],
        ),
      );
      expect(jawaban.headline, '2000 ml');
      expect(jawaban.detail, contains('2 hari yang tercatat'));
    });

    test('beberapa catatan di hari yang sama dijumlahkan', () {
      final jawaban = _jawab(
        'air-harian',
        QuestionInput(
          now: _now,
          waters: [_air(_daysAgo(1), 750), _air(_daysAgo(1), 1250)],
        ),
      );
      expect(jawaban.headline, '2000 ml');
    });

    test('catatan di luar 30 hari tidak ikut', () {
      final jawaban = _jawab(
        'air-harian',
        QuestionInput(now: _now, waters: [_air(_daysAgo(40), 3000)]),
      );
      expect(jawaban.kosong, isTrue);
    });

    test('hari kurang minum dihitung dari hari tercatat saja', () {
      final jawaban = _jawab(
        'hari-kurang-air',
        QuestionInput(
          now: _now,
          waters: [
            _air(_daysAgo(1), 2500),
            _air(_daysAgo(2), 1000),
            _air(_daysAgo(3), 500),
          ],
        ),
      );
      expect(jawaban.headline, '2 hari');
      expect(jawaban.tone, AnswerTone.perhatian);
    });

    test('semua hari cukup ditandai kabar baik', () {
      final jawaban = _jawab(
        'hari-kurang-air',
        QuestionInput(now: _now, waters: [_air(_daysAgo(1), 2500)]),
      );
      expect(jawaban.headline, 'Tidak ada');
      expect(jawaban.tone, AnswerTone.bagus);
    });
  });
}
