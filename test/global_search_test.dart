import 'package:flutter_test/flutter_test.dart';
import 'package:tracking/features/academic/data/models/task.dart';
import 'package:tracking/features/finance/domain/transaction.dart';
import 'package:tracking/features/nutrition/domain/food_log.dart';
import 'package:tracking/features/search/domain/global_search.dart';
import 'package:tracking/features/workout/data/models/exercise_entry.dart';
import 'package:tracking/features/workout/data/models/workout_session.dart';

final _now = DateTime(2026, 8, 1);

AcademicTask _tugas(String judul, {String? deskripsi, DateTime? selesai}) =>
    AcademicTask(
      id: judul,
      userId: 'u',
      title: judul,
      description: deskripsi,
      deadline: _now,
      priority: TaskPriority.medium,
      status: TaskStatus.todo,
      createdAt: _now,
      completedAt: selesai,
    );

WorkoutSession _sesi(String id, List<String> latihan, {String? catatan}) =>
    WorkoutSession(
      id: id,
      userId: 'u',
      sessionDate: _now,
      notes: catatan,
      createdAt: _now,
      exercises: [
        for (final nama in latihan)
          ExerciseEntry(id: nama, sessionId: id, userId: 'u', exerciseName: nama),
      ],
    );

FoodLog _makan(String nama) => FoodLog(
      id: nama,
      loggedOn: _now,
      loggedAt: _now,
      name: nama,
      meal: Meal.sarapan,
      calories: 250,
      proteinG: 10,
      carbsG: 30,
      fatG: 8,
    );

Transaction _tx({String? produk, String? toko, String? catatan}) => Transaction(
      id: '${produk}_$toko',
      occurredOn: _now,
      kind: TxKind.pengeluaran,
      category: TxCategory.makan,
      amount: 25000,
      product: produk,
      merchant: toko,
      note: catatan,
    );

void main() {
  group('searchAll — dasar', () {
    test('kurang dari dua huruf tidak mencari apa pun', () {
      final hasil = searchAll(query: 'a', tasks: [_tugas('Analisis')]);
      expect(hasil, isEmpty);
    });

    test('kueri kosong tidak mencari apa pun', () {
      final hasil = searchAll(query: '   ', tasks: [_tugas('Analisis')]);
      expect(hasil, isEmpty);
    });

    test('tanpa data apa pun tidak error', () {
      expect(searchAll(query: 'apa saja'), isEmpty);
    });

    test('tidak peduli huruf besar-kecil', () {
      final hasil = searchAll(query: 'ANALISIS', tasks: [_tugas('Analisis Data')]);
      expect(hasil, hasLength(1));
    });
  });

  group('searchAll — per jenis', () {
    test('tugas dicari lewat judul dan deskripsi', () {
      final hasil = searchAll(
        query: 'regresi',
        tasks: [
          _tugas('Statistika', deskripsi: 'Bab regresi linear'),
          _tugas('Kalkulus'),
        ],
      );
      expect(hasil, hasLength(1));
      expect(hasil.first.title, 'Statistika');
    });

    test('sesi dicari lewat nama latihan di dalamnya', () {
      final hasil = searchAll(
        query: 'bench',
        sessions: [
          _sesi('a', ['Bench Press', 'Squat']),
          _sesi('b', ['Deadlift']),
        ],
      );
      expect(hasil, hasLength(1));
      expect(hasil.first.title, 'Bench Press');
    });

    test('latihan yang tidak cocok tidak ikut disebut di judul', () {
      final hasil = searchAll(
        query: 'squat',
        sessions: [
          _sesi('a', ['Bench Press', 'Squat', 'Squat Jump']),
        ],
      );
      expect(hasil.first.title, 'Squat, Squat Jump');
      expect(hasil.first.title, isNot(contains('Bench')));
    });

    test('transaksi dicari lewat produk, toko, dan catatan', () {
      final hasil = searchAll(
        query: 'martabak',
        transactions: [
          _tx(produk: 'Martabak telor', toko: 'ShopeeFood'),
          _tx(produk: 'Nasi goreng', toko: 'Warung'),
          _tx(toko: 'Kedai', catatan: 'beli martabak buat teman'),
        ],
      );
      expect(hasil, hasLength(2));
    });

    test('makanan dicari lewat namanya', () {
      final hasil = searchAll(query: 'indomie', foods: [_makan('Indomie Goreng')]);
      expect(hasil, hasLength(1));
      expect(hasil.first.subtitle, contains('250 kkal'));
    });
  });

  group('searchAll — urutan dan batas', () {
    test('dikelompokkan per jenis mengikuti urutan enum', () {
      final hasil = searchAll(
        query: 'pagi',
        tasks: [_tugas('Kuliah pagi')],
        foods: [_makan('Sarapan pagi')],
        transactions: [_tx(produk: 'Kopi pagi')],
      );

      expect(
        hasil.map((h) => h.kind),
        [SearchKind.tugas, SearchKind.makanan, SearchKind.transaksi],
      );
    });

    test('tiap jenis dibatasi supaya tidak menenggelamkan yang lain', () {
      final hasil = searchAll(
        query: 'tugas',
        tasks: [for (var i = 0; i < 20; i++) _tugas('Tugas $i')],
        foods: [_makan('Makan tugas')],
      );

      final tugas = hasil.where((h) => h.kind == SearchKind.tugas);
      expect(tugas, hasLength(kMaxPerKind));
      // Makanannya tetap muncul meski tugasnya ada 20.
      expect(hasil.any((h) => h.kind == SearchKind.makanan), isTrue);
    });

    test('tugas yang selesai ditandai, bukan disembunyikan', () {
      final hasil = searchAll(
        query: 'laporan',
        tasks: [_tugas('Laporan praktikum', selesai: _now)],
      );
      expect(hasil.first.subtitle, 'Selesai');
    });
  });

  group('groupHits', () {
    test('mengelompokkan tanpa mengubah isi', () {
      final hasil = searchAll(
        query: 'pagi',
        tasks: [_tugas('Kuliah pagi')],
        foods: [_makan('Sarapan pagi')],
      );
      final grouped = groupHits(hasil);

      expect(grouped.keys, hasLength(2));
      expect(grouped[SearchKind.tugas], hasLength(1));
    });

    test('daftar kosong menghasilkan kelompok kosong', () {
      expect(groupHits(const []), isEmpty);
    });
  });
}
