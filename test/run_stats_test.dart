import 'package:flutter_test/flutter_test.dart';
import 'package:tracking/features/run/domain/geo.dart';
import 'package:tracking/features/run/domain/run_stats.dart';

/// Berapa derajat bujur yang setara satu meter di khatulistiwa, diturunkan dari
/// fungsi jaraknya sendiri.
///
/// Sengaja tidak memakai angka WGS84 (111.319 m/derajat): haversine memodelkan
/// bumi sebagai bola, jadi hasilnya konsisten ~0,1% di bawah nilai elipsoid.
/// Menyusun fixture dari angka elipsoid membuat rute "1000 m" terhitung 998,9 m
/// dan batas kilometernya meleset — yang salah fixture-nya, bukan kodenya.
final double _degPerMeter = 1 / haversineMeters(0, 0, 0, 1);

GeoPoint _at(double meterTimur, int detik) => GeoPoint(
      lat: 0,
      lng: meterTimur * _degPerMeter,
      elapsedMs: detik * 1000,
    );

void main() {
  group('haversineMeters', () {
    test('titik yang sama berjarak nol', () {
      expect(haversineMeters(-6.2, 106.8, -6.2, 106.8), 0);
    });

    test('satu derajat bujur di khatulistiwa sekitar 111 km', () {
      // 111.195 m, bukan 111.319 m dari WGS84: haversine memakai jari-jari
      // rata-rata bola, jadi konsisten ~0,1% lebih kecil. Untuk mengukur lari
      // beberapa kilometer, selisih itu jauh di bawah derau GPS.
      final meters = haversineMeters(0, 0, 0, 1);
      expect(meters, closeTo(111195, 50));
    });

    test('jaraknya simetris', () {
      final a = haversineMeters(-6.2, 106.8, -6.21, 106.81);
      final b = haversineMeters(-6.21, 106.81, -6.2, 106.8);
      expect(a, closeTo(b, 0.0001));
    });

    test('jarak pendek terukur wajar', () {
      // 100 meter ke timur.
      final meters = haversineMeters(0, 0, 0, 100 * _degPerMeter);
      expect(meters, closeTo(100, 0.5));
    });
  });

  group('RunRecorder — penyaringan', () {
    test('titik pertama diterima sebagai jangkar tanpa menambah jarak', () {
      final recorder = RunRecorder();
      final hasil = recorder.add(lat: 0, lng: 0, accuracy: 5, elapsedMs: 0);

      expect(hasil.isAccepted, isTrue);
      expect(hasil.addedMeters, 0);
      expect(recorder.distanceMeters, 0);
    });

    test('fix dengan akurasi buruk dibuang', () {
      final recorder = RunRecorder();
      final hasil = recorder.add(lat: 0, lng: 0, accuracy: 80, elapsedMs: 0);

      expect(hasil.isAccepted, isFalse);
      expect(hasil.reason, RejectReason.akurasiBuruk);
      expect(recorder.points, isEmpty);
    });

    test('berdiri diam tidak menambah jarak sama sekali', () {
      final recorder = RunRecorder();
      recorder.add(lat: 0, lng: 0, accuracy: 5, elapsedMs: 0);

      // Sinyal bergoyang 1-3 meter selama satu menit.
      for (var i = 1; i <= 60; i++) {
        recorder.add(
          lat: 0,
          lng: (i.isEven ? 2 : -3) * _degPerMeter,
          accuracy: 8,
          elapsedMs: i * 1000,
        );
      }

      expect(recorder.distanceMeters, 0);
      expect(recorder.points, hasLength(1));
    });

    test('perpindahan nyata menambah jarak', () {
      final recorder = RunRecorder();
      recorder.add(lat: 0, lng: 0, accuracy: 5, elapsedMs: 0);
      final hasil = recorder.add(
        lat: 0,
        lng: 20 * _degPerMeter,
        accuracy: 5,
        elapsedMs: 5000,
      );

      expect(hasil.isAccepted, isTrue);
      expect(hasil.addedMeters, closeTo(20, 0.5));
      expect(recorder.distanceMeters, closeTo(20, 0.5));
    });

    test('lompatan sinyal ditolak, bukan dijumlahkan', () {
      final recorder = RunRecorder();
      recorder.add(lat: 0, lng: 0, accuracy: 5, elapsedMs: 0);

      // 500 meter dalam 1 detik = 500 m/s. Mustahil.
      final hasil = recorder.add(
        lat: 0,
        lng: 500 * _degPerMeter,
        accuracy: 5,
        elapsedMs: 1000,
      );

      expect(hasil.isAccepted, isFalse);
      expect(hasil.reason, RejectReason.lompatanSinyal);
      expect(recorder.distanceMeters, 0);
    });

    test('jangkar dipasang ulang setelah lompatan beruntun', () {
      final recorder = RunRecorder();
      recorder.add(lat: 0, lng: 0, accuracy: 5, elapsedMs: 0);

      // Sinyal pulih di tempat yang jauh, mis. keluar terowongan.
      final hasil = [
        for (var i = 1; i <= 6; i++)
          recorder.add(
            lat: 0,
            lng: 5000 * _degPerMeter,
            accuracy: 5,
            elapsedMs: i * 1000,
          ),
      ];

      // Beberapa penolakan awal itu memang disengaja — lompatan sejauh itu
      // pantas dicurigai dulu.
      expect(hasil.take(4).every((r) => r.reason == RejectReason.lompatanSinyal), isTrue);

      // Yang penting: jangkarnya akhirnya dipasang ulang. Tanpa itu, seluruh
      // sisa lari akan tertolak selamanya.
      expect(hasil.any((r) => r.isAccepted), isTrue);
      expect(recorder.points, hasLength(2));

      // Titik terakhir jatuh di jangkar baru, jadi wajar dianggap terlalu dekat.
      expect(hasil.last.reason, RejectReason.terlaluDekat);

      // Jarak lompatannya tetap tidak dihitung.
      expect(recorder.distanceMeters, 0);
    });

    test('markGap membuat titik berikutnya jadi jangkar baru', () {
      final recorder = RunRecorder();
      recorder.add(lat: 0, lng: 0, accuracy: 5, elapsedMs: 0);
      recorder.add(lat: 0, lng: 20 * _degPerMeter, accuracy: 5, elapsedMs: 5000);
      expect(recorder.distanceMeters, closeTo(20, 0.5));

      // Jeda: user berjalan 100 m ke tempat lain.
      recorder.markGap();
      final hasil = recorder.add(
        lat: 0,
        lng: 120 * _degPerMeter,
        accuracy: 5,
        elapsedMs: 6000,
      );

      expect(hasil.isAccepted, isTrue);
      // Perpindahan selama jeda tidak masuk hitungan.
      expect(recorder.distanceMeters, closeTo(20, 0.5));
    });

    test('lari lurus 1 km terhitung mendekati 1000 meter', () {
      final recorder = RunRecorder();
      // Satu titik tiap 10 meter, kecepatan 3 m/s.
      for (var i = 0; i <= 100; i++) {
        recorder.add(
          lat: 0,
          lng: i * 10 * _degPerMeter,
          accuracy: 5,
          elapsedMs: (i * 10 / 3 * 1000).round(),
        );
      }

      expect(recorder.distanceMeters, closeTo(1000, 5));
    });
  });

  group('pace', () {
    test('5 km dalam 25 menit sama dengan 5:00 per km', () {
      final pace = paceSecondsPerKm(distanceMeters: 5000, seconds: 1500);
      expect(pace, 300);
      expect(formatPace(pace!), '5:00');
    });

    test('detik ganjil dibulatkan dan diberi nol di depan', () {
      expect(formatPace(305.4), '5:05');
    });

    test('jarak nol tidak membagi dengan nol', () {
      expect(paceSecondsPerKm(distanceMeters: 0, seconds: 100), isNull);
    });

    test('pace tak masuk akal ditampilkan sebagai strip', () {
      expect(formatPace(0), '-');
      expect(formatPace(double.infinity), '-');
      expect(formatPace(double.nan), '-');
    });
  });

  group('format', () {
    test('durasi di bawah satu jam tanpa angka jam', () {
      expect(formatDuration(95), '01:35');
    });

    test('durasi lewat satu jam menyertakan jam', () {
      expect(formatDuration(3725), '1:02:05');
    });

    test('jarak di bawah 1 km dalam meter', () {
      expect(formatDistance(850), '850 m');
    });

    test('jarak di atas 1 km dalam dua desimal', () {
      expect(formatDistance(5432), '5.43 km');
    });
  });

  group('computeSplits', () {
    test('rute di bawah 1 km belum punya split', () {
      final points = [_at(0, 0), _at(500, 150)];
      expect(computeSplits(points), isEmpty);
    });

    test('waktu split diinterpolasi di dalam ruas', () {
      // Titik di 900 m (270 detik) lalu 1100 m (330 detik). Batas 1 km jatuh
      // di tengah ruas: separuhnya, jadi 300 detik.
      final points = [_at(0, 0), _at(900, 270), _at(1100, 330)];
      final splits = computeSplits(points);

      expect(splits, hasLength(1));
      expect(splits.single.km, 1);
      expect(splits.single.seconds, closeTo(300, 1));
    });

    test('split kedua dihitung dari batas sebelumnya, bukan dari start', () {
      final points = [_at(0, 0), _at(1000, 300), _at(2000, 650)];
      final splits = computeSplits(points);

      expect(splits, hasLength(2));
      expect(splits[0].seconds, closeTo(300, 1));
      // Km kedua makan 350 detik, bukan 650.
      expect(splits[1].seconds, closeTo(350, 1));
    });

    test('satu ruas panjang bisa menghasilkan beberapa split', () {
      // Lompat dari 0 langsung ke 3 km dalam 900 detik.
      final points = [_at(0, 0), _at(3000, 900)];
      final splits = computeSplits(points);

      expect(splits, hasLength(3));
      expect([for (final s in splits) s.km], [1, 2, 3]);
    });

    test('rute kosong atau satu titik tidak error', () {
      expect(computeSplits(const []), isEmpty);
      expect(computeSplits([_at(0, 0)]), isEmpty);
    });

    test('label split ditulis mm:ss', () {
      final points = [_at(0, 0), _at(1000, 335)];
      expect(computeSplits(points).single.label, '5:35');
    });
  });

  group('routeBounds', () {
    test('mengurung semua titik', () {
      final points = [
        const GeoPoint(lat: -6.20, lng: 106.80, elapsedMs: 0),
        const GeoPoint(lat: -6.25, lng: 106.85, elapsedMs: 1000),
        const GeoPoint(lat: -6.22, lng: 106.75, elapsedMs: 2000),
      ];

      final bounds = routeBounds(points)!;
      expect(bounds.minLat, -6.25);
      expect(bounds.maxLat, -6.20);
      expect(bounds.minLng, 106.75);
      expect(bounds.maxLng, 106.85);
      expect(bounds.centerLat, closeTo(-6.225, 0.0001));
    });

    test('rute kosong tidak punya batas', () {
      expect(routeBounds(const []), isNull);
    });
  });

  group('GeoPoint json', () {
    test('bolak-balik json tidak mengubah nilai', () {
      const point = GeoPoint(lat: -6.2088, lng: 106.8456, elapsedMs: 12345);
      final kembali = GeoPoint.fromJson(point.toJson());

      expect(kembali.lat, point.lat);
      expect(kembali.lng, point.lng);
      expect(kembali.elapsedMs, point.elapsedMs);
    });
  });
}
