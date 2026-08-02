/// Menebak baris nilai dari teks hasil OCR foto KHS.
///
/// Tiga gagasan yang membuat ini bertahan terhadap OCR yang buruk:
///
/// 1. **Dibaca dari kanan.** Ekor baris KHS selalu `sks | NILAI | BOBOT`, dan
///    urutan itu jauh lebih bisa diandalkan daripada isi kolomnya — nama mata
///    kuliah panjang dan penuh angka, tapi ekornya selalu berbentuk sama.
///
/// 2. **Kolom bobot dipakai untuk menambal.** Di KHS Indonesia, BOBOT adalah
///    `sks × bobot huruf`: A dengan 2 sks tertulis 8, AB dengan 2 sks tertulis
///    7. Jadi kalau hurufnya rusak terbaca, dia bisa dihitung dari bobot ÷ sks;
///    dan kalau justru kolom sks-nya yang hilang, sks bisa dihitung dari
///    bobot ÷ bobot huruf. Itu bukan tebakan, itu aritmetika dari dokumennya.
///
/// 3. **Baris yang punya kode mata kuliah selalu ditampilkan**, walau seluruh
///    ekornya hilang. Membuangnya diam-diam membuat kamu tidak tahu ada yang
///    hilang — dan pada KHS yang OCR-nya buruk, itu bisa separuh isinya.
library;

import 'grade.dart';

/// Baris yang jelas bukan baris nilai.
///
/// Alamat kampus ikut ditolak: "(KAMPUS B UNAIR)" punya huruf B berdiri
/// sendiri yang tanpa ini terbaca sebagai nilai B untuk mata kuliah bernama
/// "JL. DARMAWANGSA DALAM NO. 28-30".
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
const double _toleransi = 0.05;

/// Tingkat untuk sebuah huruf, dicari di kedua skala.
GradeStep? _step(String huruf) {
  final cari = huruf.trim().toUpperCase();
  for (final scale in GradeScale.values) {
    for (final step in stepsFor(scale)) {
      if (step.huruf == cari) return step;
    }
  }
  return null;
}

/// Huruf untuk sebuah bobot per sks, mis. 2.5 → "BC".
///
/// Bobot tidak pernah bertabrakan antar skala (3.5 hanya AB, 3.3 hanya B+),
/// jadi sebuah angka selalu menunjuk satu huruf — apa pun skala yang kebetulan
/// sedang dipilih user.
String? hurufDariBobot(double bobot) {
  for (final scale in GradeScale.values) {
    for (final step in stepsFor(scale)) {
      if ((step.bobot - bobot).abs() <= _toleransi) return step.huruf;
    }
  }
  return null;
}

/// Hitung huruf dari kolom bobot di KHS.
///
/// Dua kebiasaan penulisan ditangani: bobot total (`sks × bobot huruf`, paling
/// umum) dicoba lebih dulu, lalu bobot per sks (angka 0–4 langsung).
///
/// Null kalau tidak ada yang cocok — lebih baik kosong daripada huruf karangan.
String? hurufDariKolomBobot({required int sks, required double bobot}) {
  if (sks > 0) {
    final perSks = hurufDariBobot(bobot / sks);
    if (perSks != null) return perSks;
  }
  return hurufDariBobot(bobot);
}

/// Hitung sks dari bobot dan hurufnya: bobot ÷ bobot huruf.
///
/// Dipakai waktu kolom sks-nya yang hilang. Nilai E tidak bisa dipakai —
/// bobotnya nol, dan nol dibagi apa pun tidak memberi tahu apa-apa.
int? sksDariBobot({required double bobot, required String huruf}) {
  final step = _step(huruf);
  if (step == null || step.bobot <= 0) return null;

  final hasil = bobot / step.bobot;
  final bulat = hasil.round();
  if ((hasil - bulat).abs() > _toleransi) return null;
  if (bulat < 1 || bulat > kMaxSks) return null;
  return bulat;
}

/// Satu baris nilai yang berhasil ditebak.
class KhsEntry {
  const KhsEntry({
    required this.courseName,
    this.huruf,
    this.sks,
    this.bobot,
    this.dariBobot = false,
    this.sksDihitung = false,
  });

  final String courseName;

  /// Huruf mutu. **Null berarti tidak terbaca** — barisnya jelas baris mata
  /// kuliah, tapi kolom nilainya rusak dan tidak bisa dihitung dari bobot.
  /// Ditampilkan supaya kamu perbaiki, bukan dibuang diam-diam: kamu berhak
  /// tahu barisnya ada.
  final String? huruf;

  /// Null kalau kolom sks tidak terbaca dan tidak bisa dihitung.
  final int? sks;

  /// Angka mentah di kolom BOBOT, apa adanya.
  final double? bobot;

  /// Hurufnya dihitung dari bobot ÷ sks, bukan dibaca langsung.
  final bool dariBobot;

  /// Sks-nya dihitung dari bobot ÷ bobot huruf, bukan dibaca langsung.
  final bool sksDihitung;

  bool get terbaca => huruf != null;

  /// Masih perlu kamu isi sesuatu sebelum barisnya berguna.
  bool get perluDiisi => huruf == null || sks == null;

  KhsEntry copyWith({String? courseName, String? huruf, int? sks}) => KhsEntry(
        courseName: courseName ?? this.courseName,
        huruf: huruf ?? this.huruf,
        sks: sks ?? this.sks,
        bobot: bobot,
        // Sudah dikoreksi tangan, jadi bukan lagi hasil hitungan.
        dariBobot: huruf == null && dariBobot,
        sksDihitung: sks == null && sksDihitung,
      );

  /// Huruf yang terbaca tidak cocok dengan kolom bobotnya.
  ///
  /// Biasanya salah satunya salah baca. Ditandai supaya kamu periksa, bukan
  /// diperbaiki diam-diam — app tidak tahu mana yang benar. Angka yang memang
  /// dipakai untuk menghitung tidak pernah ditandai: membandingkannya balik ke
  /// dirinya sendiri selalu cocok, jadi tandanya tidak berarti apa-apa.
  bool get janggal {
    final nilai = huruf;
    final angka = bobot;
    final jumlahSks = sks;
    if (nilai == null || angka == null || jumlahSks == null) return false;
    if (dariBobot || sksDihitung) return false;

    final seharusnya = hurufDariKolomBobot(sks: jumlahSks, bobot: angka);
    return seharusnya != null && seharusnya != nilai;
  }
}

/// Kode mata kuliah, mungkin menempel dengan nomor urut di depan dan awal nama
/// di belakang — OCR sering menghapus spasinya: "1AGI101AGAMA ISLAMI".
final RegExp _kodeGabung = RegExp(r'^(\d{0,2})([A-Za-z]{2,5}\d{3,6})([A-Za-z].*)?$');

final RegExp _angkaUtuh = RegExp(r'^\d{1,3}$');
final RegExp _angkaDesimal = RegExp(r'^\d{1,3}[.,]\d{1,2}$');

/// Token pendek berhuruf: entah huruf mutu yang sah, entah bekas salah baca
/// ("BC" jadi "BO", "AB" jadi "AR").
final RegExp _tokenPendek = RegExp(r'^[A-Za-z][A-Za-z+-]{0,2}$');

enum _Jenis { angka, huruf, rusak, kata }

class _Token {
  const _Token(this.jenis, {this.angka, this.huruf});

  final _Jenis jenis;
  final double? angka;
  final String? huruf;

  bool get sksMasukAkal =>
      angka != null && angka! >= 1 && angka! <= kMaxSks && angka! == angka!.roundToDouble();
}

_Token _klasifikasi(String token) {
  if (_angkaUtuh.hasMatch(token)) return _Token(_Jenis.angka, angka: double.parse(token));
  if (_angkaDesimal.hasMatch(token)) {
    return _Token(_Jenis.angka, angka: double.parse(token.replaceAll(',', '.')));
  }

  final besar = token.toUpperCase();
  for (final scale in GradeScale.values) {
    for (final step in stepsFor(scale)) {
      if (step.huruf == besar) return _Token(_Jenis.huruf, huruf: step.huruf);
    }
  }

  if (_tokenPendek.hasMatch(token)) return const _Token(_Jenis.rusak);
  return const _Token(_Jenis.kata);
}

String _bersihkan(String raw) => raw
    .replaceAll(RegExp(r'[|\t]+'), ' ')
    .replaceAll(RegExp(r'\s{2,}'), ' ')
    .replaceAll(RegExp(r'^[\s.,:;\-–—/]+|[\s.,:;\-–—/]+$'), '')
    .trim();

typedef _Ekor = ({
  int? sks,
  String? huruf,
  double? bobot,
  bool dariBobot,
  bool sksDihitung,
  int dipakai,
});

const _Ekor _ekorKosong =
    (sks: null, huruf: null, bobot: null, dariBobot: false, sksDihitung: false, dipakai: 0);

/// Baca kolom-kolom di ujung kanan.
///
/// Pengumpulan berhenti di kata pertama — nama mata kuliah selalu berupa kata
/// panjang, sedangkan sks, nilai, dan bobot semuanya pendek. Itu batas yang
/// tidak perlu tahu ada berapa kolom yang selamat dari OCR.
_Ekor _bacaEkor(List<String> tokens) {
  final terkumpul = <_Token>[];
  var dipakai = 0;

  for (var i = tokens.length - 1; i >= 0 && terkumpul.length < 3; i--) {
    final token = _klasifikasi(tokens[i]);
    if (token.jenis == _Jenis.kata) break;
    terkumpul.insert(0, token);
    dipakai++;
  }

  if (terkumpul.isEmpty) return _ekorKosong;

  // Bentuk lengkap: sks NILAI BOBOT.
  if (terkumpul.length == 3) {
    final a = terkumpul[0];
    final b = terkumpul[1];
    final c = terkumpul[2];

    if (a.sksMasukAkal && c.jenis == _Jenis.angka) {
      final sks = a.angka!.toInt();
      if (b.jenis == _Jenis.huruf) {
        return (
          sks: sks,
          huruf: b.huruf,
          bobot: c.angka,
          dariBobot: false,
          sksDihitung: false,
          dipakai: 3,
        );
      }
      if (b.jenis == _Jenis.rusak) {
        // Kolom nilainya rusak, tapi posisinya benar — hurufnya dihitung.
        final huruf = hurufDariKolomBobot(sks: sks, bobot: c.angka!);
        return (
          sks: sks,
          huruf: huruf,
          bobot: c.angka,
          dariBobot: huruf != null,
          sksDihitung: false,
          dipakai: 3,
        );
      }
    }
    // Bentuknya tidak dikenali; coba dua token terakhir saja.
    terkumpul.removeAt(0);
    dipakai--;
  }

  if (terkumpul.length == 2) {
    final a = terkumpul[0];
    final b = terkumpul[1];

    // sks NILAI
    if (a.sksMasukAkal && b.jenis == _Jenis.huruf) {
      return (
        sks: a.angka!.toInt(),
        huruf: b.huruf,
        bobot: null,
        dariBobot: false,
        sksDihitung: false,
        dipakai: dipakai,
      );
    }
    // sks NILAI-rusak, tanpa bobot: tidak ada yang bisa dihitung.
    if (a.sksMasukAkal && b.jenis == _Jenis.rusak) {
      return (
        sks: a.angka!.toInt(),
        huruf: null,
        bobot: null,
        dariBobot: false,
        sksDihitung: false,
        dipakai: dipakai,
      );
    }
    // NILAI BOBOT — kolom sks-nya yang hilang, dan itu bisa dihitung balik.
    if (a.jenis == _Jenis.huruf && b.jenis == _Jenis.angka) {
      final sks = sksDariBobot(bobot: b.angka!, huruf: a.huruf!);
      return (
        sks: sks,
        huruf: a.huruf,
        bobot: b.angka,
        dariBobot: false,
        sksDihitung: sks != null,
        dipakai: dipakai,
      );
    }
    // sks BOBOT — kolom nilainya hilang sama sekali.
    if (a.sksMasukAkal && b.jenis == _Jenis.angka) {
      final sks = a.angka!.toInt();
      final huruf = hurufDariKolomBobot(sks: sks, bobot: b.angka!);
      return (
        sks: sks,
        huruf: huruf,
        bobot: b.angka,
        dariBobot: huruf != null,
        sksDihitung: false,
        dipakai: dipakai,
      );
    }

    terkumpul.removeAt(0);
    dipakai--;
  }

  final satu = terkumpul.single;
  if (satu.jenis == _Jenis.huruf) {
    return (
      sks: null,
      huruf: satu.huruf,
      bobot: null,
      dariBobot: false,
      sksDihitung: false,
      dipakai: dipakai,
    );
  }
  if (satu.sksMasukAkal) {
    return (
      sks: satu.angka!.toInt(),
      huruf: null,
      bobot: null,
      dariBobot: false,
      sksDihitung: false,
      dipakai: dipakai,
    );
  }
  if (satu.jenis == _Jenis.angka) {
    // Angka besar di ujung: itu kolom bobot, bukan sks.
    return (
      sks: null,
      huruf: null,
      bobot: satu.angka,
      dariBobot: false,
      sksDihitung: false,
      dipakai: dipakai,
    );
  }

  return _ekorKosong;
}

typedef _Nama = ({String nama, bool punyaKode});

/// Buang nomor urut dan kode mata kuliah, sisanya nama.
///
/// Kodenya dicari di dalam token juga, bukan cuma sebagai token utuh: OCR
/// sering menghapus spasi sehingga nomor urut, kode, dan awal nama menempel
/// jadi satu — "1AGI101AGAMA ISLAMI".
_Nama _bacaNama(List<String> tokens) {
  final hasil = <String>[];
  var punyaKode = false;

  for (final token in tokens) {
    final cocok = _kodeGabung.firstMatch(token);
    if (cocok != null) {
      punyaKode = true;
      final ekor = cocok.group(3);
      // Sisa satu huruf setelah kode hampir selalu sampah OCR ("SIP107I"),
      // bukan awal nama — tidak ada mata kuliah yang namanya dimulai satu
      // huruf berdiri sendiri.
      if (ekor != null && ekor.length > 1) hasil.add(ekor);
      continue;
    }

    // Angka sebelum kode itu nomor urut baris.
    if (!punyaKode && _angkaUtuh.hasMatch(token)) continue;
    hasil.add(token);
  }

  return (nama: _bersihkan(hasil.join(' ')), punyaKode: punyaKode);
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
    if (tokens.isEmpty) continue;

    final ekor = _bacaEkor(tokens);
    final nama = _bacaNama(tokens.sublist(0, tokens.length - ekor.dipakai));

    // Nama sependek dua huruf hampir pasti sisa kolom yang salah potong.
    if (nama.nama.length < 3) continue;

    // Sebuah baris diterima kalau ekornya memberi sesuatu, atau kalau dia punya
    // kode mata kuliah. Yang kedua penting: pada KHS yang OCR-nya buruk, baris
    // bisa kehilangan seluruh kolom angkanya dan tetap jelas baris mata kuliah.
    final adaIsi = ekor.huruf != null || ekor.sks != null || ekor.bobot != null;
    if (!adaIsi && !nama.punyaKode) continue;

    entries.add(KhsEntry(
      courseName: nama.nama,
      huruf: ekor.huruf,
      sks: ekor.sks,
      bobot: ekor.bobot,
      dariBobot: ekor.dariBobot,
      sksDihitung: ekor.sksDihitung,
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
  const khasSetengah = {'AB', 'BC'};
  const khasPlusMinus = {'A-', 'B+', 'B-', 'C+'};

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
