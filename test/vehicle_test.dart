import 'package:flutter_test/flutter_test.dart';
import 'package:tracking/features/vehicle/domain/vehicle.dart';

Vehicle _motor({
  int? odometerKm,
  DateTime? odometerOn,
  DateTime? taxDueOn,
  DateTime? plateDueOn,
  VehicleType type = VehicleType.motor,
}) {
  return Vehicle(
    id: 'v1',
    name: 'Beat',
    type: type,
    plate: 'L 1234 AB',
    odometerKm: odometerKm,
    odometerOn: odometerOn,
    taxDueOn: taxDueOn,
    plateDueOn: plateDueOn,
    createdAt: DateTime(2026, 1, 1),
  );
}

ServiceLog _servis({
  String id = 's1',
  ServiceKind kind = ServiceKind.oli,
  required DateTime doneOn,
  int? odometerKm,
  double? cost,
}) {
  return ServiceLog(
    id: id,
    vehicleId: 'v1',
    kind: kind,
    doneOn: doneOn,
    odometerKm: odometerKm,
    cost: cost,
  );
}

void main() {
  final now = DateTime(2026, 8, 3);

  group('patokan servis', () {
    test('interval motor dan mobil berbeda untuk jenis yang sama', () {
      expect(ServiceKind.oli.intervalKm(VehicleType.motor), 2000);
      expect(ServiceKind.oli.intervalKm(VehicleType.mobil), 10000);
    });

    test('aki tidak punya patokan jarak, hanya umur', () {
      expect(ServiceKind.aki.intervalKm(VehicleType.motor), isNull);
      expect(ServiceKind.aki.intervalBulan(VehicleType.motor), 24);
      expect(ServiceKind.aki.punyaPatokan(VehicleType.motor), isTrue);
    });

    test('jenis lainnya tidak punya patokan sama sekali', () {
      expect(ServiceKind.lainnya.punyaPatokan(VehicleType.motor), isFalse);
    });

    test('oli gardan tidak berlaku untuk mobil', () {
      expect(ServiceKind.oliGardan.punyaPatokan(VehicleType.mobil), isFalse);
    });
  });

  group('laju km per hari', () {
    test('butuh dua pembacaan, satu saja tidak cukup', () {
      final laju = lajuKmPerHari(
        _motor(odometerKm: 12000, odometerOn: DateTime(2026, 8, 1)),
        const [],
      );
      expect(laju, isNull);
    });

    test('dua pembacaan yang terlalu berdekatan ditolak', () {
      final laju = lajuKmPerHari(
        _motor(odometerKm: 12100, odometerOn: DateTime(2026, 8, 3)),
        [_servis(doneOn: DateTime(2026, 8, 1), odometerKm: 12000)],
      );
      expect(laju, isNull);
    });

    test('dihitung dari pembacaan terjauh, bukan dua yang terakhir', () {
      final laju = lajuKmPerHari(
        _motor(odometerKm: 13000, odometerOn: DateTime(2026, 8, 1)),
        [
          _servis(id: 'a', doneOn: DateTime(2026, 6, 2), odometerKm: 10000),
          _servis(id: 'b', doneOn: DateTime(2026, 7, 2), odometerKm: 11500),
        ],
      );

      // 3.000 km dalam 60 hari.
      expect(laju, closeTo(50, 0.01));
    });

    test('odometer yang mundur tidak menghasilkan laju negatif', () {
      final laju = lajuKmPerHari(
        _motor(odometerKm: 9000, odometerOn: DateTime(2026, 8, 1)),
        [_servis(doneOn: DateTime(2026, 6, 1), odometerKm: 12000)],
      );
      expect(laju, isNull);
    });
  });

  group('perkiraan odometer', () {
    test('tanpa pembacaan sama sekali, tidak ada perkiraan', () {
      expect(perkiraanOdometer(_motor(), const [], now: now), isNull);
    });

    test('tanpa laju, yang dipakai angka terakhir apa adanya', () {
      final odo = perkiraanOdometer(
        _motor(odometerKm: 12000, odometerOn: DateTime(2026, 7, 1)),
        const [],
        now: now,
      );
      expect(odo, 12000);
    });

    test('dengan laju, angkanya dimajukan sesuai jarak hari', () {
      final odo = perkiraanOdometer(
        _motor(odometerKm: 13000, odometerOn: DateTime(2026, 8, 1)),
        [_servis(doneOn: DateTime(2026, 6, 2), odometerKm: 10000)],
        now: now,
      );

      // 50 km/hari, dua hari sejak pembacaan terakhir.
      expect(odo, 13100);
    });
  });

  group('pengingat servis', () {
    test('belum pernah dicatat berarti belum ada jadwal', () {
      final hasil = pengingatServis(
        vehicle: _motor(),
        logs: const [],
        kind: ServiceKind.oli,
        now: now,
      );
      expect(hasil, isNull);
    });

    test('jenis tanpa patokan tidak pernah menghasilkan pengingat', () {
      final hasil = pengingatServis(
        vehicle: _motor(),
        logs: [_servis(kind: ServiceKind.lainnya, doneOn: DateTime(2026, 1, 1))],
        kind: ServiceKind.lainnya,
        now: now,
      );
      expect(hasil, isNull);
    });

    test('tanpa odometer, dihitung dari waktu saja dan dasarnya dikatakan', () {
      final hasil = pengingatServis(
        vehicle: _motor(),
        logs: [_servis(doneOn: DateTime(2026, 7, 3))],
        kind: ServiceKind.oli,
        now: now,
      )!;

      expect(hasil.sisaKm, isNull);
      expect(hasil.sisaHari, 31);
      expect(hasil.dasar, contains('odometer'));
    });

    test('oli yang lewat dua bulan ditandai lewat', () {
      final hasil = pengingatServis(
        vehicle: _motor(),
        logs: [_servis(doneOn: DateTime(2026, 5, 3))],
        kind: ServiceKind.oli,
        now: now,
      )!;

      expect(hasil.sisaHari, isNegative);
      expect(hasil.status, StatusTempo.lewat);
      expect(hasil.lewat, isTrue);
    });

    test('sisa km dihitung dari odometer servis terakhir', () {
      final hasil = pengingatServis(
        vehicle: _motor(odometerKm: 11500, odometerOn: DateTime(2026, 8, 1)),
        logs: [_servis(doneOn: DateTime(2026, 7, 20), odometerKm: 10000)],
        kind: ServiceKind.oli,
        now: now,
      )!;

      // Servis di 10.000 dengan patokan 2.000 km, jadi jadwalnya di 12.000.
      // Odometer tercatat 11.500 pada 1 Agustus, dan lajunya 125 km/hari
      // (1.500 km dalam 12 hari), jadi dua hari kemudian diperkirakan 11.750.
      expect(hasil.sisaKm, 250);
      expect(hasil.status, StatusTempo.segera);
    });

    test('km habis lebih dulu daripada waktu tetap dianggap lewat', () {
      final hasil = pengingatServis(
        vehicle: _motor(odometerKm: 12500, odometerOn: DateTime(2026, 8, 1)),
        logs: [_servis(doneOn: DateTime(2026, 7, 25), odometerKm: 10000)],
        kind: ServiceKind.oli,
        now: now,
      )!;

      expect(hasil.sisaHari, isPositive);
      expect(hasil.sisaKm, isNegative);
      expect(hasil.status, StatusTempo.lewat);
    });

    test('yang dipakai catatan terbaru, bukan yang pertama', () {
      final hasil = pengingatServis(
        vehicle: _motor(),
        logs: [
          _servis(id: 'lama', doneOn: DateTime(2026, 1, 5)),
          _servis(id: 'baru', doneOn: DateTime(2026, 7, 20)),
        ],
        kind: ServiceKind.oli,
        now: now,
      )!;

      expect(hasil.tanggal, DateTime(2026, 9, 20));
    });
  });

  group('daftar pengingat', () {
    test('pajak dan plat ikut masuk daftar', () {
      final hasil = daftarPengingat(
        vehicle: _motor(
          taxDueOn: DateTime(2026, 9, 1),
          plateDueOn: DateTime(2028, 9, 1),
        ),
        logs: const [],
        now: now,
      );

      expect(hasil.map((p) => p.judul), containsAll(['Pajak tahunan', 'Ganti plat 5 tahunan']));
    });

    test('yang sudah lewat selalu di urutan teratas', () {
      final hasil = daftarPengingat(
        vehicle: _motor(taxDueOn: DateTime(2026, 8, 20)),
        logs: [_servis(doneOn: DateTime(2026, 1, 3))],
        now: now,
      );

      expect(hasil.first.judul, 'Oli mesin');
      expect(hasil.first.lewat, isTrue);
    });

    test('kendaraan tanpa data apa pun tidak menghasilkan pengingat karangan', () {
      expect(daftarPengingat(vehicle: _motor(), logs: const [], now: now), isEmpty);
    });

    test('pajak yang masih setahun lagi berstatus aman', () {
      final hasil = daftarPengingat(
        vehicle: _motor(taxDueOn: DateTime(2027, 6, 1)),
        logs: const [],
        now: now,
      );

      expect(hasil.single.status, StatusTempo.aman);
    });
  });

  group('umur catatan odometer', () {
    test('tanggal terakhir diambil dari catatan servis maupun kolom kendaraan', () {
      final terakhir = odometerTerakhirPada(
        _motor(odometerKm: 13000, odometerOn: DateTime(2026, 7, 1)),
        [_servis(doneOn: DateTime(2026, 6, 1), odometerKm: 12000)],
      );

      expect(terakhir, DateTime(2026, 7, 1));
    });

    test('servis tanpa angka odometer tidak dianggap sebagai catatan', () {
      final terakhir = odometerTerakhirPada(
        _motor(),
        [_servis(doneOn: DateTime(2026, 8, 1))],
      );

      expect(terakhir, isNull);
    });

    test('tidak menagih odometer kalau tidak ada jadwal yang memakainya', () {
      // Aki: patokannya umur, bukan jarak.
      final perlu = perluCatatOdometer(
        _motor(),
        [_servis(kind: ServiceKind.aki, doneOn: DateTime(2026, 1, 1), odometerKm: 9000)],
        now: now,
      );

      expect(perlu, isFalse);
    });

    test('menagih kalau catatan terakhirnya sudah lewat sebulan', () {
      final perlu = perluCatatOdometer(
        _motor(),
        [_servis(doneOn: DateTime(2026, 6, 1), odometerKm: 12000)],
        now: now,
      );

      expect(perlu, isTrue);
    });

    test('tidak menagih kalau catatannya masih baru', () {
      final perlu = perluCatatOdometer(
        _motor(),
        [_servis(doneOn: DateTime(2026, 7, 25), odometerKm: 12000)],
        now: now,
      );

      expect(perlu, isFalse);
    });

    test('belum pernah mencatat sama sekali bukan urusan pengingat ini', () {
      expect(perluCatatOdometer(_motor(), const [], now: now), isFalse);
    });
  });

  group('biaya', () {
    test('servis tanpa biaya tidak dianggap gratis, tapi dilaporkan terpisah', () {
      final hasil = biayaKendaraan(
        [
          _servis(id: 'a', doneOn: DateTime(2026, 3, 1), cost: 55000),
          _servis(id: 'b', doneOn: DateTime(2026, 5, 1)),
        ],
        sejak: DateTime(2026, 1, 1),
      );

      expect(hasil.total, 55000);
      expect(hasil.jumlahServis, 2);
      expect(hasil.tanpaBiaya, 1);
    });

    test('servis sebelum rentang tidak ikut dihitung', () {
      final hasil = biayaKendaraan(
        [_servis(doneOn: DateTime(2025, 12, 31), cost: 999000)],
        sejak: DateTime(2026, 1, 1),
      );

      expect(hasil.total, 0);
      expect(hasil.jumlahServis, 0);
    });
  });

  group('pembacaan dari database', () {
    test('jenis servis yang tidak dikenal jatuh ke lainnya', () {
      final log = ServiceLog.fromMap({
        'id': 'x',
        'vehicle_id': 'v1',
        'kind': 'turbo',
        'done_on': '2026-08-01',
      });

      expect(log.kind, ServiceKind.lainnya);
      expect(log.odometerKm, isNull);
      expect(log.cost, isNull);
    });

    test('judul memakai nopol kalau ada', () {
      expect(_motor().judul, contains('L 1234 AB'));
    });
  });
}
