/// Kendaraan: kapan servis berikutnya, dan kapan pajaknya jatuh tempo.
///
/// Dua hal yang kalau terlewat langsung berbiaya — pajak telat kena denda,
/// oli telat merusak mesin — dan keduanya jatuh tempo dalam hitungan bulan
/// sampai tahun. Jarak yang persis terlalu panjang untuk diingat sendiri, dan
/// terlalu pendek untuk aman.
library;

import 'package:flutter/material.dart';

/// Berapa hari sebelum jatuh tempo sesuatu dianggap "segera".
///
/// Tiga puluh hari: cukup untuk mengurus perpanjangan pajak tanpa terburu-buru,
/// dan cukup dekat untuk tidak diabaikan sebagai urusan nanti.
const int kAmbangSegeraHari = 30;

/// Minimal jarak waktu antara dua pembacaan odometer sebelum lajunya boleh
/// dipakai. Dua pembacaan berselang dua hari akan menghasilkan laju yang
/// menggambarkan dua hari itu saja, bukan kebiasaanmu.
const int kMinHariLaju = 7;

enum VehicleType {
  motor('Motor', Icons.two_wheeler),
  mobil('Mobil', Icons.directions_car);

  const VehicleType(this.label, this.icon);

  final String label;
  final IconData icon;

  static VehicleType fromDb(String? value) => VehicleType.values.firstWhere(
        (type) => type.name == value,
        orElse: () => VehicleType.motor,
      );
}

/// Jenis perawatan beserta jarak dan tenggat bawaannya.
///
/// Angkanya patokan umum, bukan aturan pabrikan kendaraanmu — buku servis
/// selalu menang kalau berbeda. Yang dipakai mana pun yang lebih dulu tiba,
/// km atau bulan, karena begitulah cara oli benar-benar habis umurnya: dipakai
/// jauh, atau didiamkan lama.
enum ServiceKind {
  oli('Oli mesin', Icons.water_drop_outlined, 2000, 2, 10000, 6),
  oliGardan('Oli gardan', Icons.settings_outlined, 8000, 8, null, null),
  servisRutin('Servis rutin', Icons.build_outlined, 3000, 3, 10000, 6),
  busi('Busi', Icons.bolt_outlined, 8000, 8, 20000, 12),
  kampasRem('Kampas rem', Icons.disc_full_outlined, 10000, 12, 30000, 24),
  rantai('Rantai / V-belt', Icons.link_outlined, 10000, 12, null, null),
  ban('Ban', Icons.trip_origin, 15000, 24, 40000, 36),
  aki('Aki', Icons.battery_charging_full_outlined, null, 24, null, 30),
  lainnya('Lainnya', Icons.handyman_outlined, null, null, null, null);

  const ServiceKind(
    this.label,
    this.icon,
    this._kmMotor,
    this._bulanMotor,
    this._kmMobil,
    this._bulanMobil,
  );

  final String label;
  final IconData icon;

  final int? _kmMotor;
  final int? _bulanMotor;
  final int? _kmMobil;
  final int? _bulanMobil;

  /// Null berarti jenis ini memang tidak punya patokan jarak — aki habis
  /// karena umur, bukan karena dipakai jauh.
  int? intervalKm(VehicleType type) =>
      type == VehicleType.motor ? _kmMotor : _kmMobil;

  int? intervalBulan(VehicleType type) =>
      type == VehicleType.motor ? _bulanMotor : _bulanMobil;

  bool punyaPatokan(VehicleType type) =>
      intervalKm(type) != null || intervalBulan(type) != null;

  static ServiceKind fromDb(String? value) => ServiceKind.values.firstWhere(
        (kind) => kind.name == value,
        orElse: () => ServiceKind.lainnya,
      );
}

DateTime _hari(DateTime date) => DateTime(date.year, date.month, date.day);

class Vehicle {
  const Vehicle({
    required this.id,
    required this.name,
    this.type = VehicleType.motor,
    this.plate,
    this.year,
    this.odometerKm,
    this.odometerOn,
    this.taxDueOn,
    this.plateDueOn,
    required this.createdAt,
  });

  final String id;
  final String name;
  final VehicleType type;

  /// Nomor polisi. Berguna saat mengurus pajak, dan saat kamu punya lebih dari
  /// satu kendaraan yang namanya mirip.
  final String? plate;

  final int? year;

  /// Angka odometer terakhir yang kamu catat, beserta kapan dicatatnya.
  /// Keduanya harus ada bersama — angka tanpa tanggal tidak bisa dipakai
  /// menghitung apa pun.
  final int? odometerKm;
  final DateTime? odometerOn;

  /// Jatuh tempo pajak tahunan (STNK).
  final DateTime? taxDueOn;

  /// Jatuh tempo ganti plat lima tahunan. Yang ini paling sering terlewat
  /// karena jaraknya jauh sekali dari kejadian terakhir.
  final DateTime? plateDueOn;

  final DateTime createdAt;

  String get judul => plate == null || plate!.trim().isEmpty
      ? name
      : '$name  ·  ${plate!.trim().toUpperCase()}';

  factory Vehicle.fromMap(Map<String, dynamic> map) => Vehicle(
        id: map['id'] as String,
        name: map['name'] as String,
        type: VehicleType.fromDb(map['type'] as String?),
        plate: map['plate'] as String?,
        year: (map['year'] as num?)?.toInt(),
        odometerKm: (map['odometer_km'] as num?)?.toInt(),
        odometerOn: map['odometer_on'] == null
            ? null
            : DateTime.parse(map['odometer_on'] as String),
        taxDueOn:
            map['tax_due_on'] == null ? null : DateTime.parse(map['tax_due_on'] as String),
        plateDueOn: map['plate_due_on'] == null
            ? null
            : DateTime.parse(map['plate_due_on'] as String),
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}

class ServiceLog {
  const ServiceLog({
    required this.id,
    required this.vehicleId,
    required this.kind,
    required this.doneOn,
    this.odometerKm,
    this.cost,
    this.note,
  });

  final String id;
  final String vehicleId;
  final ServiceKind kind;
  final DateTime doneOn;

  /// Odometer saat servis. Null berarti kamu tidak sempat mencatatnya — dan
  /// kalau begitu, jarak ke servis berikutnya memang tidak bisa dihitung.
  final int? odometerKm;

  final double? cost;
  final String? note;

  factory ServiceLog.fromMap(Map<String, dynamic> map) => ServiceLog(
        id: map['id'] as String,
        vehicleId: map['vehicle_id'] as String,
        kind: ServiceKind.fromDb(map['kind'] as String?),
        doneOn: DateTime.parse(map['done_on'] as String),
        odometerKm: (map['odometer_km'] as num?)?.toInt(),
        cost: (map['cost'] as num?)?.toDouble(),
        note: map['note'] as String?,
      );
}

enum StatusTempo {
  aman('Aman'),
  segera('Segera'),
  lewat('Lewat');

  const StatusTempo(this.label);

  final String label;
}

/// Golongan tenggat. Dipakai penjadwal notifikasi untuk memilih jarak
/// pengingatnya: mengurus pajak butuh persiapan lebih panjang daripada mampir
/// ganti oli, dan ganti plat lebih panjang lagi.
enum JenisTempo { pajak, plat, servis }

/// Satu baris pengingat: servis berikutnya, pajak, atau ganti plat.
class Pengingat {
  const Pengingat({
    required this.judul,
    required this.icon,
    required this.jenis,
    this.tanggal,
    this.sisaHari,
    this.sisaKm,
    required this.status,
    required this.dasar,
  });

  final String judul;
  final IconData icon;
  final JenisTempo jenis;

  /// Perkiraan tanggalnya. Null kalau cuma bisa dihitung lewat jarak.
  final DateTime? tanggal;

  /// Negatif berarti sudah lewat.
  final int? sisaHari;

  /// Sisa kilometer sampai jadwal berikutnya. Negatif berarti sudah lewat.
  final int? sisaKm;

  final StatusTempo status;

  /// Kalimat pendek yang menyebut angka ini datang dari mana. Wajib ada:
  /// pengingat yang tidak bisa menjelaskan dasarnya akan diabaikan begitu
  /// sekali saja terasa meleset.
  final String dasar;

  bool get lewat => status == StatusTempo.lewat;
}

StatusTempo _status({int? sisaHari, int? sisaKm}) {
  if ((sisaHari != null && sisaHari < 0) || (sisaKm != null && sisaKm < 0)) {
    return StatusTempo.lewat;
  }
  if (sisaHari != null && sisaHari <= kAmbangSegeraHari) return StatusTempo.segera;
  // Seribu kilometer terakhir kira-kira sebulan pemakaian motor harian.
  if (sisaKm != null && sisaKm <= 1000) return StatusTempo.segera;
  return StatusTempo.aman;
}

/// Rata-rata kilometer per hari, dari dua pembacaan odometer terjauh.
///
/// Null kalau belum bisa dihitung dengan jujur: butuh dua pembacaan yang
/// berjarak minimal [kMinHariLaju] hari. Tanpa ini tidak ada perkiraan tanggal
/// untuk servis yang patokannya jarak — dan itu lebih baik daripada angka
/// karangan yang terlihat seperti hasil hitungan.
double? lajuKmPerHari(Vehicle vehicle, List<ServiceLog> logs) {
  final bacaan = <({DateTime tanggal, int km})>[
    for (final log in logs)
      if (log.odometerKm case final km?) (tanggal: _hari(log.doneOn), km: km),
    if (vehicle.odometerKm case final km?)
      if (vehicle.odometerOn case final tanggal?) (tanggal: _hari(tanggal), km: km),
  ]..sort((a, b) => a.tanggal.compareTo(b.tanggal));

  if (bacaan.length < 2) return null;

  final awal = bacaan.first;
  final akhir = bacaan.last;
  final hari = akhir.tanggal.difference(awal.tanggal).inDays;
  final km = akhir.km - awal.km;

  if (hari < kMinHariLaju || km <= 0) return null;
  return km / hari;
}

/// Odometer hari ini, diperkirakan dari pembacaan terakhir ditambah laju.
///
/// Null kalau tidak ada pembacaan sama sekali. Kalau lajunya belum bisa
/// dihitung, yang dikembalikan angka terakhir apa adanya — bukan tebakan.
int? perkiraanOdometer(Vehicle vehicle, List<ServiceLog> logs, {required DateTime now}) {
  final bacaan = <({DateTime tanggal, int km})>[
    for (final log in logs)
      if (log.odometerKm case final km?) (tanggal: _hari(log.doneOn), km: km),
    if (vehicle.odometerKm case final km?)
      if (vehicle.odometerOn case final tanggal?) (tanggal: _hari(tanggal), km: km),
  ]..sort((a, b) => a.tanggal.compareTo(b.tanggal));

  if (bacaan.isEmpty) return null;

  final terakhir = bacaan.last;
  final laju = lajuKmPerHari(vehicle, logs);
  if (laju == null) return terakhir.km;

  final selisihHari = _hari(now).difference(terakhir.tanggal).inDays;
  if (selisihHari <= 0) return terakhir.km;
  return terakhir.km + (laju * selisihHari).round();
}

/// Berapa lama sebuah catatan odometer boleh menua sebelum jadwal berbasis km
/// tidak bisa dipercaya lagi.
///
/// Sebulan: dengan pemakaian harian biasa, sebulan itu ribuan kilometer —
/// lebih dari satu siklus ganti oli motor.
const int kUmurOdometerHari = 30;

/// Kapan odometer terakhir kali dicatat, dari catatan servis maupun dari
/// kolom di kendaraannya. Null kalau belum pernah sama sekali.
DateTime? odometerTerakhirPada(Vehicle vehicle, List<ServiceLog> logs) {
  DateTime? terakhir;

  void pertimbangkan(DateTime tanggal) {
    if (terakhir == null || tanggal.isAfter(terakhir!)) terakhir = _hari(tanggal);
  }

  for (final log in logs) {
    if (log.odometerKm != null) pertimbangkan(log.doneOn);
  }
  if (vehicle.odometerKm != null && vehicle.odometerOn != null) {
    pertimbangkan(vehicle.odometerOn!);
  }

  return terakhir;
}

/// Kendaraan ini punya jadwal berbasis km yang akan meleset kalau odometernya
/// tidak diperbarui.
///
/// Dua syarat, dan keduanya perlu: harus ada jadwal yang memang memakai km
/// (percuma menagih odometer kalau semua jadwalmu berbasis waktu), dan
/// catatan terakhirnya harus sudah menua. Tanpa syarat pertama ini cuma jadi
/// teguran soal kebiasaan mencatat — jenis pengingat yang paling cepat
/// dimatikan orang.
bool perluCatatOdometer(
  Vehicle vehicle,
  List<ServiceLog> logs, {
  required DateTime now,
  int ambangHari = kUmurOdometerHari,
}) {
  final adaJadwalKm = logs.any(
    (log) => log.odometerKm != null && log.kind.intervalKm(vehicle.type) != null,
  );
  if (!adaJadwalKm) return false;

  final terakhir = odometerTerakhirPada(vehicle, logs);
  if (terakhir == null) return false;

  return _hari(now).difference(terakhir).inDays >= ambangHari;
}

DateTime _tambahBulan(DateTime dari, int bulan) =>
    DateTime(dari.year, dari.month + bulan, dari.day);

/// Pengingat untuk satu jenis servis. Null kalau tidak ada dasar apa pun —
/// belum pernah dicatat, atau jenisnya memang tanpa patokan.
Pengingat? pengingatServis({
  required Vehicle vehicle,
  required List<ServiceLog> logs,
  required ServiceKind kind,
  required DateTime now,
}) {
  if (!kind.punyaPatokan(vehicle.type)) return null;

  final riwayat = [
    for (final log in logs)
      if (log.kind == kind) log,
  ]..sort((a, b) => b.doneOn.compareTo(a.doneOn));

  if (riwayat.isEmpty) return null;

  final terakhir = riwayat.first;
  final hariIni = _hari(now);

  int? sisaHari;
  DateTime? jatuhTempo;
  final bulan = kind.intervalBulan(vehicle.type);
  if (bulan != null) {
    jatuhTempo = _tambahBulan(_hari(terakhir.doneOn), bulan);
    sisaHari = jatuhTempo.difference(hariIni).inDays;
  }

  int? sisaKm;
  final intervalKm = kind.intervalKm(vehicle.type);
  final odoServis = terakhir.odometerKm;
  final odoSekarang = perkiraanOdometer(vehicle, logs, now: now);
  if (intervalKm != null && odoServis != null && odoSekarang != null) {
    sisaKm = (odoServis + intervalKm) - odoSekarang;
  }

  final dasar = switch ((sisaHari != null, sisaKm != null)) {
    (true, true) => 'Tiap $intervalKm km atau $bulan bulan, mana yang lebih dulu',
    (true, false) => odoServis == null
        ? 'Dihitung dari waktu saja — odometer waktu servis terakhir belum dicatat'
        : 'Tiap $bulan bulan',
    (false, true) => 'Tiap $intervalKm km',
    (false, false) => 'Belum ada dasar hitungan',
  };

  return Pengingat(
    judul: kind.label,
    icon: kind.icon,
    jenis: JenisTempo.servis,
    tanggal: jatuhTempo,
    sisaHari: sisaHari,
    sisaKm: sisaKm,
    status: _status(sisaHari: sisaHari, sisaKm: sisaKm),
    dasar: dasar,
  );
}

/// Seluruh pengingat satu kendaraan, yang paling mendesak di atas.
List<Pengingat> daftarPengingat({
  required Vehicle vehicle,
  required List<ServiceLog> logs,
  required DateTime now,
}) {
  final hariIni = _hari(now);
  final hasil = <Pengingat>[];

  if (vehicle.taxDueOn case final tempo?) {
    final sisa = _hari(tempo).difference(hariIni).inDays;
    hasil.add(
      Pengingat(
        judul: 'Pajak tahunan',
        icon: Icons.receipt_long_outlined,
        jenis: JenisTempo.pajak,
        tanggal: _hari(tempo),
        sisaHari: sisa,
        status: _status(sisaHari: sisa),
        dasar: 'Dari tanggal jatuh tempo di STNK',
      ),
    );
  }

  if (vehicle.plateDueOn case final tempo?) {
    final sisa = _hari(tempo).difference(hariIni).inDays;
    hasil.add(
      Pengingat(
        judul: 'Ganti plat 5 tahunan',
        icon: Icons.badge_outlined,
        jenis: JenisTempo.plat,
        tanggal: _hari(tempo),
        sisaHari: sisa,
        status: _status(sisaHari: sisa),
        dasar: 'Dari tanggal di STNK',
      ),
    );
  }

  for (final kind in ServiceKind.values) {
    final pengingat = pengingatServis(
      vehicle: vehicle,
      logs: logs,
      kind: kind,
      now: now,
    );
    if (pengingat != null) hasil.add(pengingat);
  }

  hasil.sort((a, b) {
    // Yang sudah lewat selalu di atas, apa pun sisanya.
    if (a.lewat != b.lewat) return a.lewat ? -1 : 1;

    final hariA = a.sisaHari;
    final hariB = b.sisaHari;
    if (hariA != null && hariB != null && hariA != hariB) return hariA.compareTo(hariB);
    if ((hariA == null) != (hariB == null)) return hariA == null ? 1 : -1;

    final kmA = a.sisaKm;
    final kmB = b.sisaKm;
    if (kmA != null && kmB != null && kmA != kmB) return kmA.compareTo(kmB);
    if ((kmA == null) != (kmB == null)) return kmA == null ? 1 : -1;

    return a.judul.compareTo(b.judul);
  });

  return hasil;
}

/// Total biaya perawatan dalam rentang [sejak] sampai sekarang.
///
/// Servis yang biayanya tidak dicatat tidak dianggap gratis — jumlahnya
/// dilaporkan terpisah lewat [BiayaKendaraan.tanpaBiaya].
class BiayaKendaraan {
  const BiayaKendaraan({
    required this.total,
    required this.jumlahServis,
    required this.tanpaBiaya,
  });

  final double total;
  final int jumlahServis;
  final int tanpaBiaya;
}

BiayaKendaraan biayaKendaraan(List<ServiceLog> logs, {required DateTime sejak}) {
  var total = 0.0;
  var jumlah = 0;
  var tanpaBiaya = 0;

  for (final log in logs) {
    if (log.doneOn.isBefore(sejak)) continue;
    jumlah++;
    if (log.cost case final biaya?) {
      total += biaya;
    } else {
      tanpaBiaya++;
    }
  }

  return BiayaKendaraan(total: total, jumlahServis: jumlah, tanpaBiaya: tanpaBiaya);
}
