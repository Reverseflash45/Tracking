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
import 'package:tracking/features/profile/data/profile_repository.dart';

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
}
