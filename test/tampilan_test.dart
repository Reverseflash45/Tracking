import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracking/core/theme/app_colors.dart';
import 'package:tracking/core/theme/app_theme.dart';
import 'package:tracking/core/widgets/empty_state.dart';
import 'package:tracking/core/widgets/hero_header.dart';
import 'package:tracking/core/widgets/menu_list.dart';
import 'package:tracking/core/widgets/section_header.dart';
import 'package:tracking/features/academic/data/models/class_schedule.dart';
import 'package:tracking/features/academic/data/models/task.dart';
import 'package:tracking/features/academic/presentation/schedule_page.dart';
import 'package:tracking/features/academic/presentation/task_tile.dart';

/// Uji tampilan untuk widget yang dipakai bersama seluruh halaman.
///
/// Sampai sekarang 32 berkas test di app ini semuanya menguji logika, dan tidak
/// satu pun menyentuh tampilan. Artinya kalimat "775 test lolos" tidak pernah
/// membuktikan apa pun tentang apakah ada teks yang terpotong — dan tiap kali
/// tata letak diubah, satu-satunya cara tahu adalah memasang APK di HP.
///
/// Yang diuji di sini bukan "bagus atau tidak" — itu memang tidak bisa diuji.
/// Yang diuji: apakah widgetnya masih muat. Flutter melaporkan luber sebagai
/// error saat menggambar, jadi `takeException()` yang kosong berarti tidak ada
/// satu pun baris yang terpotong.
///
/// Tiga keadaan terburuk yang dipakai:
/// - lebar 320dp, HP Android tersempit yang masih beredar
/// - skala teks 1.3, setelan "ukuran huruf besar" di Android
/// - teks panjang, karena judul dan label di app ini datang dari isian pengguna
void main() {
  const lebarSempit = 320.0;
  const skalaBesar = 1.3;

  const judulPanjang = 'Praktikum Pemrograman Berorientasi Objek Lanjut';
  const keteranganPanjang =
      'Kumpulkan sebelum tengah malam di portal, jangan lewat email pribadi';

  /// Menggambar [child] di layar sesempit dan sebesar mungkin, lalu
  /// mengembalikan error yang muncul saat menggambar (null berarti aman).
  Future<Object?> gambar(
    WidgetTester tester,
    Widget child, {
    double lebar = lebarSempit,
    double skalaTeks = 1.0,
    Brightness kecerahan = Brightness.light,
  }) async {
    tester.view.physicalSize = Size(lebar, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: kecerahan == Brightness.dark ? AppTheme.dark() : AppTheme.light(),
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(skalaTeks)),
          child: Scaffold(
            body: SingleChildScrollView(child: child),
          ),
        ),
      ),
    );
    return tester.takeException();
  }

  const statsPenuh = [
    HeroStatData(icon: Icons.school_outlined, value: '24', label: 'Mata Kuliah'),
    HeroStatData(icon: Icons.timelapse, value: '132', label: 'Total SKS'),
    HeroStatData(icon: Icons.star_outline, value: '3.87', label: 'IPK Kumulatif'),
  ];

  // Pemeriksaan alat, bukan pemeriksaan app. Kalau ini lolos berarti
  // `gambar()` memang mengembalikan error saat ada yang terpotong — tanpa ini,
  // semua test di bawah bisa saja lolos karena alatnya buta, bukan karena
  // widgetnya muat.
  testWidgets('alat ujinya sendiri memang mendeteksi luber', (tester) async {
    final hasil = await gambar(
      tester,
      const Row(
        children: [
          SizedBox(width: 400, height: 20),
          SizedBox(width: 400, height: 20),
        ],
      ),
    );
    expect(hasil, isA<FlutterError>());
    expect(hasil.toString(), contains('overflow'));
  });

  group('HeroHeader bergradient', () {
    testWidgets('muat di layar sempit dengan judul panjang', (tester) async {
      expect(
        await gambar(
          tester,
          const HeroHeader(
            title: judulPanjang,
            subtitle: keteranganPanjang,
            color: AppColors.academic,
            stats: statsPenuh,
          ),
        ),
        isNull,
      );
    });

    testWidgets('muat saat huruf diperbesar 1.3x', (tester) async {
      expect(
        await gambar(
          tester,
          const HeroHeader(
            title: judulPanjang,
            subtitle: keteranganPanjang,
            color: AppColors.academic,
            stats: statsPenuh,
          ),
          skalaTeks: skalaBesar,
        ),
        isNull,
      );
    });

    testWidgets('muat dengan tombol di kanan dan tiga statistik', (tester) async {
      expect(
        await gambar(
          tester,
          HeroHeader(
            title: judulPanjang,
            color: AppColors.workout,
            stats: statsPenuh,
            trailing: HeroIconButton(
              icon: Icons.show_chart,
              tooltip: 'Progress',
              onPressed: () {},
            ),
          ),
          skalaTeks: skalaBesar,
        ),
        isNull,
      );
    });
  });

  group('HeroHeader.sub', () {
    testWidgets('muat di layar sempit dengan judul panjang', (tester) async {
      expect(
        await gambar(
          tester,
          const HeroHeader.sub(
            title: judulPanjang,
            subtitle: keteranganPanjang,
            color: AppColors.deadline,
            stats: statsPenuh,
          ),
        ),
        isNull,
      );
    });

    testWidgets('muat saat huruf diperbesar 1.3x', (tester) async {
      expect(
        await gambar(
          tester,
          const HeroHeader.sub(
            title: judulPanjang,
            subtitle: keteranganPanjang,
            color: AppColors.deadline,
            stats: statsPenuh,
          ),
          skalaTeks: skalaBesar,
        ),
        isNull,
      );
    });

    testWidgets('angka panjang di tiga statistik tidak saling mendorong', (tester) async {
      expect(
        await gambar(
          tester,
          const HeroHeader.sub(
            title: 'Keuangan',
            color: AppColors.finance,
            stats: [
              HeroStatData(icon: Icons.arrow_upward, value: 'Rp12.500.000', label: 'Pemasukan'),
              HeroStatData(icon: Icons.arrow_downward, value: 'Rp10.750.000', label: 'Pengeluaran'),
              HeroStatData(icon: Icons.savings_outlined, value: 'Rp1.750.000', label: 'Sisa'),
            ],
          ),
          skalaTeks: skalaBesar,
        ),
        isNull,
      );
    });
  });

  group('statistik progres latihan', () {
    testWidgets('rep, set, dan total muat bertiga di layar sempit', (tester) async {
      expect(
        await gambar(
          tester,
          const HeroHeader.sub(
            title: 'Barbell Bench Press',
            subtitle: 'Latihan Beban - progres beban',
            color: AppColors.workout,
            stats: [
              HeroStatData(icon: Icons.repeat, value: '12', label: 'Rep per Set'),
              HeroStatData(icon: Icons.layers_outlined, value: '5', label: 'Set'),
              HeroStatData(icon: Icons.functions, value: '2400 kg', label: 'Total'),
            ],
          ),
          skalaTeks: skalaBesar,
        ),
        isNull,
      );
    });
  });

  group('SectionHeader', () {
    testWidgets('judul panjang dengan tombol di kanan tidak meluber', (tester) async {
      expect(
        await gambar(
          tester,
          SectionHeader(
            title: judulPanjang,
            icon: Icons.today_outlined,
            color: AppColors.academic,
            trailing: TextButton(onPressed: () {}, child: const Text('Lihat semua')),
          ),
          skalaTeks: skalaBesar,
        ),
        isNull,
      );
    });
  });

  group('EmptyState', () {
    testWidgets('versi penuh muat dengan kalimat panjang', (tester) async {
      expect(
        await gambar(
          tester,
          const EmptyState(
            icon: Icons.inbox_outlined,
            title: 'Belum ada tugas yang tercatat',
            subtitle: keteranganPanjang,
            color: AppColors.deadline,
          ),
          skalaTeks: skalaBesar,
        ),
        isNull,
      );
    });

    testWidgets('versi ringkas muat di dalam kartu sempit', (tester) async {
      expect(
        await gambar(
          tester,
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: const EmptyState(
                icon: Icons.inbox_outlined,
                title: 'Tidak ada jadwal hari ini',
                subtitle: keteranganPanjang,
                color: AppColors.academic,
                compact: true,
              ),
            ),
          ),
          skalaTeks: skalaBesar,
        ),
        isNull,
      );
    });
  });

  group('MenuList', () {
    testWidgets('label dan keterangan panjang tidak meluber', (tester) async {
      expect(
        await gambar(
          tester,
          const MenuList(
            items: [
              MenuItemData(
                icon: Icons.local_fire_department,
                label: 'Kalkulator Kalori dan Kebutuhan Makro',
                rute: '/workout/calories',
                warna: AppColors.dashboard,
                keterangan: keteranganPanjang,
              ),
              MenuItemData(
                icon: Icons.badge_outlined,
                label: 'Dokumen',
                rute: '/documents',
                warna: AppColors.document,
              ),
            ],
          ),
          skalaTeks: skalaBesar,
        ),
        isNull,
      );
    });

    testWidgets('satu baris saja tidak menggambar garis pemisah', (tester) async {
      await gambar(
        tester,
        const MenuList(
          items: [
            MenuItemData(icon: Icons.flag_outlined, label: 'Target', rute: '/goals'),
          ],
        ),
      );
      expect(find.byType(Divider), findsNothing);
    });

    testWidgets('garis pemisah muncul di antara baris, bukan di ujung', (tester) async {
      await gambar(
        tester,
        const MenuList(
          items: [
            MenuItemData(icon: Icons.flag_outlined, label: 'Target', rute: '/goals'),
            MenuItemData(icon: Icons.movie_outlined, label: 'Watchlist', rute: '/watchlist'),
            MenuItemData(icon: Icons.two_wheeler, label: 'Kendaraan', rute: '/vehicle'),
          ],
        ),
      );
      // Tiga baris berarti dua pemisah. Kalau jadi tiga, berarti ada garis
      // menggantung di bawah baris terakhir.
      expect(find.byType(Divider), findsNWidgets(2));
    });
  });

  group('warna kategori', () {
    // Kesembilan warna ini dipakai sebagai ikon dan angka tebal di atas kartu,
    // di tema terang maupun gelap, dengan nilai yang sama untuk keduanya. Itu
    // cuma boleh kalau terangnya memang duduk di tengah — dan "di tengah" itu
    // hal yang bisa dihitung, bukan hal yang perlu dilihat.
    //
    // WCAG meminta rasio 3:1 untuk grafis dan teks besar. Kalau satu warna
    // gagal di salah satu tema, warna itu harus diganti, bukan dimaafkan.
    const kategori = {
      'Beranda': AppColors.dashboard,
      'Jadwal': AppColors.academic,
      'Tugas': AppColors.deadline,
      'Workout': AppColors.workout,
      'Keuangan': AppColors.finance,
      'Profil': AppColors.profile,
      'Watchlist': AppColors.watchlist,
      'Kendaraan': AppColors.vehicle,
      'Dokumen': AppColors.document,
      'Prioritas tinggi': AppColors.priorityHigh,
      'Prioritas sedang': AppColors.priorityMedium,
      'Prioritas rendah': AppColors.priorityLow,
      'Sedang dikerjakan': AppColors.statusInProgress,
      'Selesai': AppColors.statusDone,
    };

    double luminansi(Color c) => c.computeLuminance();

    double rasio(Color a, Color b) {
      final terang = luminansi(a) > luminansi(b) ? luminansi(a) : luminansi(b);
      final gelap = luminansi(a) > luminansi(b) ? luminansi(b) : luminansi(a);
      return (terang + 0.05) / (gelap + 0.05);
    }

    for (final tema in [AppTheme.light(), AppTheme.dark()]) {
      final nama = tema.brightness == Brightness.dark ? 'gelap' : 'terang';
      final latarKartu = tema.cardTheme.color!;

      test('semuanya terbaca di atas kartu tema $nama', () {
        final gagal = <String>[];
        kategori.forEach((label, warna) {
          final r = rasio(warna, latarKartu);
          if (r < 3.0) gagal.add('$label (${r.toStringAsFixed(2)}:1)');
        });
        expect(gagal, isEmpty,
            reason: 'warna berikut tidak sampai 3:1 di atas kartu tema $nama: '
                '${gagal.join(", ")}');
      });
    }

    test('tidak ada dua kategori yang ronanya terlalu mirip', () {
      // Dulu Beranda #3B6FE5 dan Jadwal #4F46E5 cuma beda 20 derajat rona.
      // Keduanya terbaca "biru", jadi warnanya tidak membedakan apa pun —
      // padahal itu dua tab yang bersebelahan.
      final utama = {
        'Beranda': AppColors.dashboard,
        'Jadwal': AppColors.academic,
        'Tugas': AppColors.deadline,
        'Workout': AppColors.workout,
        'Keuangan': AppColors.finance,
      };

      final terlaluMirip = <String>[];
      final daftar = utama.entries.toList();
      for (var i = 0; i < daftar.length; i++) {
        for (var j = i + 1; j < daftar.length; j++) {
          final a = HSLColor.fromColor(daftar[i].value).hue;
          final b = HSLColor.fromColor(daftar[j].value).hue;
          var beda = (a - b).abs();
          if (beda > 180) beda = 360 - beda;
          if (beda < 40) {
            terlaluMirip.add(
                '${daftar[i].key} vs ${daftar[j].key} (${beda.toStringAsFixed(0)} derajat)');
          }
        }
      }
      expect(terlaluMirip, isEmpty,
          reason: 'pasangan warna tab ini terlalu berdekatan ronanya: '
              '${terlaluMirip.join(", ")}');
    });
  });

  group('tema', () {
    testWidgets('kartu punya garis tepi di tema gelap maupun terang', (tester) async {
      for (final kecerahan in Brightness.values) {
        final tema = kecerahan == Brightness.dark ? AppTheme.dark() : AppTheme.light();
        final bentuk = tema.cardTheme.shape;

        expect(bentuk, isA<RoundedRectangleBorder>(), reason: 'tema $kecerahan');
        expect(
          (bentuk! as RoundedRectangleBorder).side.width,
          greaterThan(0),
          reason: 'kartu di tema $kecerahan kehilangan garis tepinya — di tema '
              'gelap bayangan tidak bekerja, jadi garis inilah satu-satunya '
              'yang memisahkan kartu dari latar',
        );
        expect(tema.cardTheme.elevation, 0, reason: 'tema $kecerahan');
      }
    });

    testWidgets('kartu lebih terang daripada latar halaman di kedua tema', (tester) async {
      for (final kecerahan in Brightness.values) {
        final tema = kecerahan == Brightness.dark ? AppTheme.dark() : AppTheme.light();
        expect(
          tema.cardTheme.color,
          isNot(tema.scaffoldBackgroundColor),
          reason: 'kartu dan latar halaman berwarna sama di tema $kecerahan, '
              'jadi kartunya tidak terpisah dari latarnya',
        );
      }
    });
  });

  group('kartu jadwal', () {
    ClassSchedule jadwal({String? room, String? courseCode, String? classCode, String? lecturer}) {
      return ClassSchedule(
        id: 'j1',
        userId: 'u1',
        courseId: 'c1',
        courseName: 'Pemrograman Backend Lanjut (Praktikum)',
        courseCode: courseCode,
        classCode: classCode,
        lecturer: lecturer,
        dayOfWeek: 1,
        startTime: '07:00:00',
        endTime: '11:00:00',
        room: room,
      );
    }

    // Ruangan dan kode berbagi satu baris. Yang paling mudah rusak dari susunan
    // itu adalah keduanya sama-sama panjang: sebelum ini tiap baris meta
    // melebar penuh, jadi menaruh dua di satu baris pasti meluber.
    testWidgets('ruangan dan kode sebaris tetap muat walau dua-duanya panjang', (tester) async {
      final hasil = await gambar(
        tester,
        ProviderScope(
          child: ScheduleTile(
            schedule: jadwal(
              room: 'LABORATORIUM BAHASA GEDUNG C LANTAI 3',
              courseCode: 'SIC20401',
              classCode: 'TI-C7',
              lecturer: 'Anugrah Nur Rahmanto, S.Kom., M.Kom.',
            ),
          ),
        ),
      );
      expect(hasil, isNull);
    });

    testWidgets('muat saat huruf diperbesar 1.3x', (tester) async {
      final hasil = await gambar(
        tester,
        ProviderScope(
          child: ScheduleTile(
            schedule: jadwal(room: 'LAB BAHASA 1', courseCode: 'SIC204', classCode: 'TI-C7'),
          ),
        ),
        skalaTeks: skalaBesar,
      );
      expect(hasil, isNull);
    });

    testWidgets('tanpa kode, ruangan sendirian juga tidak meluber', (tester) async {
      final hasil = await gambar(
        tester,
        ProviderScope(child: ScheduleTile(schedule: jadwal(room: 'C. 203'))),
      );
      expect(hasil, isNull);
    });
  });

  group('baris tugas', () {
    AcademicTask tugas({
      TaskKind kind = TaskKind.kuliah,
      String? courseName = 'Keamanan Cyber',
      TaskStatus status = TaskStatus.todo,
    }) {
      return AcademicTask(
        id: 't1',
        userId: 'u1',
        courseId: courseName == null ? null : 'c1',
        courseName: courseName,
        kind: kind,
        title: judulPanjang,
        deadline: DateTime.now().add(const Duration(days: 3)),
        priority: TaskPriority.high,
        status: status,
        createdAt: DateTime.now(),
      );
    }

    testWidgets('judul panjang, pil matkul, dan lencana status muat bersama', (tester) async {
      final hasil = await gambar(
        tester,
        ProviderScope(child: TaskTile(task: tugas())),
      );
      expect(hasil, isNull);
    });

    testWidgets('muat saat huruf diperbesar 1.3x', (tester) async {
      final hasil = await gambar(
        tester,
        ProviderScope(child: TaskTile(task: tugas(status: TaskStatus.inProgress))),
        skalaTeks: skalaBesar,
      );
      expect(hasil, isNull);
    });

    testWidgets('daftar pribadi tidak menuliskan mata kuliah', (tester) async {
      await gambar(
        tester,
        ProviderScope(
          child: TaskTile(
            task: tugas(kind: TaskKind.pribadi, courseName: null),
            tampilkanMatkul: false,
          ),
        ),
      );
      expect(find.text('Umum'), findsNothing);
    });
  });
}
