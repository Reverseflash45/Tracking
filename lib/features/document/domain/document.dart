/// Dokumen penting dan masa berlakunya.
///
/// Sekali diisi, mengingatkanmu bertahun-tahun tanpa disentuh lagi. SIM yang
/// telat sehari tidak bisa diperpanjang — harus tes ulang dari nol — dan itu
/// jenis tenggat yang tidak mungkin diingat sendiri karena jaraknya lima tahun
/// dari kejadian terakhir.
library;

import 'package:flutter/material.dart';

/// Berapa hari sebelum kedaluwarsa sebuah dokumen dianggap "segera".
///
/// Dua bulan, lebih panjang daripada pengingat kendaraan: mengurus dokumen
/// berarti antre, melengkapi berkas, dan kadang datang dua kali.
const int kAmbangDokumenHari = 60;

/// Berapa bulan masa berlaku paspor yang biasanya diminta negara tujuan.
///
/// Bukan aturan Indonesia, melainkan syarat masuk di banyak negara — paspor
/// yang masih berlaku empat bulan tetap sah di sini tapi bisa membuatmu
/// ditolak di konter check-in.
const int kBulanPasporAman = 6;

enum DocKind {
  ktp('KTP', Icons.badge_outlined, null),
  sim('SIM', Icons.drive_eta_outlined, 5),
  stnk('STNK', Icons.description_outlined, 5),
  paspor('Paspor', Icons.public, 10),
  bpjs('BPJS', Icons.local_hospital_outlined, null),
  npwp('NPWP', Icons.account_balance_outlined, null),
  kartuMahasiswa('Kartu Mahasiswa', Icons.school_outlined, null),
  asuransi('Asuransi', Icons.shield_outlined, 1),
  lainnya('Lainnya', Icons.folder_outlined, null);

  const DocKind(this.label, this.icon, this.masaBerlakuTahun);

  final String label;
  final IconData icon;

  /// Masa berlaku umum dalam tahun, dipakai mengisi otomatis tanggal
  /// kedaluwarsa saat kamu mengisi tanggal terbit. Null berarti tidak ada
  /// patokan — KTP sudah berlaku seumur hidup, dan NPWP tidak kedaluwarsa.
  final int? masaBerlakuTahun;

  static DocKind fromDb(String? value) => DocKind.values.firstWhere(
        (kind) => kind.name == value,
        orElse: () => DocKind.lainnya,
      );
}

enum StatusDokumen {
  aman('Aman'),
  segera('Segera'),
  lewat('Kedaluwarsa'),
  tanpaTempo('Tanpa masa berlaku'),
  belumDiisi('Masa berlaku belum diisi');

  const StatusDokumen(this.label);

  final String label;
}

DateTime _hari(DateTime date) => DateTime(date.year, date.month, date.day);

class Document {
  const Document({
    required this.id,
    required this.name,
    this.kind = DocKind.lainnya,
    this.number,
    this.issuedOn,
    this.expiresOn,
    this.noExpiry = false,
    this.note,
    required this.createdAt,
  });

  final String id;
  final String name;
  final DocKind kind;

  /// Nomor dokumen. Disimpan supaya kamu tidak perlu membongkar dompet tiap
  /// kali mengisi formulir — dan karena itu selalu ditampilkan tersamar dulu.
  final String? number;

  final DateTime? issuedOn;
  final DateTime? expiresOn;

  /// Dokumen ini memang tidak punya masa berlaku. Penanda terpisah, bukan
  /// sekadar tanggal kosong: "seumur hidup" dan "belum kamu isi" dua keadaan
  /// berbeda, dan yang kedua perlu ditagih sementara yang pertama tidak.
  final bool noExpiry;

  final String? note;
  final DateTime createdAt;

  /// Negatif berarti sudah lewat. Null kalau tidak ada tanggal kedaluwarsa.
  int? sisaHari(DateTime now) {
    final tempo = expiresOn;
    if (noExpiry || tempo == null) return null;
    return _hari(tempo).difference(_hari(now)).inDays;
  }

  StatusDokumen status(DateTime now) {
    if (noExpiry) return StatusDokumen.tanpaTempo;

    final sisa = sisaHari(now);
    if (sisa == null) return StatusDokumen.belumDiisi;
    if (sisa < 0) return StatusDokumen.lewat;
    if (sisa <= kAmbangDokumenHari) return StatusDokumen.segera;
    return StatusDokumen.aman;
  }

  /// Paspor yang masa berlakunya tinggal di bawah [kBulanPasporAman] bulan.
  /// Masih sah, tapi sudah cukup untuk ditolak di konter check-in.
  bool pasporMepet(DateTime now) {
    if (kind != DocKind.paspor) return false;
    final sisa = sisaHari(now);
    if (sisa == null || sisa < 0) return false;
    return sisa < kBulanPasporAman * 30;
  }

  factory Document.fromMap(Map<String, dynamic> map) => Document(
        id: map['id'] as String,
        name: map['name'] as String,
        kind: DocKind.fromDb(map['kind'] as String?),
        number: map['number'] as String?,
        issuedOn:
            map['issued_on'] == null ? null : DateTime.parse(map['issued_on'] as String),
        expiresOn:
            map['expires_on'] == null ? null : DateTime.parse(map['expires_on'] as String),
        noExpiry: map['no_expiry'] as bool? ?? false,
        note: map['note'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}

/// Nomor dokumen dengan sebagian besar digitnya ditutup.
///
/// Empat digit terakhir dibiarkan terbaca: itu cukup untuk mengenali dokumen
/// mana yang sedang kamu lihat, tapi tidak cukup untuk dipakai orang lain
/// kalau layarmu terlihat dari samping.
String nomorTersamar(String nomor) {
  final bersih = nomor.trim();
  if (bersih.length <= 4) return '•' * bersih.length;

  final ekor = bersih.substring(bersih.length - 4);
  return '${'•' * (bersih.length - 4)}$ekor';
}

/// Perkiraan tanggal kedaluwarsa dari tanggal terbit, kalau jenisnya punya
/// masa berlaku baku. Null kalau tidak ada patokan — dan kalau begitu memang
/// harus kamu isi sendiri, bukan ditebak.
DateTime? perkiraanKedaluwarsa(DocKind kind, DateTime terbit) {
  final tahun = kind.masaBerlakuTahun;
  if (tahun == null) return null;
  return DateTime(terbit.year + tahun, terbit.month, terbit.day);
}

/// Urutan tampil: yang kedaluwarsa dulu, lalu yang paling dekat jatuh tempo.
///
/// Yang tanpa masa berlaku ditaruh paling bawah — dia tidak butuh perhatianmu,
/// dan menaruhnya di antara yang mendesak cuma menambah baris yang harus
/// dilewati mata.
List<Document> sortDocuments(List<Document> items, {required DateTime now}) {
  const urutan = {
    StatusDokumen.lewat: 0,
    StatusDokumen.segera: 1,
    StatusDokumen.aman: 2,
    StatusDokumen.belumDiisi: 3,
    StatusDokumen.tanpaTempo: 4,
  };

  final hasil = [...items];

  hasil.sort((a, b) {
    final statusA = urutan[a.status(now)]!;
    final statusB = urutan[b.status(now)]!;
    if (statusA != statusB) return statusA.compareTo(statusB);

    final sisaA = a.sisaHari(now);
    final sisaB = b.sisaHari(now);
    if (sisaA != null && sisaB != null && sisaA != sisaB) return sisaA.compareTo(sisaB);

    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });

  return hasil;
}

class RingkasanDokumen {
  const RingkasanDokumen({
    required this.total,
    required this.lewat,
    required this.segera,
    required this.belumDiisi,
  });

  final int total;
  final int lewat;
  final int segera;

  /// Dokumen yang masa berlakunya belum kamu isi. Ditampilkan supaya "0 yang
  /// segera" tidak terbaca sebagai aman padahal separuhnya belum terhitung.
  final int belumDiisi;
}

RingkasanDokumen ringkasDokumen(List<Document> items, {required DateTime now}) {
  var lewat = 0;
  var segera = 0;
  var belumDiisi = 0;

  for (final item in items) {
    switch (item.status(now)) {
      case StatusDokumen.lewat:
        lewat++;
      case StatusDokumen.segera:
        segera++;
      case StatusDokumen.belumDiisi:
        belumDiisi++;
      case StatusDokumen.aman:
      case StatusDokumen.tanpaTempo:
        break;
    }
  }

  return RingkasanDokumen(
    total: items.length,
    lewat: lewat,
    segera: segera,
    belumDiisi: belumDiisi,
  );
}
