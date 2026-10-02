import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:tracking/core/supabase/supabase_client_provider.dart';
import 'package:tracking/core/theme/app_theme.dart';
import 'package:tracking/features/lainnya/presentation/lainnya_page.dart';
import 'package:tracking/features/nutrition/domain/food_log.dart';
import 'package:tracking/features/nutrition/domain/food_photo.dart';
import 'package:tracking/features/nutrition/presentation/food_photo_page.dart';
import 'package:tracking/features/insight/domain/correlation.dart';
import 'package:tracking/features/insight/presentation/insight_page.dart' show GrafikMingguan;
import 'package:tracking/features/profile/data/profile_repository.dart';
import 'package:tracking/features/wrapped/presentation/wrapped_page.dart';

/// Uji muat untuk tab Lainnya dan halaman Foto makanan, dengan keadaan terburuk
/// yang sama seperti tampilan_test: layar 320 dp dan huruf besar 1.3.
void main() {
  setUpAll(() => initializeDateFormatting('id_ID', null));

  Future<Object?> gambar(WidgetTester tester, Widget halaman, Brightness kecerahan) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWithValue(null),
          profileProvider.overrideWith((ref) async => null),
        ],
        child: MaterialApp(
          theme: kecerahan == Brightness.dark ? AppTheme.dark() : AppTheme.light(),
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
            child: halaman,
          ),
        ),
      ),
    );
    await tester.pump();
    return tester.takeException();
  }

  const tebakan = TebakanMakanan(
    nama: 'Ayam goreng paha atas bumbu kuning khas warung tegal',
    porsi: '1 potong besar, termasuk minyak goreng yang terserap',
    gram: 1250,
    kalori: 1830,
    proteinG: 120,
    karboG: 240,
    lemakG: 115,
    yakin: 35,
  );

  for (final kecerahan in Brightness.values) {
    testWidgets('tab Lainnya muat ($kecerahan)', (tester) async {
      expect(await gambar(tester, const LainnyaPage(), kecerahan), isNull);
      expect(find.text('Keuangan'), findsOneWidget);
    });

    testWidgets('halaman Foto makanan kosong muat ($kecerahan)', (tester) async {
      expect(await gambar(tester, const FoodPhotoPage(), kecerahan), isNull);
    });

    testWidgets('kartu tebakan dan bilah simpan muat dengan teks panjang ($kecerahan)',
        (tester) async {
      final hasil = await gambar(
        tester,
        Scaffold(
          bottomNavigationBar: BilahSimpanTebakan(
            meal: Meal.makanSiang,
            onMeal: (_) {},
            jumlah: 12,
            kalori: 12345,
            menyimpan: false,
            onSimpan: () {},
          ),
          body: ListView(
            children: [
              KartuTebakan(
                item: tebakan,
                dipilih: true,
                onPilih: (_) {},
                onKurang: () {},
                onTambah: () {},
                onKetik: () {},
              ),
            ],
          ),
        ),
        kecerahan,
      );
      expect(hasil, isNull);
      expect(find.text('kasar'), findsOneWidget);
    });
  }

  for (final kecerahan in Brightness.values) {
    testWidgets('kartu Wrapped muat dengan angka dan teks panjang ($kecerahan)', (tester) async {
      final hasil = await gambar(
        tester,
        Scaffold(
          body: Column(
            children: [
              SizedBox(
                height: 600,
                child: StoryCard(
                  color: Colors.purple,
                  data: StoryCardData(
                    icon: Icons.local_fire_department,
                    eyebrow: 'Hari aktif',
                    angka: 1234567,
                    satuan: 'kkal',
                    selisih: const Selisih(-12345, 'bulan lalu'),
                    persen: 0.8,
                    caption: 'Paling produktif hari Rabu\nRata-rata protein 120 g per hari',
                    perHari: const [10, 20, 30, 40, 50, 60, 70],
                  ),
                ),
              ),
            ],
          ),
        ),
        kecerahan,
      );
      await tester.pumpAndSettle();
      expect(hasil, isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('kartu ringkasan Wrapped muat ($kecerahan)', (tester) async {
      final hasil = await gambar(
        tester,
        Scaffold(
          body: SizedBox(
            height: 700,
            child: StoryCard(
              color: Colors.blue,
              data: StoryCardData(
                icon: Icons.grid_view_rounded,
                eyebrow: 'Ringkasan bulan ini',
                teks: 'Pejuang Deadline yang Tidak Pernah Tidur Sebelum Jam Dua',
                caption: '',
                ringkasan: const [
                  (Icons.task_alt, '1.234', 'Tugas selesai'),
                  (Icons.scale_outlined, '1.234.567', 'Volume (kg)'),
                  (Icons.directions_run, '123,4 km', 'Lari'),
                ],
                onBagikan: () {},
              ),
            ),
          ),
        ),
        kecerahan,
      );
      await tester.pumpAndSettle();
      expect(hasil, isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('grafik 12 minggu Pola muat ($kecerahan)', (tester) async {
      final minggu = [
        for (var i = 0; i < 12; i++)
          WeekBucket(DateTime(2026, 7, 13 + 7 * i))
            ..sesiOlahraga = i % 8
            ..tugasSelesai = i
            ..tugasTepatWaktu = i ~/ 2,
      ];
      final hasil = await gambar(
        tester,
        Scaffold(body: ListView(children: [GrafikMingguan(minggu: minggu)])),
        kecerahan,
      );
      await tester.pumpAndSettle();
      expect(hasil, isNull);
      expect(tester.takeException(), isNull);
    });
  }
}
