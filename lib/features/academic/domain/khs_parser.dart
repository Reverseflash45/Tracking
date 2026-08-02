/// Menebak baris nilai dari teks hasil OCR foto KHS.
///
/// Dibaca **dari kanan**, bukan dengan mencari angka di sembarang tempat. Tiga
/// kolom terakhir KHS selalu berurutan `sks | NILAI | BOBOT`, dan urutan itu
/// jauh lebih bisa diandalkan daripada isi kolomnya — nama mata kuliah panjang
/// dan penuh angka, tapi ekornya selalu berbentuk sama.
///
/// Kolom BOBOT di KHS adalah **sks × bobot huruf**, bukan bobot per sks: A
/// dengan 2 sks tertulis 8, A dengan 3 sks tertulis 12. Itu yang membuatnya
/// berguna: kalau huruf mutunya salah terbaca OCR — "BC" jadi "BO", "AB" jadi
/// "AR" — hurufnya bisa dihitung balik dari bobot ÷ sks. Itu bukan tebakan,
/// itu aritmetika dari dokumennya sendiri.
library;

import 'grade.dart';

/// Baris yang jelas bukan baris nilai.
///
/// "IPS" dan "IPK" ikut ditolak: baris itu berisi angka yang bentuknya persis
/// seperti bobot sementara nama mata kuliahnya kosong. Alamat kampus juga —
/// "(KAMPUS B UNAIR)" punya huruf B berdiri sendiri yang tanpa ini terbaca
/// sebagai nilai B untuk mata kuliah bernama "JL. DARMAWANGSA DALAM NO. 28-30".
const List<String> _rejectKeywords = [
  'indeks prestasi',
  'kartu hasil studi',
  'jumlah sks',
  'total sks',
  'sks maksimal',
  'ipk',
  'ips',
  'nim',
  'nama mahasiswa',
  'dosen wali',
  'program studi',
  'fakultas',
  'universitas',
  'mata kuliah', // baris kepala tabel
  'no kode',
  'kode mk',
  'jl.',
  'jalan ',
  'kampus',
  'telp',
  'fax',
  'http',
  'wakil dekan',
  'keterangan',
  'lembar',
  'halaman',
];

/// Batas sks yang masuk akal untuk satu mata kuliah.
const int kMaxSks = 6;

/// Selisih yang masih dianggap sama saat mencocokkan bobot.
const double _toleransiBobot = 0.05;

/// Semua bobot huruf yang dikenal, dari kedua skala.
///
/// Nilainya tidak pernah bertabrakan antar skala (3.5 hanya AB, 3.3 hanya B+),
/// jadi sebuah angka bobot selalu menunjuk satu huruf — apa pun skala yang
/// kebetulan sedang dipilih user.
Map<double, String> get _bobotKeHuruf {
  final hasil = <double, String>{};
  for (final scale in GradeScale.values) {
    for (final step in stepsFor(scale)) {
      hasil.putIfAbsent(step.bobot, () => step.huruf);
    }
  }
  return hasil;
}

/// Huruf untuk sebuah bobot per sks, mis. 2.5 → "BC".
String? hurufDariBobot(double bobot) {
  for (final entry in _bobotKeHuruf.entries) {
    if ((entry.key - bobot).abs() <= _toleransiBobot) return entry.value;
  }
  return null;
}

/// Hitung huruf dari kolom bobot di KHS.
///
/// Dua kebiasaan penulisan ditangani:
/// - **Bobot total** (paling umum di KHS Indonesia): `sks × bobot huruf`, mis.
///   8 untuk A dengan 2 sks. Dicoba lebih dulu.
/// - **Bobot per sks**: angka 0–4 langsung, mis. 4.00 untuk A.
///
/// Null kalau tidak ada yang cocok — lebih baik kosong daripada huruf karangan.
String? hurufDariKolomBobot({required int sks, required double bobot}) {
  if (sks > 0) {
    final perSks = hurufDariBobot(bobot / sks);
    if (perSks != null) return perSks;
  }
  return hurufDariBobot(bobot);
}

/// Satu baris nilai yang berhasil ditebak.
class KhsEntry {
  const KhsEntry({
    required this.courseName,
    this.huruf,
    this.sks,
    this.bobot,
    this.dariBobot = false,
  });

  final String courseName;

  /// Huruf mutu. **Null berarti tidak terbaca** — barisnya jelas baris mata
  /// kuliah, tapi kolom nilainya rusak dan tidak bisa dihitung dari bobot.
  /// Ditampilkan supaya kamu perbaiki, bukan dibuang diam-diam: kamu berhak
  /// tahu barisnya ada.
  final String? huruf;

  /// Null kalau kolom sks tidak terbaca.
  final int? sks;

  /// Angka mentah di kolom BOBOT, apa adanya.
  final double? bobot;

  /// Hurufnya dihitung dari bobot ÷ sks, bukan dibaca langsung.
  final bool dariBobot;

  bool get terbaca => huruf != null;

  KhsEntry copyWith({String? courseName, String? huruf, int? sks}) => KhsEntry(
        courseName: courseName ?? this.courseName,
        huruf: huruf ?? this.huruf,
        sks: sks ?? this.sks,
        bobot: bobot,
        // Sudah dikoreksi tangan, jadi bukan lagi hasil hitungan.
        dariBobot: huruf == null && dariBobot,
      );

  /// Huruf yang terbaca tidak cocok dengan kolom bobotnya.
  ///
  /// Biasanya salah satunya salah baca. Ditandai supaya kamu periksa, bukan
  /// diperbaiki diam-diam — app tidak tahu mana yang benar.
  bool get janggal {
    final nilai = huruf;
    final angka = bobot;
    final jumlahSks = sks;
    if (nilai == null || angka == null || jumlahSks == null || dariBobot) return false;

    final seharusnya = hurufDariKolomBobot(sks: jumlahSks, bobot: angka);
    return seharusnya != null && seharusnya != nilai;
  }
}

/// Kode mata kuliah, mis. "TIF3204" atau "SIl108" (OCR sering menukar I dan l).
final RegExp _kodePattern = RegExp(r'\b[A-Za-z]{2,5}[-\s]?\d{3,6}\b');

final RegExp _angkaUtuh = RegExp(r'^\d{1,3}$');
final RegExp _angkaDesimal = RegExp(r'^\d{1,3}[.,]\d{1,2}$');

/// Token yang bentuknya seperti huruf mutu tapi bukan huruf yang dikenal.
///
/// Inilah bekas OCR yang salah baca: "BC" jadi "BO", "AB" jadi "AR". Diterima
/// sebagai penanda posisi kolom nilai supaya bobotnya masih bisa dipakai.
bool _mungkinHurufRusak(String token) =>
    token.length <= 3 && RegExp(r'^[A-Za-z][A-Za-z+-]{0,2}$').hasMatch(token);

double? _keAngka(String token) {
  if (_angkaUtuh.hasMatch(token)) return double.parse(token);
  if (_angkaDesimal.hasMatch(token)) return double.parse(token.replaceAll(',', '.'));
  return null;
}

String? _keHuruf(String token) {
  final besar = token.toUpperCase();
  for (final huruf in semuaHuruf) {
    if (huruf == besar) return huruf;
  }
  return null;
}

String _bersihkan(String raw) => raw
    .replaceAll(RegExp(r'[|\t]+'), ' ')
    .replaceAll(RegExp(r'\s{2,}'), ' ')
    .replaceAll(RegExp(r'^[\s.,:;\-–—/]+|[\s.,:;\-–—/]+$'), '')
    .trim();

/// Hasil pembacaan tiga kolom terakhir.
typedef _Ekor = ({int? sks, String? huruf, double? bobot, int dipakai});

/// Baca `sks | NILAI | BOBOT` dari ujung kanan daftar token.
///
/// [dipakai] adalah berapa token dari belakang yang habis terpakai, supaya
/// sisanya bisa dijadikan nama mata kuliah.
_Ekor? _bacaEkor(List<String> tokens) {
  if (tokens.length < 2) return null;

  final terakhir = tokens.last;
  final angkaTerakhir = _keAngka(terakhir);
  final hurufTerakhir = _keHuruf(terakhir);

  // Bentuk: ... sks NILAI BOBOT
  if (angkaTerakhir != null && tokens.length >= 3) {
    final tengah = tokens[tokens.length - 2];
    final sks = _keAngka(tokens[tokens.length - 3])?.toInt();

    if (sks != null && sks >= 1 && sks <= kMaxSks) {
      final huruf = _keHuruf(tengah);
      if (huruf != null) {
        return (sks: sks, huruf: huruf, bobot: angkaTerakhir, dipakai: 3);
      }
      // Kolom nilainya rusak, tapi posisinya benar — hurufnya dihitung dari
      // bobot ÷ sks.
      if (_mungkinHurufRusak(tengah)) {
        return (
          sks: sks,
          huruf: hurufDariKolomBobot(sks: sks, bobot: angkaTerakhir),
          bobot: angkaTerakhir,
          dipakai: 3,
        );
      }
    }
  }

  // Bentuk: ... sks BOBOT (kolom nilai hilang sama sekali)
  if (angkaTerakhir != null) {
    final sks = _keAngka(tokens[tokens.length - 2])?.toInt();
    if (sks != null && sks >= 1 && sks <= kMaxSks) {
      final huruf = hurufDariKolomBobot(sks: sks, bobot: angkaTerakhir);
      if (huruf != null) {
        return (sks: sks, huruf: huruf, bobot: angkaTerakhir, dipakai: 2);
      }
    }
  }

  // Bentuk: ... sks NILAI (kolom bobot hilang)
  if (hurufTerakhir != null || _mungkinHurufRusak(terakhir)) {
    final sks = _keAngka(tokens[tokens.length - 2])?.toInt();
    if (sks != null && sks >= 1 && sks <= kMaxSks) {
      return (sks: sks, huruf: hurufTerakhir, bobot: null, dipakai: 2);
    }
  }

  return null;
}

/// Buang nomor urut dan kode mata kuliah, sisanya nama.
///
/// Kodenya dicari di mana pun, bukan cuma di posisi kedua: OCR kadang
/// menyelipkan sampah dari watermark di depan baris, dan itu tidak boleh
/// membuat kode dan nomor urut ikut lolos ke dalam nama.
String _namaDari(List<String> tokens) {
  var indexKode = -1;
  for (var i = 0; i < tokens.length; i++) {
    if (_kodePattern.hasMatch(tokens[i])) {
      indexKode = i;
      break;
    }
  }

  final sisa = <String>[];
  for (var i = 0; i < tokens.length; i++) {
    if (i == indexKode) continue;
    // Angka sebelum kode mata kuliah itu nomor urut baris.
    if (indexKode >= 0 && i < indexKode && _angkaUtuh.hasMatch(tokens[i])) continue;
    // Tanpa kode sama sekali, angka di depan tetap nomor urut.
    if (indexKode < 0 && sisa.isEmpty && _angkaUtuh.hasMatch(tokens[i])) continue;
    sisa.add(tokens[i]);
  }

  return _bersihkan(sisa.join(' '));
}

/// Baca teks OCR jadi daftar nilai.
List<KhsEntry> parseKhs(String rawText) {
  final entries = <KhsEntry>[];

  for (final baris in rawText.split('\n')) {
    final line = baris.trim();
    if (line.isEmpty) continue;

    final lower = line.toLowerCase();
    if (_rejectKeywords.any(lower.contains)) continue;

    final tokens = line
        .replaceAll('|', ' ')
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();

    final ekor = _bacaEkor(tokens);
    if (ekor == null) continue;

    final nama = _namaDari(tokens.sublist(0, tokens.length - ekor.dipakai));
    // Nama sependek dua huruf hampir pasti sisa kolom yang salah potong.
    if (nama.length < 3) continue;

    entries.add(KhsEntry(
      courseName: nama,
      huruf: ekor.huruf,
      sks: ekor.sks,
      bobot: ekor.bobot,
      // Hurufnya dihitung kalau kolom nilainya sendiri tidak menghasilkan huruf
      // yang sah, tapi ekornya tetap terbaca.
      dariBobot: ekor.huruf != null &&
          ekor.bobot != null &&
          _keHuruf(tokens[tokens.length - (ekor.dipakai == 3 ? 2 : 1)]) == null,
    ));
  }

  return entries;
}

/// Skala huruf yang dipakai KHS ini, ditebak dari huruf yang muncul.
///
/// "AB" dan "BC" hanya ada di skala setengah; "A-", "B+", "B-", "C+" hanya di
/// plus-minus. Null kalau semua hurufnya ada di kedua skala (A, B, C, D, E) —
/// KHS seperti itu memang tidak memberi petunjuk apa pun.
GradeScale? tebakSkala(List<KhsEntry> entries) {
  final khasSetengah = {'AB', 'BC'};
  final khasPlusMinus = {'A-', 'B+', 'B-', 'C+'};

  var setengah = 0;
  var plusMinus = 0;
  for (final entry in entries) {
    final huruf = entry.huruf;
    if (huruf == null) continue;
    if (khasSetengah.contains(huruf)) setengah++;
    if (khasPlusMinus.contains(huruf)) plusMinus++;
  }

  if (setengah == 0 && plusMinus == 0) return null;
  return setengah >= plusMinus ? GradeScale.setengah : GradeScale.plusMinus;
}

final RegExp _tahunAjaran = RegExp(r'(20\d{2})\s*/\s*(20\d{2})');
final RegExp _ganjilGenap = RegExp(r'\b(ganjil|genap|gasal|pendek)\b', caseSensitive: false);

/// Tebak nama semester dari kepala KHS, mis. "2024/2025 Genap".
///
/// Null kalau tidak ketemu — nama semester lebih baik kamu ketik sendiri
/// daripada diisi tebakan yang salah, karena dia yang mengelompokkan seluruh
/// daftar nilaimu.
String? findSemester(String rawText) {
  final tahun = _tahunAjaran.firstMatch(rawText);
  final istilah = _ganjilGenap.firstMatch(rawText);

  if (tahun == null && istilah == null) return null;

  final bagian = <String>[
    if (tahun != null) '${tahun.group(1)}/${tahun.group(2)}',
    if (istilah != null) _kapital(istilah.group(1)!),
  ];
  return bagian.join(' ');
}

String _kapital(String kata) => kata[0].toUpperCase() + kata.substring(1).toLowerCase();
