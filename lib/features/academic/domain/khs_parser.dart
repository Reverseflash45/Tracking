/// Menebak baris nilai dari teks hasil OCR foto KHS.
///
/// Sama seperti pembaca KRS dan pembaca struk: ini penebak, bukan pembaca.
/// Yang dikerjakan di sini cuma menemukan potongan yang bentuknya jelas — huruf
/// mutu, sks, dan bobot — lalu menyerahkan sisanya untuk kamu koreksi.
///
/// Satu baris hanya diterima kalau **huruf mutunya ketemu**. Tanpa itu yang
/// tersisa cuma daftar mata kuliah, dan itu sudah dikerjakan pembaca KRS.
library;

import 'grade.dart';

/// Baris yang jelas bukan baris nilai.
///
/// "IPS" dan "IPK" ikut ditolak: baris itu berisi angka 3.45 yang bentuknya
/// persis seperti bobot, dan nama mata kuliahnya kosong — hasilnya jadi entri
/// hantu bernama "Indeks Prestasi".
const List<String> _rejectKeywords = [
  'indeks prestasi',
  'kartu hasil studi',
  'jumlah sks',
  'total sks',
  'ipk',
  'ips',
  'nim',
  'nama mahasiswa',
  'program studi',
  'fakultas',
  'dosen wali',
  'tanda tangan',
  'mata kuliah', // baris kepala tabel
  'no kode',
  'halaman',
];

/// Batas sks yang masuk akal untuk satu mata kuliah.
const int kMaxSks = 6;

/// Satu baris nilai yang berhasil ditebak.
class KhsEntry {
  const KhsEntry({
    required this.courseName,
    required this.huruf,
    this.sks,
    this.bobot,
  });

  final String courseName;

  /// Huruf mutu, mis. "A-" atau "AB".
  final String huruf;

  /// Null kalau kolom sks tidak terbaca.
  final int? sks;

  /// Bobot yang tertulis di KHS (mis. 4.00), kalau ada. Dipakai sebagai
  /// pemeriksa silang terhadap [huruf], bukan sebagai sumber nilai.
  final double? bobot;

  KhsEntry copyWith({String? courseName, String? huruf, int? sks, double? bobot}) =>
      KhsEntry(
        courseName: courseName ?? this.courseName,
        huruf: huruf ?? this.huruf,
        sks: sks ?? this.sks,
        bobot: bobot ?? this.bobot,
      );

  /// Bobot yang tertulis di KHS tidak cocok dengan hurufnya.
  ///
  /// Biasanya berarti salah satunya salah baca. Ditandai supaya kamu periksa,
  /// bukan diperbaiki diam-diam — app tidak tahu mana yang benar.
  bool janggal(GradeScale scale) {
    final tertulis = bobot;
    if (tertulis == null) return false;
    final step = stepForLetter(huruf, scale);
    if (step == null) return false;
    return (step.bobot - tertulis).abs() > 0.05;
  }
}

/// Huruf mutu, disusun dari yang terpanjang supaya "A" tidak menang atas "A-".
final RegExp _hurufPattern = RegExp(
  '(?:^|[\\s|])(${(semuaHuruf..sort((a, b) => b.length.compareTo(a.length))).map(RegExp.escape).join('|')})(?=[\\s|]|\$)',
);

/// Bobot IP: 0,00 sampai 4,00.
final RegExp _bobotPattern = RegExp(r'(?:^|[\s|])([0-4][.,]\d{1,2})(?=[\s|]|$)');

/// Kode mata kuliah, mis. "TIF3204" atau "MKU-101".
final RegExp _kodePattern = RegExp(r'\b[A-Z]{2,5}[-\s]?\d{3,6}\b');

/// Angka berdiri sendiri, calon kolom sks atau nomor urut.
final RegExp _angkaPattern = RegExp(r'(?:^|[\s|])(\d{1,2})(?=[\s|]|$)');

String _bersihkan(String raw) => raw
    .replaceAll(RegExp(r'[|\t]+'), ' ')
    .replaceAll(RegExp(r'\s{2,}'), ' ')
    .replaceAll(RegExp(r'^[\s.,:;\-–—/]+|[\s.,:;\-–—/]+$'), '')
    .trim();

/// Baca teks OCR jadi daftar nilai.
List<KhsEntry> parseKhs(String rawText) {
  final entries = <KhsEntry>[];

  for (final baris in rawText.split('\n')) {
    final line = baris.trim();
    if (line.isEmpty) continue;

    final lower = line.toLowerCase();
    if (_rejectKeywords.any(lower.contains)) continue;

    // Huruf mutu diambil dari kecocokan TERAKHIR: di KHS kolom nilai ada di
    // ujung kanan, sementara di kiri sering ada huruf tunggal lain seperti
    // kode kelas "A" atau sisa "B" dari nama mata kuliah yang terpotong.
    final hurufMatches = _hurufPattern.allMatches(line).toList();
    if (hurufMatches.isEmpty) continue;
    final hurufMatch = hurufMatches.last;
    final huruf = hurufMatch.group(1)!;

    var sisa = line;

    // Bobot dibuang lebih dulu supaya "4.00" tidak dikira kolom sks bernilai 4.
    final bobotMatch = _bobotPattern.firstMatch(sisa);
    final bobot = bobotMatch == null
        ? null
        : double.tryParse(bobotMatch.group(1)!.replaceAll(',', '.'));
    if (bobotMatch != null) {
      sisa = sisa.replaceRange(bobotMatch.start, bobotMatch.end, ' ');
    }

    // Huruf mutunya sendiri juga dibuang, dicari ulang di sisa yang sudah
    // kehilangan bobot supaya posisinya tetap benar.
    final hurufDiSisa = _hurufPattern.allMatches(sisa).toList();
    if (hurufDiSisa.isNotEmpty) {
      final akhir = hurufDiSisa.last;
      sisa = sisa.replaceRange(akhir.start, akhir.end, ' ');
    }

    sisa = sisa.replaceAll(_kodePattern, ' ');

    // Kolom sks: angka berdiri sendiri yang paling dekat dengan kolom nilai,
    // yaitu yang paling kanan. Nomor urut ada di paling kiri, jadi kalau ada
    // dua angka, yang terakhir yang benar.
    int? sks;
    final angkaMatches = _angkaPattern.allMatches(sisa).toList();
    for (final match in angkaMatches.reversed) {
      final angka = int.parse(match.group(1)!);
      if (angka >= 1 && angka <= kMaxSks) {
        sks = angka;
        sisa = sisa.replaceRange(match.start, match.end, ' ');
        break;
      }
    }
    // Sisa angka apa pun (nomor urut, tahun) bukan bagian dari nama.
    sisa = sisa.replaceAll(_angkaPattern, ' ');

    final nama = _bersihkan(sisa);
    // Nama sependek dua huruf hampir pasti sisa kolom yang salah potong.
    if (nama.length < 3) continue;

    entries.add(KhsEntry(courseName: nama, huruf: huruf, sks: sks, bobot: bobot));
  }

  return entries;
}

final RegExp _tahunAjaran = RegExp(r'(20\d{2})\s*/\s*(20\d{2})');
final RegExp _ganjilGenap = RegExp(r'\b(ganjil|genap|gasal|pendek)\b', caseSensitive: false);

/// Tebak nama semester dari kepala KHS, mis. "2026/2027 Ganjil".
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

String _kapital(String kata) =>
    kata[0].toUpperCase() + kata.substring(1).toLowerCase();
