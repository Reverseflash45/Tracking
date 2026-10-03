import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:tracking/core/security/app_lock.dart';
import 'package:tracking/core/security/kunci_app.dart';
import 'package:tracking/core/supabase/supabase_client_provider.dart';
import 'package:tracking/core/theme/app_theme.dart';
import 'package:tracking/features/health/data/health_connect.dart';
import 'package:tracking/features/health/domain/kesehatan.dart';
import 'package:tracking/features/health/presentation/kesehatan_page.dart';
import 'package:tracking/features/profile/data/cadangan_lokal.dart';
import 'package:tracking/features/profile/presentation/cadangan_page.dart';

/// Kunci yang langsung terkunci dan tidak pernah memanggil plugin sidik jari.
class _KunciPalsu extends KunciController {
  @override
  KunciState build() => const KunciState(siap: true, aktif: true, terkunci: true);

  @override
  Future<String?> buka() async =>
      'Terlalu banyak percobaan. Tunggu sebentar, lalu coba lagi nanti ya.';
}

/// Halaman baru v1.4 di keadaan terburuk: layar 320 dp, huruf 1.3, terang
/// dan gelap.
void main() {
  setUpAll(() => initializeDateFormatting('id_ID', null));

  Future<Object?> gambar(
    WidgetTester tester,
    Widget halaman,
    Brightness kecerahan, {
    List overrides = const [],
  }) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWithValue(null),
          ...overrides.cast(),
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
    await tester.pump();
    return tester.takeException();
  }

  final langkah = [
    for (var i = 0; i < 7; i++)
      LangkahHarian(tanggal: DateTime(2026, 9, 27 + i), langkah: i == 2 ? 0 : 12345 + i * 4321),
  ];

  for (final kecerahan in Brightness.values) {
    testWidgets('Kesehatan tersambung muat dengan angka besar ($kecerahan)', (tester) async {
      final galat = await gambar(
        tester,
        const KesehatanPage(),
        kecerahan,
        overrides: [
          ringkasanKesehatanProvider.overrideWith(
            (ref) async => RingkasanKesehatan(
              status: StatusHealthConnect.siap,
              langkah: langkah,
              detakIstirahat: 112,
            ),
          ),
        ],
      );
      expect(galat, isNull);
      expect(find.text('Langkah hari ini'), findsOneWidget);
    });

    testWidgets('Kesehatan belum disambungkan muat ($kecerahan)', (tester) async {
      final galat = await gambar(
        tester,
        const KesehatanPage(),
        kecerahan,
        overrides: [
          ringkasanKesehatanProvider.overrideWith(
            (ref) async => const RingkasanKesehatan(status: StatusHealthConnect.perluIzin),
          ),
        ],
      );
      expect(galat, isNull);
      expect(find.text('Sambungkan'), findsOneWidget);
    });

    testWidgets('Cadangan dengan beberapa berkas muat ($kecerahan)', (tester) async {
      final galat = await gambar(
        tester,
        const CadanganPage(),
        kecerahan,
        overrides: [
          cadanganOtomatisAktifProvider.overrideWith((ref) async => true),
          daftarCadanganProvider.overrideWith(
            (ref) async => [
              for (var i = 0; i < 3; i++)
                BerkasCadangan(
                  file: File('tracking-backup-2026-09-2$i-0915.json'),
                  dibuat: DateTime(2026, 9, 20 + i, 9, 15),
                  ukuran: 3456789 * (i + 1),
                ),
            ],
          ),
        ],
      );
      expect(galat, isNull);
      expect(find.text('Cadangan otomatis mingguan'), findsOneWidget);
    });

    testWidgets('Layar kunci menutupi isi app dan pesan galatnya muat ($kecerahan)', (tester) async {
      final galat = await gambar(
        tester,
        const KunciApp(child: Scaffold(body: Text('Isi rahasia'))),
        kecerahan,
        overrides: [kunciProvider.overrideWith(_KunciPalsu.new)],
      );
      expect(galat, isNull);
      expect(find.text('Tracking terkunci'), findsOneWidget);
      expect(find.textContaining('Terlalu banyak percobaan'), findsOneWidget);
      // Isinya tetap hidup di bawah, tapi tidak bisa disentuh.
      final abaikan = tester.widget<IgnorePointer>(
        find.ancestor(of: find.text('Isi rahasia'), matching: find.byType(IgnorePointer)).first,
      );
      expect(abaikan.ignoring, isTrue);
    });
  }
}
