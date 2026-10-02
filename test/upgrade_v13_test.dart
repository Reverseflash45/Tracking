import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tracking/core/crash/crash_reporter.dart';
import 'package:tracking/core/update/update_checker.dart';
import 'package:tracking/features/academic/data/models/task.dart';
import 'package:tracking/features/insight/domain/correlation.dart';
import 'package:tracking/features/nutrition/domain/food_log.dart';
import 'package:tracking/features/nutrition/domain/food_photo.dart';
import 'package:tracking/features/routine/data/rutinitas_widget_sync.dart';
import 'package:tracking/features/routine/domain/berkala.dart';
import 'package:tracking/features/workout/data/models/workout_session.dart';
import 'package:tracking/features/wrapped/domain/wrapped_stats.dart';
import 'package:tracking/features/wrapped/presentation/wrapped_page.dart' show Selisih;

FoodLog _makan(String nama, double? gram, DateTime tgl) => FoodLog(
      id: '$nama$tgl$gram',
      loggedOn: tgl,
      loggedAt: tgl,
      name: nama,
      meal: Meal.makanSiang,
      calories: 100,
      proteinG: 1,
      carbsG: 1,
      fatG: 1,
      servingGrams: gram,
    );

void main() {
  group('cek update', () {
    test('perbandingan versi', () {
      expect(lebihBaru('v1.3.0', '1.2.0'), isTrue);
      expect(lebihBaru('1.10.0', '1.9.9'), isTrue);
      expect(lebihBaru('v1.2.0', '1.2.0'), isFalse);
      expect(lebihBaru('1.1.9', '1.2.0'), isFalse);
      expect(lebihBaru('bukan-versi', '1.2.0'), isFalse);
    });

    test('membaca rilis GitHub, memilih APK arm64, melewati draft', () {
      final rilis = InfoRilis.fromGithub({
        'tag_name': 'v1.3.0',
        'name': 'Tracking 1.3.0',
        'body': 'Isi',
        'html_url': 'https://github.com/x/y/releases/tag/v1.3.0',
        'draft': false,
        'prerelease': false,
        'assets': [
          {'name': 'tracking-v1.3.0-arm32.apk', 'browser_download_url': 'u32'},
          {'name': 'tracking-v1.3.0-arm64.apk', 'browser_download_url': 'u64'},
        ],
      })!;
      expect(rilis.versi, '1.3.0');
      expect(rilis.apkArm64, 'u64');
      expect(InfoRilis.fromGithub({'tag_name': 'v2.0.0', 'html_url': 'h', 'draft': true}), isNull);
    });

    test('catatan rilis diringkas, berhenti sebelum petunjuk pasang', () {
      const md = 'Judul.\n\n**Fitur**\n- Satu `kode`\n- Dua\n\n**Pasang:** unduh arm64';
      expect(ringkasCatatan(md), 'Judul.\nFitur\n• Satu kode\n• Dua');
    });
  });

  group('pelapor error', () {
    LaporanError e(String pesan, String stack) =>
        LaporanError(occurredAt: DateTime(2026, 10, 2), error: pesan, stack: stack);

    test('error sama dihitung, bukan disimpan berulang', () {
      var isi = <LaporanError>[];
      isi = gabungLaporan(isi, e('A', '#0 main.dart:1\n#1 x'));
      isi = gabungLaporan(isi, e('A', '#0 main.dart:1\n#1 y'));
      isi = gabungLaporan(isi, e('A', '#0 lain.dart:9'));
      expect(isi.length, 2);
      expect(isi.first.jumlah, 2);
    });

    test('tampungan dibatasi, yang paling lama dibuang', () {
      var isi = <LaporanError>[];
      for (var i = 0; i < 5; i++) {
        isi = gabungLaporan(isi, e('E$i', ''), maks: 3);
      }
      expect(isi.map((l) => l.error), ['E2', 'E3', 'E4']);
    });

    test('teks panjang dipotong sesuai batas kolom', () {
      final l = LaporanError.dari(Exception('x' * 5000), StackTrace.fromString('s' * 9000));
      expect(l.error.length, 2000);
      expect(l.stack!.length, 8000);
      expect(LaporanError.fromJson(l.toJson()).kunci, l.kunci);
    });
  });

  group('porsi kebiasaan', () {
    final now = DateTime(2026, 10, 2);

    test('median per nama, minimal dua kali, ejaan tersering', () {
      final hasil = porsiKebiasaan([
        _makan('Nasi putih', 150, now),
        _makan('nasi putih', 200, now),
        _makan('Nasi putih', 250, now),
        _makan('Nasi putih', 900, now.subtract(const Duration(days: 200))), // terlalu lama
        _makan('Tempe', 50, now), // baru sekali
        _makan('Telur', null, now),
        _makan('Telur', null, now),
      ], now: now);
      expect(hasil.length, 1);
      expect(hasil.single.nama, 'Nasi putih');
      expect(hasil.single.gram, 200);
      expect(hasil.single.kali, 3);
      expect(hasil.single.toJson(), {'nama': 'Nasi putih', 'gram': 200, 'kali': 3});
    });
  });

  group('widget', () {
    test('menandai selesai memajukan jatuh tempo dan menyusun ulang', () {
      String p(String id, int n) => PayloadBerkala(
            routineId: id,
            userId: 'u',
            title: id,
            intervalDays: n,
            menitPengingat: 480,
          ).encode();
      final data = jsonEncode({
        'berkala': [
          {'t': 'A', 'd': '2026-10-01', 'p': p('A', 25)},
          {'t': 'B', 'd': '2026-10-05', 'p': p('B', 7)},
        ],
        'harian': {'1': []},
      });
      final baru = jsonDecode(majukanDiWidget(data, 'A', DateTime(2026, 10, 2, 9))) as Map;
      expect(baru['berkala'][0]['t'], 'B');
      expect(baru['berkala'][1]['d'], '2026-10-27');
      expect(baru['harian'], {'1': []});
    });
  });

  group('pembanding Wrapped', () {
    test('momen setara di periode sebelumnya', () {
      expect(momenSebelumnya(WrappedPeriod.mingguan, DateTime(2026, 10, 2)), DateTime(2026, 9, 25));
      expect(momenSebelumnya(WrappedPeriod.bulanan, DateTime(2026, 3, 31)), DateTime(2026, 2, 28));
      expect(momenSebelumnya(WrappedPeriod.bulanan, DateTime(2026, 1, 15)), DateTime(2025, 12, 15));
      expect(momenSebelumnya(WrappedPeriod.tahunan, DateTime(2028, 2, 29)), DateTime(2027, 2, 28));
    });

    test('label selisih', () {
      expect(const Selisih(3, 'bulan lalu').label, '▲ 3 dari bulan lalu');
      expect(const Selisih(-2, 'minggu lalu').label, '▼ 2 dari minggu lalu');
      expect(const Selisih(0, 'bulan lalu').label, 'Sama seperti bulan lalu');
      expect(const Selisih(1.25, 'bulan lalu', satuan: 'km', desimal: 1).label, '▲ 1,3 km dari bulan lalu');
    });

    test('aktivitas per hari dihitung dari hari aktif', () {
      final stats = computeWrappedStats(
        period: WrappedPeriod.bulanan,
        now: DateTime(2026, 10, 9),
        tasks: const [],
        sessions: [
          for (final d in [1, 2, 8]) // Kamis, Jumat, Kamis
            WorkoutSession(
              id: '$d',
              userId: 'u',
              sessionDate: DateTime(2026, 10, d),
              createdAt: DateTime(2026, 10, d),
            ),
        ],
      );
      expect(stats.aktivitasPerHari, [0, 0, 0, 2, 1, 0, 0]);
    });
  });

  group('grafik Pola', () {
    test('12 minggu berurutan tanpa lubang, berakhir di minggu ini', () {
      final minggu = mingguTerakhir(
        tasks: [
          AcademicTask(
            id: 't',
            userId: 'u',
            title: 't',
            deadline: DateTime(2026, 9, 25),
            priority: TaskPriority.medium,
            status: TaskStatus.done,
            createdAt: DateTime(2026, 9, 1),
            completedAt: DateTime(2026, 9, 23),
          ),
        ],
        sessions: const [],
        runs: const [],
        now: DateTime(2026, 10, 2),
      );
      expect(minggu.length, 12);
      expect(minggu.last.start, DateTime(2026, 9, 28));
      expect(minggu.first.start, DateTime(2026, 7, 13));
      expect(minggu[10].tugasSelesai, 1);
    });
  });
}
