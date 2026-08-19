import 'package:flutter_test/flutter_test.dart';
import 'package:tracking/features/academic/data/models/course.dart';
import 'package:tracking/features/academic/data/models/task.dart';
import 'package:tracking/features/document/domain/document.dart';
import 'package:tracking/features/finance/domain/transaction.dart';
import 'package:tracking/features/goals/domain/goal.dart';
import 'package:tracking/features/note/domain/note.dart';
import 'package:tracking/features/nutrition/domain/food_log.dart';
import 'package:tracking/features/search/domain/global_search.dart';
import 'package:tracking/features/vehicle/domain/vehicle.dart';
import 'package:tracking/features/watchlist/domain/watchlist.dart';
import 'package:tracking/features/wishlist/domain/wishlist.dart';
import 'package:tracking/features/workout/data/models/exercise_entry.dart';
import 'package:tracking/features/workout/data/models/workout_session.dart';

final _now = DateTime(2026, 8, 1);

Note _catatan(String isi, {String? judul}) => Note(
      id: 'n-$isi',
      userId: 'u',
      title: judul,
      body: isi,
      createdAt: _now,
      updatedAt: _now,
    );

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

Course _matkul(String nama, {String? dosen, int? sks}) => Course(
      id: nama,
      userId: 'u',
      name: nama,
      lecturer: dosen,
      sks: sks,
      createdAt: _now,
    );

WishlistItem _barang(String nama, {double? harga, String? catatan}) =>
    WishlistItem(id: nama, name: nama, price: harga, note: catatan);

MediaItem _tontonan(String judul, {MediaKind kind = MediaKind.series, String? catatan}) =>
    MediaItem(id: judul, title: judul, kind: kind, note: catatan, createdAt: _now);

Vehicle _kendaraan(String nama, {String? nopol}) =>
    Vehicle(id: nama, name: nama, plate: nopol, createdAt: _now);

ServiceLog _servis(String vehicleId, {String? catatan}) => ServiceLog(
      id: '$vehicleId-servis',
      vehicleId: vehicleId,
      kind: ServiceKind.oli,
      doneOn: _now,
      note: catatan,
    );

Document _dokumen(String nama, {DocKind kind = DocKind.sim, String? nomor}) => Document(
      id: nama,
      name: nama,
      kind: kind,
      number: nomor,
      createdAt: _now,
    );

Goal _target(String judul, {bool arsip = false}) => Goal(
      id: judul,
      title: judul,
      metric: GoalMetric.jarakLari,
      targetValue: 20,
      period: GoalPeriod.mingguan,
      archived: arsip,
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

  group('searchAll — sumber yang dulu tertinggal', () {
    test('mata kuliah dicari lewat nama dan dosen', () {
      final hasil = searchAll(
        query: 'slamet',
        courses: [_matkul('Basis Data', dosen: 'Pak Slamet', sks: 3)],
      );

      expect(hasil.single.kind, SearchKind.matkul);
      expect(hasil.single.subtitle, contains('3 sks'));
    });

    test('wishlist dicari lewat nama dan catatan', () {
      final hasil = searchAll(
        query: 'mekanik',
        wishlist: [_barang('Keyboard', catatan: 'Yang mekanik, switch merah')],
      );

      expect(hasil.single.kind, SearchKind.wishlist);
    });

    test('barang tanpa harga mengatakannya, bukan menampilkan nol', () {
      final hasil = searchAll(query: 'keyboard', wishlist: [_barang('Keyboard')]);
      expect(hasil.single.subtitle, 'Harga belum diisi');
    });

    test('watchlist dicari lewat judul', () {
      final hasil = searchAll(query: 'frieren', media: [_tontonan('Frieren')]);
      expect(hasil.single.kind, SearchKind.tontonan);
      expect(hasil.single.subtitle, contains('Series'));
    });

    test('kendaraan dicari lewat nama maupun nopol', () {
      final hasil = searchAll(
        query: 'l 1234',
        vehicles: [_kendaraan('Beat', nopol: 'L 1234 AB')],
      );

      expect(hasil.single.kind, SearchKind.kendaraan);
      expect(hasil.single.tujuan, '/vehicle/Beat');
    });

    test('catatan servis ikut tercari dan menunjuk kendaraannya', () {
      final hasil = searchAll(
        query: 'ahass',
        vehicles: [_kendaraan('Beat')],
        services: [_servis('Beat', catatan: 'Servis di AHASS depan kampus')],
      );

      expect(hasil.single.title, 'Oli mesin Beat');
      expect(hasil.single.tujuan, '/vehicle/Beat');
    });

    test('dokumen dicari lewat nama dan jenisnya', () {
      final hasil = searchAll(query: 'paspor', documents: [_dokumen('Paspor', kind: DocKind.paspor)]);
      expect(hasil.single.kind, SearchKind.dokumen);
    });

    test('nomor dokumen tidak ikut dicari dan tidak ikut ditampilkan', () {
      final nomor = '3578011234567890';
      final hasil = searchAll(query: nomor, documents: [_dokumen('KTP', nomor: nomor)]);

      expect(hasil, isEmpty);

      final lewatNama = searchAll(query: 'ktp', documents: [_dokumen('KTP', nomor: nomor)]);
      expect(lewatNama.single.subtitle, isNot(contains('3578')));
    });

    test('catatan dicari lewat judul maupun isinya', () {
      final lewatJudul = searchAll(
        query: 'wifi',
        notes: [_catatan('kosanpakdhe2024', judul: 'Wifi kos')],
      );
      expect(lewatJudul.single.kind, SearchKind.catatan);

      // Ini yang paling penting untuk catatan bebas: judulnya sering memang
      // tidak pernah diisi, jadi kalau isinya tidak ikut dicari, catatannya
      // praktis tidak bisa ditemukan lagi.
      final lewatIsi = searchAll(
        query: 'rekening',
        notes: [_catatan('Nomor rekening Rian\n1234567890 BCA')],
      );
      expect(lewatIsi.single.title, 'Nomor rekening Rian');
      expect(lewatIsi.single.tujuan, startsWith('/notes/'));
    });

    test('target dicari lewat judul, yang diarsipkan dilewati', () {
      final hasil = searchAll(
        query: 'lari',
        goals: [_target('Lari rutin'), _target('Lari lama', arsip: true)],
      );

      expect(hasil, hasLength(1));
      expect(hasil.single.kind, SearchKind.target);
    });

    test('yang tidak punya tanggal turun ke bawah dan diurut abjad', () {
      final hasil = searchAll(
        query: 'beli',
        wishlist: [_barang('Beli Zulu'), _barang('Beli Alfa')],
      );

      expect(hasil.map((h) => h.title).toList(), ['Beli Alfa', 'Beli Zulu']);
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
