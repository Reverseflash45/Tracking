import 'package:flutter_test/flutter_test.dart';
import 'package:tracking/features/academic/domain/grade.dart';
import 'package:tracking/features/academic/domain/khs_parser.dart';

/// Hasil OCR sebenarnya dari KHS Universitas Airlangga, apa adanya — termasuk
/// salah bacanya: "BC" jadi "BO", "AB" jadi "AR", bobot "12" jadi "1", dan
/// sampah watermark "-uolooel" yang nyelip di depan baris keenam.
///
/// Ini bahan uji paling berharga di berkas ini: teks buatan sendiri tidak
/// pernah serusak teks sungguhan.
const _khsAsli = '''
23.09  1:46:18  B637  (76
KB/S
G  ahasiswa.unair.ac.id  +
UNIVERSITAS AIRLANGGA
FAKULTAS VOKASI
D4 - TEKNIK INFORMATIKA
JL. DARMAWANGSA DALAM NO. 28-30 (KAMPUS B UNAIR )
SURABAYA 60286, 60286
Telp. 031-5033869, 031-5053156, Fax. 031-5053156
http://www.vokasi.unair.ac.id, info
@vokasi.unair.ac.id
KARTU HASIL STUDI TAHUN AJARAN 2024/2025 SEMESTER GENAP
NIM  434241117
Nama Mahasiswa  RAFI FERNANDITO SETIAWAN
Dosen Wali  :ETO WURYANTO, Drs., DEA
NO. KODE MK  NAMA MATA KULIAH  sks  NILAI BOBOT
1  BAE233 BAHASA INGGRIS PROFESI  2  A  8
2  MAL105| MATEMATIKA DISKRIT  2  BO  5
3  SIA111  | LOGIKA& PEMROGRAMAN DASAR  2  BO
4  SIA113  | LOGIKA & PEMROGRAMAN DASAR (PRAKTIKUM)  2  A
5 SID101  BASIS DATA RELASIONAL  2  6
-uolooel  6  SID102  BASIS DATA RELASIONAL (PRAKTIKUM)  3  A  1
7  SII107  ANALISA DAN DESAIN SISTEM INFORMASI (PRAKTIUM)  2  AR
SIl108  ANALISA DAN DESAIN SISTEM INFORMASI  2  A
SIJ207  PENGANTAR SISTEM OPERASI  2  6
10  SIJ208  PENGANTAR SISTEM OPERASI (PRAKTIKUM)  1  A  4
Total sks dan Bobot 20  69
Indeks Prestasi Semester  3.45
sks maksimal yang boleh diambil semester depan  24 sks
Tanpa mata kuliah dengan nilai E, hasil studi sampai semester ini adalah:
JUMLAH sks YANG TELAH DITEMPUH = 40, dengan IPK =3.53
Keterangan: (") MBKM Outbond
Surabaya, 02 Agustus 2026
Wakil Dekan 1,
Lembar
1. untuk mahasiswa
2. untuk dosen wali
3. untuk departemen
Dr. ANDI ESTETIONO, S.E.. M.M.
196807162016123101
''';

/// KHS semester Ganjil, OCR-nya jauh lebih rusak: nomor urut menempel dengan
/// kode dan awal nama ("1AGI101AGAMA"), banyak baris kehilangan kolom sks,
/// beberapa kehilangan kolom nilai, dan tiga baris kehilangan semuanya.
const _khsGanjil = '''
23.10  1:46:33  R 5,82  (76
KB/S
G  ahasiswa.unair.ac.id  +
UNIVERSITAS AIRLANGGA
FAKULTAS VOKASI
D4 - TEKNIK INFORMATIKA
JL. DARMAWANGSA DALAM NO. 28-30 ( KAMPUS B UNAIR )
SURABAYA 60286, 60286
Telp. 031-5033869, 031-5053156, Fax. 031-5053156
http://www.vokasi.unair.ac.id, info
@vokasi.unair.ac.id
KARTU HASIL STUDI TAHUN AJARAN 2024/2025 SEMESTER GANJIL
NIM  :  434241117
Nama Mahasiswa:  RAFI FERNANDITO SETIAVWAN
Dosen Wali  ETO WURYANTO, Drs., DEA
NO. KODE MK  NAMA MATA KULIAH  sks NILAI BOBOT
1AGI101AGAMA ISLAMI  2  A  8
2  BAI101BAHASA INDONESIA  2  AB
MAD111 MATEMATIKA DASAR  AB  7
4  MAL106 ALJABAR LINIER
5 MNM106  KOMUNIKASI DAN PENGEMBANGAN DIRI
6 MNM107  PENGANTAR KOLABORASI KEILMUAN  2
7  NOP103  PANCASILA  8
NOP104  KEWARGANEGARAAN  AB
PHP103| LOGIKA DAN PEMIKIRAN KRITIS  AB  7
10  SIP107I DATA DAN PUSTAKA
Total sks dan Bobot  20  72
Indeks Prestasi Semester  3.
sks maksimal yang boleh diambil semester depan  24 sks
Tanpa mata kuliah dengan nilai E, hasil studi sampai
semester ini adalah:
JUMLAH sks YANG TELAH DITEMPUH = 20, dengan IPK=3.6
Keterangan: (") MBKM Outbond
Surabaya, 02 Agustus 2026
Wakil Dekan 1,
Lembar:
1. untuk mahasiswa
2. untuk dosen wali
3. untuk departemen
Dr. ANDI ESTETIONO. S.E. M.M.
196807162016123101
''';

void main() {
  group('KHS Ganjil — OCR paling rusak', () {
    final hasil = parseKhs(_khsGanjil);

    test('sepuluh baris, tidak lebih dan tidak kurang', () {
      expect(hasil, hasLength(10));
    });

    test('nomor urut dan kode yang menempel dipisahkan dari nama', () {
      // OCR menghapus spasinya: "1AGI101AGAMA ISLAMI".
      expect(hasil[0].courseName, 'AGAMA ISLAMI');
      expect(hasil[1].courseName, 'BAHASA INDONESIA');
    });

    test('sisa satu huruf setelah kode dibuang', () {
      // "SIP107I" — huruf I itu sampah OCR, bukan awal nama.
      expect(hasil[9].courseName, 'DATA DAN PUSTAKA');
    });

    test('baris yang kolom sks-nya hilang dihitung dari bobot', () {
      // "MATEMATIKA DASAR AB 7" → 7 / 3,5 = 2 sks.
      expect(hasil[2].courseName, 'MATEMATIKA DASAR');
      expect(hasil[2].huruf, 'AB');
      expect(hasil[2].sks, 2);
      expect(hasil[2].sksDihitung, isTrue);

      expect(hasil[8].courseName, 'LOGIKA DAN PEMIKIRAN KRITIS');
      expect(hasil[8].sks, 2);
    });

    test('baris yang kehilangan seluruh kolom tetap muncul', () {
      // Kode mata kuliahnya masih terbaca, jadi barisnya jelas ada. Dibuang
      // diam-diam membuat kamu tidak tahu setengah KHS-mu hilang.
      expect(hasil[3].courseName, 'ALJABAR LINIER');
      expect(hasil[3].huruf, isNull);
      expect(hasil[3].sks, isNull);

      expect(hasil[4].courseName, 'KOMUNIKASI DAN PENGEMBANGAN DIRI');
      expect(hasil[4].perluDiisi, isTrue);
    });

    test('sks tanpa nilai tetap terbaca sks-nya', () {
      expect(hasil[5].courseName, 'PENGANTAR KOLABORASI KEILMUAN');
      expect(hasil[5].sks, 2);
      expect(hasil[5].huruf, isNull);
    });

    test('angka besar sendirian dibaca sebagai bobot, bukan sks', () {
      // "PANCASILA 8" — 8 tidak mungkin jumlah sks satu mata kuliah.
      expect(hasil[6].courseName, 'PANCASILA');
      expect(hasil[6].sks, isNull);
      expect(hasil[6].bobot, 8);
    });

    test('nilai tanpa sks tetap terbaca nilainya', () {
      expect(hasil[7].courseName, 'KEWARGANEGARAAN');
      expect(hasil[7].huruf, 'AB');
      expect(hasil[7].sks, isNull);
    });

    test('baris ringkasan, identitas, dan alamat tidak ikut', () {
      final nama = hasil.map((e) => e.courseName).join(' | ').toUpperCase();
      expect(nama, isNot(contains('DARMAWANGSA')));
      expect(nama, isNot(contains('TOTAL')));
      expect(nama, isNot(contains('RAFI')));
      expect(nama, isNot(contains('ESTETIONO')));
      expect(nama, isNot(contains('TEKNIK INFORMATIKA')));
    });

    test('empat baris terisi penuh, sisanya minta diisi', () {
      final penuh = hasil.where((e) => !e.perluDiisi).toList();
      expect(penuh.map((e) => e.courseName), [
        'AGAMA ISLAMI',
        'BAHASA INDONESIA',
        'MATEMATIKA DASAR',
        'LOGIKA DAN PEMIKIRAN KRITIS',
      ]);
    });

    test('skala kampus tertebak dari AB', () {
      expect(tebakSkala(hasil), GradeScale.setengah);
    });

    test('semester tertebak', () {
      expect(findSemester(_khsGanjil), '2024/2025 Ganjil');
    });
  });

  group('KHS Genap — semua sepuluh baris kena', () {
    final hasil = parseKhs(_khsAsli);

    test('sepuluh baris, tidak lebih dan tidak kurang', () {
      expect(hasil, hasLength(10));
    });

    test('alamat kampus tidak jadi mata kuliah', () {
      // "(KAMPUS B UNAIR)" punya huruf B berdiri sendiri; tanpa penolakan
      // alamat, barisnya terbaca sebagai mata kuliah bernilai B.
      expect(hasil.any((e) => e.courseName.contains('DARMAWANGSA')), isFalse);
    });

    test('baris ringkasan dan identitas tidak ikut', () {
      final nama = hasil.map((e) => e.courseName).join(' | ').toUpperCase();
      expect(nama, isNot(contains('INDEKS')));
      expect(nama, isNot(contains('TOTAL')));
      expect(nama, isNot(contains('RAFI')));
      expect(nama, isNot(contains('ESTETIONO')));
    });

    test('nama mata kuliahnya bersih dari kode dan nomor urut', () {
      expect(hasil[0].courseName, 'BAHASA INGGRIS PROFESI');
      expect(hasil[1].courseName, 'MATEMATIKA DISKRIT');
      expect(hasil[3].courseName, 'LOGIKA & PEMROGRAMAN DASAR (PRAKTIKUM)');
      expect(hasil[7].courseName, 'ANALISA DAN DESAIN SISTEM INFORMASI');
      expect(hasil[9].courseName, 'PENGANTAR SISTEM OPERASI (PRAKTIKUM)');
    });

    test('sks diambil dari kolomnya, bukan dari kolom bobot', () {
      // Inilah kesalahan versi pertama: "PENGANTAR SISTEM OPERASI (PRAKTIKUM)
      // 1 A 4" terbaca 4 sks karena 4 adalah angka terakhir.
      expect(hasil[9].sks, 1);
      expect(hasil[0].sks, 2);
      expect(hasil[5].sks, 3);
    });

    test('huruf yang terbaca jelas dipakai apa adanya', () {
      expect(hasil[0].huruf, 'A');
      expect(hasil[3].huruf, 'A');
      expect(hasil[9].huruf, 'A');
    });

    test('huruf yang rusak dihitung balik dari bobot dibagi sks', () {
      // "BO" seharusnya BC: 5 / 2 sks = 2,5 → BC.
      expect(hasil[1].huruf, 'BC');
      expect(hasil[1].dariBobot, isTrue);
    });

    test('kolom nilai yang hilang sama sekali juga terhitung dari bobot', () {
      // Baris 5 dan 9: kolom NILAI-nya tidak terbaca OCR, tinggal "2 6".
      expect(hasil[4].huruf, 'B'); // 6 / 2 = 3,0
      expect(hasil[8].huruf, 'B');
      expect(hasil[4].dariBobot, isTrue);
    });

    test('baris yang benar-benar tidak bisa dipulihkan tetap ditampilkan', () {
      // "BO" dan "AR" tanpa kolom bobot: tidak ada yang bisa dihitung. Barisnya
      // tetap muncul supaya bisa diperbaiki — dibuang diam-diam justru membuat
      // kamu tidak tahu ada yang hilang.
      expect(hasil[2].huruf, isNull);
      expect(hasil[2].courseName, contains('PEMROGRAMAN DASAR'));
      expect(hasil[6].huruf, isNull);
      expect(hasil[6].courseName, contains('ANALISA DAN DESAIN'));
    });

    test('bobot yang tidak cocok dengan hurufnya ditandai', () {
      // Bobot 12 terbaca "1"; A dengan 3 sks seharusnya 12, bukan 1.
      expect(hasil[5].huruf, 'A');
      expect(hasil[5].janggal, isTrue);
    });

    test('yang cocok tidak ditandai janggal', () {
      expect(hasil[0].janggal, isFalse); // 8 / 2 = 4,0 = A
      expect(hasil[9].janggal, isFalse); // 4 / 1 = 4,0 = A
    });

    test('huruf hasil hitungan tidak pernah dianggap janggal', () {
      // Dia memang berasal dari bobot itu; membandingkannya balik ke bobot
      // yang sama selalu cocok, jadi tandanya tidak berarti apa-apa.
      expect(hasil[1].janggal, isFalse);
    });

    test('skala kampus tertebak dari huruf yang muncul', () {
      // BC hanya ada di skala A/AB/B — bukan skala plus-minus.
      expect(tebakSkala(hasil), GradeScale.setengah);
    });

    test('semester tertebak dari kepala KHS', () {
      expect(findSemester(_khsAsli), '2024/2025 Genap');
    });

    test('nilai yang berhasil dibaca menghasilkan IPS yang benar', () {
      // KHS aslinya menulis IPS 3.45 dari 20 sks. Dua baris yang tidak
      // terbaca (BC dan AB, 2 sks masing-masing) dikeluarkan lebih dulu,
      // dan bobot baris keenam dipakai dari hurufnya (A), bukan dari angka
      // 1 yang salah baca.
      final terbaca = hasil.where((e) => e.terbaca && e.sks != null);
      var bobot = 0.0;
      var sks = 0;
      for (final entry in terbaca) {
        bobot += stepForLetter(entry.huruf!, GradeScale.setengah)!.bobot * entry.sks!;
        sks += entry.sks!;
      }

      expect(sks, 16);
      // (4*2 + 2.5*2 + 4*2 + 3*2 + 4*3 + 4*2 + 3*2 + 4*1) / 16 = 3.5625
      expect(bobot / sks, closeTo(3.5625, 0.0001));
    });
  });

  group('bentuk baris yang lebih rapi', () {
    test('kode, nama, sks, huruf, bobot total', () {
      final hasil = parseKhs('TIF3204  Basis Data  3  A  12');
      expect(hasil.single.courseName, 'Basis Data');
      expect(hasil.single.sks, 3);
      expect(hasil.single.huruf, 'A');
      expect(hasil.single.janggal, isFalse);
    });

    test('bobot per sks berbentuk desimal juga dimengerti', () {
      // Sebagian kampus menulis 4.00 (bobot per sks), bukan 12 (total).
      final hasil = parseKhs('TIF3204  Basis Data  3  A  4.00');
      expect(hasil.single.huruf, 'A');
      expect(hasil.single.janggal, isFalse);
    });

    test('bobot berkoma juga terbaca', () {
      final hasil = parseKhs('TIF3204  Basis Data  2  A-  3,70');
      expect(hasil.single.huruf, 'A-');
      expect(hasil.single.janggal, isFalse);
    });

    test('tanpa kolom bobot tetap terbaca', () {
      final hasil = parseKhs('MKU101  Pancasila  2  B+');
      expect(hasil.single.huruf, 'B+');
      expect(hasil.single.sks, 2);
      expect(hasil.single.bobot, isNull);
      expect(hasil.single.janggal, isFalse);
    });

    test('pemisah garis tegak dari tabel ikut dibersihkan', () {
      final hasil = parseKhs('TIF3204 | Struktur Data | 4 | B | 12');
      expect(hasil.single.courseName, 'Struktur Data');
      expect(hasil.single.sks, 4);
      expect(hasil.single.huruf, 'B');
    });
  });

  group('yang harus dilewati', () {
    test('baris berkode tanpa ekor apa pun tetap diterima', () {
      // Sengaja: kode mata kuliahnya sudah cukup membuktikan barisnya baris
      // nilai. Nilainya dikosongkan supaya kamu isi sendiri.
      final hasil = parseKhs('TIF3204  Basis Data');
      expect(hasil.single.courseName, 'Basis Data');
      expect(hasil.single.perluDiisi, isTrue);
    });

    test('baris tanpa kode dan tanpa ekor dilewati', () {
      // Tanpa kode, tidak ada apa pun yang membedakannya dari kalimat biasa.
      expect(parseKhs('Basis Data Relasional'), isEmpty);
    });

    test('sks di luar batas wajar tidak dianggap sks', () {
      expect(parseKhs('Total sks dan Bobot 20 69'), isEmpty);
    });

    test('teks kosong tidak error', () {
      expect(parseKhs(''), isEmpty);
      expect(parseKhs('   \n  \n'), isEmpty);
    });

    test('nama terlalu pendek dilewati', () {
      expect(parseKhs('TIF3204  2  A  8'), isEmpty);
    });
  });

  group('hurufDariKolomBobot', () {
    test('bobot total dibagi sks', () {
      expect(hurufDariKolomBobot(sks: 2, bobot: 5), 'BC');
      expect(hurufDariKolomBobot(sks: 2, bobot: 7), 'AB');
      expect(hurufDariKolomBobot(sks: 3, bobot: 12), 'A');
      expect(hurufDariKolomBobot(sks: 2, bobot: 6), 'B');
    });

    test('bobot per sks dipakai kalau pembagiannya tidak masuk akal', () {
      expect(hurufDariKolomBobot(sks: 2, bobot: 4), 'C'); // 4/2 = 2,0 = C
      expect(hurufDariKolomBobot(sks: 1, bobot: 3.3), 'B+');
    });

    test('angka yang tidak menunjuk huruf mana pun menghasilkan null', () {
      expect(hurufDariKolomBobot(sks: 3, bobot: 100), isNull);
    });

    test('sks nol tidak bikin pembagian nol', () {
      expect(hurufDariKolomBobot(sks: 0, bobot: 4), 'A');
    });
  });

  group('tebakSkala', () {
    test('huruf yang ada di kedua skala tidak memberi petunjuk', () {
      final hasil = parseKhs('TIF101 Satu 2 A 8\nTIF102 Dua 2 B 6');
      expect(tebakSkala(hasil), isNull);
    });

    test('A- menunjuk skala plus-minus', () {
      final hasil = parseKhs('TIF101 Satu 2 A- 7.4');
      expect(tebakSkala(hasil), GradeScale.plusMinus);
    });

    test('daftar kosong tidak menebak apa pun', () {
      expect(tebakSkala(const []), isNull);
    });
  });

  group('findSemester', () {
    test('tahun ajaran dan istilahnya digabung', () {
      expect(findSemester('Semester Ganjil 2026/2027'), '2026/2027 Ganjil');
    });

    test('tahun ajaran saja tetap berguna', () {
      expect(findSemester('Tahun Akademik 2026/2027'), '2026/2027');
    });

    test('tanpa petunjuk apa pun menghasilkan null', () {
      expect(findSemester('TIF3204 Basis Data 3 A'), isNull);
    });
  });

  group('stepForLetter', () {
    test('huruf dari skala satunya tetap ketemu', () {
      expect(stepForLetter('BC', GradeScale.plusMinus)?.bobot, 2.50);
      expect(stepForLetter('A-', GradeScale.setengah)?.bobot, 3.70);
    });

    test('huruf kecil dan berspasi tetap ketemu', () {
      expect(stepForLetter(' a- ', GradeScale.plusMinus)?.bobot, 3.70);
    });

    test('huruf yang tidak dikenal menghasilkan null', () {
      expect(stepForLetter('Z', GradeScale.plusMinus), isNull);
      expect(stepForLetter('', GradeScale.plusMinus), isNull);
    });
  });

  group('CourseGrade dengan nilai resmi', () {
    CourseGrade matkul({String? finalLetter, List<GradeComponent> komponen = const []}) =>
        CourseGrade(
          courseId: 'c1',
          courseName: 'Basis Data',
          sks: 3,
          semester: null,
          finalLetter: finalLetter,
          components: komponen,
        );

    test('huruf dari KHS menang atas hitungan komponen', () {
      final course = matkul(
        finalLetter: 'A',
        komponen: [
          const GradeComponent(id: 'k', courseId: 'c1', name: 'UTS', weight: 100, score: 50),
        ],
      );
      expect(course.huruf(GradeScale.plusMinus)?.huruf, 'A');
      expect(course.resmi, isTrue);
      expect(course.lengkap, isTrue);
    });

    test('nilai resmi ikut menghitung IPK tanpa komponen apa pun', () {
      final hasil = summarizeGrades([matkul(finalLetter: 'A')], GradeScale.plusMinus);
      expect(hasil.ip, 4.0);
      expect(hasil.sksDinilai, 3);
    });

    test('dilepas berarti kembali ke hitungan komponen', () {
      final course = matkul(
        komponen: [
          const GradeComponent(id: 'k', courseId: 'c1', name: 'UTS', weight: 100, score: 50),
        ],
      );
      expect(course.resmi, isFalse);
      // Skor 50 jatuh di D (ambang 45), bukan E.
      expect(course.huruf(GradeScale.plusMinus)?.huruf, 'D');
    });

    test('huruf kosong tidak dianggap nilai resmi', () {
      expect(matkul(finalLetter: '  ').resmi, isFalse);
    });
  });
}
