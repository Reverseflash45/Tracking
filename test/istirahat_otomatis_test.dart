import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tracking/core/supabase/supabase_client_provider.dart';
import 'package:tracking/core/theme/app_theme.dart';
import 'package:tracking/features/workout/data/rest_day_repository.dart';
import 'package:tracking/features/workout/domain/istirahat_otomatis.dart';
import 'package:tracking/features/workout/domain/workout_streak.dart';
import 'package:tracking/features/workout/presentation/tujuh_hari_card.dart';
import 'package:tracking/features/workout/presentation/workout_providers.dart';

DateTime d(int hari) => DateTime(2026, 10, hari);

void main() {
  // 6 Oktober 2026, jam 9 pagi.
  final now = DateTime(2026, 10, 6, 9);

  group('Istirahat otomatis', () {
    test('hari kemarin tanpa latihan ditandai, hari ini tidak', () {
      final hasil = hariIstirahatOtomatis(
        aktif: [d(1), d(3), DateTime(2026, 10, 4, 18, 30)],
        istirahat: const [],
        now: now,
        sejak: d(1),
      );
      expect(hasil, [d(2), d(5)]);
    });

    test('hari yang sudah kamu tandai sendiri tidak ditandai ulang', () {
      final hasil = hariIstirahatOtomatis(
        aktif: [d(1)],
        istirahat: [d(3)],
        now: now,
        sejak: d(2),
      );
      expect(hasil, [d(2), d(4), d(5)]);
    });

    test('tidak mengisi sebelum latihan pertamamu', () {
      final hasil = hariIstirahatOtomatis(aktif: [d(4)], istirahat: const [], now: now);
      expect(hasil, [d(5)]);
    });

    test('belum pernah latihan: tidak ada yang diisi', () {
      expect(hariIstirahatOtomatis(aktif: const [], istirahat: const [], now: now), isEmpty);
    });

    test('paling jauh 14 hari ke belakang', () {
      final hasil = hariIstirahatOtomatis(
        aktif: [DateTime(2026, 8, 1)],
        istirahat: const [],
        now: now,
        sejak: DateTime(2026, 8, 2),
      );
      expect(hasil.length, kMaksHariOtomatis);
      expect(hasil.last, d(5));
    });

    test('streak tetap putus setelah dua hari istirahat otomatis', () {
      final aktif = [d(1)];
      final otomatis = hariIstirahatOtomatis(aktif: aktif, istirahat: const [], now: d(3), sejak: d(2));
      expect(otomatis, [d(2)]);
      expect(calculateStreakFromDates(aktif, restDates: otomatis, now: d(3)).current, 2);

      final tigaHari = hariIstirahatOtomatis(aktif: aktif, istirahat: const [], now: d(5), sejak: d(2));
      expect(calculateStreakFromDates(aktif, restDates: tigaHari, now: d(5)).current, 0);
    });
  });

  group('Status 7 hari', () {
    test('latihan menang atas tanda istirahat, otomatis dibedakan dari manual', () {
      final status = statusHarian(
        aktif: [d(1), d(4)],
        istirahat: {
          d(2): kCatatanIstirahatOtomatis,
          d(3): null,
          // Lupa dicatat lalu dicatat belakangan: latihan menang.
          d(4): kCatatanIstirahatOtomatis,
        },
        now: now,
      );
      expect(status.first.$1, DateTime(2026, 9, 30));
      expect(status.last.$1, d(6));
      expect(status.map((e) => e.$2).toList(), [
        StatusHari.kosong, // 30 Sep
        StatusHari.latihan, // 1
        StatusHari.istirahatOtomatis, // 2
        StatusHari.istirahat, // 3
        StatusHari.latihan, // 4
        StatusHari.kosong, // 5
        StatusHari.kosong, // 6 (hari ini)
      ]);
    });
  });

  group('Tampilan', () {
    setUpAll(() => initializeDateFormatting('id_ID', null));

    for (final kecerahan in Brightness.values) {
      testWidgets('kartu 7 hari muat di layar 320 dp, huruf 1.3 ($kecerahan)', (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final hariIni = DateTime.now();
        DateTime lalu(int n) => DateTime(hariIni.year, hariIni.month, hariIni.day - n);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentUserProvider.overrideWithValue(null),
              activeDatesProvider.overrideWithValue([lalu(1), lalu(4)]),
              restDaysProvider.overrideWith(
                (ref) async => [
                  RestDay(id: 'a', restOn: lalu(2), note: kCatatanIstirahatOtomatis),
                  RestDay(id: 'b', restOn: lalu(3)),
                ],
              ),
            ],
            child: MaterialApp(
              theme: kecerahan == Brightness.dark ? AppTheme.dark() : AppTheme.light(),
              home: const MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(1.3)),
                child: Scaffold(body: Padding(padding: EdgeInsets.all(16), child: TujuhHariCard())),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.text('7 hari terakhir'), findsOneWidget);
        expect(find.byIcon(Icons.check), findsNWidgets(2));
      });
    }
  });
}
