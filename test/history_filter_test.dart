import 'package:flutter_test/flutter_test.dart';
import 'package:tracking/features/workout/data/models/exercise_entry.dart';
import 'package:tracking/features/workout/data/models/workout_session.dart';
import 'package:tracking/features/workout/data/rest_day_repository.dart';
import 'package:tracking/features/workout/domain/history_filter.dart';

final _now = DateTime(2026, 8, 1);

DateTime _lalu(int hari) => _now.subtract(Duration(days: hari));

ExerciseEntry _latihan(
  String nama, {
  ExerciseType type = ExerciseType.beban,
  double? weightKg = 50,
  int? sets = 3,
  int? reps = 10,
  int? durationMinutes,
}) =>
    ExerciseEntry(
      id: '$nama-$type',
      sessionId: 's',
      userId: 'u',
      exerciseName: nama,
      type: type,
      weightKg: weightKg,
      sets: sets,
      reps: reps,
      durationMinutes: durationMinutes,
    );

WorkoutSession _sesi(
  String id,
  DateTime tanggal,
  List<ExerciseEntry> latihan,
) =>
    WorkoutSession(
      id: id,
      userId: 'u',
      sessionDate: tanggal,
      createdAt: tanggal,
      exercises: latihan,
    );

RestDay _istirahat(String id, DateTime tanggal) =>
    RestDay(id: id, restOn: tanggal);

List<HistoryRow> _saring({
  List<WorkoutSession> sessions = const [],
  List<RestDay> restDays = const [],
  HistoryFilter filter = const HistoryFilter(period: HistoryPeriod.semua),
}) =>
    filterHistory(
      sessions: sessions,
      restDays: restDays,
      filter: filter,
      now: _now,
    );

void main() {
  group('HistoryPeriod', () {
    test('30 hari mencakup hari ini sampai 29 hari lalu', () {
      expect(HistoryPeriod.tigaPuluhHari.contains(_lalu(0), _now), isTrue);
      expect(HistoryPeriod.tigaPuluhHari.contains(_lalu(29), _now), isTrue);
      expect(HistoryPeriod.tigaPuluhHari.contains(_lalu(30), _now), isFalse);
    });

    test('3 bulan lebih longgar dari 30 hari', () {
      expect(HistoryPeriod.tigaBulan.contains(_lalu(60), _now), isTrue);
      expect(HistoryPeriod.tigaBulan.contains(_lalu(90), _now), isFalse);
    });

    test('tahun ini memakai angka tahun, bukan hitung mundur', () {
      expect(HistoryPeriod.tahunIni.contains(DateTime(2026, 1, 1), _now), isTrue);
      expect(HistoryPeriod.tahunIni.contains(DateTime(2025, 12, 31), _now), isFalse);
    });

    test('semua tidak menolak apa pun', () {
      expect(HistoryPeriod.semua.contains(DateTime(2020, 1, 1), _now), isTrue);
    });

    test('jam pada tanggal tidak menggeser batas', () {
      // Sesi jam 23.00 di hari ke-29 harus tetap masuk.
      final malam = DateTime(_lalu(29).year, _lalu(29).month, _lalu(29).day, 23);
      expect(HistoryPeriod.tigaPuluhHari.contains(malam, _now), isTrue);
    });
  });

  group('filterHistory', () {
    final sesiBeban = _sesi('a', _lalu(1), [_latihan('Bench Press')]);
    final sesiCardio = _sesi('b', _lalu(2), [
      _latihan('Lari Treadmill',
          type: ExerciseType.cardio,
          weightKg: null,
          sets: null,
          reps: null,
          durationMinutes: 30),
    ]);
    final sesiLama = _sesi('c', _lalu(200), [_latihan('Squat')]);
    final rehat = _istirahat('r1', _lalu(3));

    test('urut dari yang terbaru', () {
      final hasil = _saring(
        sessions: [sesiLama, sesiBeban, sesiCardio],
        restDays: [rehat],
      );
      expect(hasil.map((r) => r.tanggal), [
        _lalu(1),
        _lalu(2),
        _lalu(3),
        _lalu(200),
      ]);
    });

    test('periode membuang yang di luar rentang', () {
      final hasil = _saring(
        sessions: [sesiBeban, sesiLama],
        filter: const HistoryFilter(period: HistoryPeriod.tigaPuluhHari),
      );
      expect(hasil, hasLength(1));
      expect(hasil.first.session!.id, 'a');
    });

    test('jenis menyaring per tipe latihan', () {
      final hasil = _saring(
        sessions: [sesiBeban, sesiCardio],
        filter: const HistoryFilter(
          period: HistoryPeriod.semua,
          kind: HistoryKind.cardio,
        ),
      );
      expect(hasil, hasLength(1));
      expect(hasil.first.session!.id, 'b');
    });

    test('saringan jenis membuang hari istirahat', () {
      // Hari istirahat tidak punya latihan bertipe apa pun; menampilkannya
      // saat menyaring "Beban" itu jawaban yang salah.
      final hasil = _saring(
        sessions: [sesiBeban],
        restDays: [rehat],
        filter: const HistoryFilter(
          period: HistoryPeriod.semua,
          kind: HistoryKind.beban,
        ),
      );
      expect(hasil.any((r) => r.isRest), isFalse);
    });

    test('jenis istirahat hanya menampilkan hari istirahat', () {
      final hasil = _saring(
        sessions: [sesiBeban, sesiCardio],
        restDays: [rehat],
        filter: const HistoryFilter(
          period: HistoryPeriod.semua,
          kind: HistoryKind.istirahat,
        ),
      );
      expect(hasil, hasLength(1));
      expect(hasil.first.isRest, isTrue);
    });

    test('pencarian nama latihan tidak peduli huruf besar-kecil', () {
      final hasil = _saring(
        sessions: [sesiBeban, sesiCardio],
        filter: const HistoryFilter(period: HistoryPeriod.semua, query: 'bench'),
      );
      expect(hasil, hasLength(1));
      expect(hasil.first.session!.id, 'a');
    });

    test('pencarian membuang hari istirahat', () {
      final hasil = _saring(
        sessions: [sesiBeban],
        restDays: [rehat],
        filter: const HistoryFilter(period: HistoryPeriod.semua, query: 'bench'),
      );
      expect(hasil.any((r) => r.isRest), isFalse);
    });

    test('pencarian berisi spasi saja dianggap kosong', () {
      final hasil = _saring(
        sessions: [sesiBeban],
        restDays: [rehat],
        filter: const HistoryFilter(period: HistoryPeriod.semua, query: '   '),
      );
      expect(hasil, hasLength(2));
    });

    test('tidak ada yang cocok menghasilkan daftar kosong, bukan error', () {
      final hasil = _saring(
        sessions: [sesiBeban],
        filter: const HistoryFilter(period: HistoryPeriod.semua, query: 'zumba'),
      );
      expect(hasil, isEmpty);
    });

    test('data kosong aman', () {
      expect(_saring(), isEmpty);
    });
  });

  group('summarizeHistory', () {
    test('menjumlah sesi, istirahat, dan volume', () {
      final rows = _saring(
        sessions: [
          _sesi('a', _lalu(1), [_latihan('Bench Press')]),
          _sesi('b', _lalu(2), [_latihan('Squat', weightKg: 80)]),
        ],
        restDays: [_istirahat('r', _lalu(3))],
      );

      final hasil = summarizeHistory(rows);
      expect(hasil.sesi, 2);
      expect(hasil.hariIstirahat, 1);
      // 50 x 3 x 10 + 80 x 3 x 10
      expect(hasil.volumeKg, 3900);
      expect(hasil.jumlahLatihan, 2);
    });

    test('saringan jenis membuat ringkasannya ikut menyempit', () {
      // Satu sesi berisi beban dan cardio sekaligus. Waktu menyaring cardio,
      // volume bebannya tidak boleh ikut terhitung — angkanya harus menjawab
      // pertanyaan yang barusan ditanyakan.
      final sesi = _sesi('a', _lalu(1), [
        _latihan('Bench Press'),
        _latihan('Sepeda',
            type: ExerciseType.cardio,
            weightKg: null,
            sets: null,
            reps: null,
            durationMinutes: 25),
      ]);

      final rows = _saring(
        sessions: [sesi],
        filter: const HistoryFilter(
          period: HistoryPeriod.semua,
          kind: HistoryKind.cardio,
        ),
      );

      final hasil = summarizeHistory(rows, kind: HistoryKind.cardio);
      expect(hasil.sesi, 1);
      expect(hasil.jumlahLatihan, 1);
      expect(hasil.volumeKg, 0);
      expect(hasil.menitCardio, 25);
    });

    test('daftar kosong menghasilkan ringkasan kosong', () {
      final hasil = summarizeHistory(const []);
      expect(hasil.kosong, isTrue);
      expect(hasil.volumeKg, 0);
    });
  });

  group('HistoryFilter.aktif', () {
    test('bawaan 30 hari sudah dianggap menyaring', () {
      expect(const HistoryFilter().aktif, isTrue);
    });

    test('semua tanpa jenis dan tanpa pencarian berarti tidak menyaring', () {
      expect(
        const HistoryFilter(period: HistoryPeriod.semua).aktif,
        isFalse,
      );
    });
  });
}
