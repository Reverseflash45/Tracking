import 'package:flutter_test/flutter_test.dart';
import 'package:tracking/features/academic/domain/krs_parser.dart';

void main() {
  group('parseKrs — satu baris tabel terpecah beberapa baris OCR', () {
    // Teks ini disalin apa adanya dari hasil OCR sebuah KRS, termasuk salah
    // bacanya: "Kliah" untuk "Kuliah", "SI329" untuk "SII329", "T-C1" untuk
    // "TI-C1", dan "Islam ||" untuk "Islam II".
    //
    // Sebelum baris digabung, teks ini menghasilkan nol jadwal — bukan karena
    // OCR-nya gagal, tapi karena tidak ada satu baris pun yang memuat hari dan
    // rentang jam sekaligus.
    const ocrAsli = '''
KODE  SKS
NO.  NAMA MATA KULIAH  KELAS  JADWAL
MTA  MTA
1  AGI401  Agama Islam ||  2  T-C1  Rabu Kuliah jam
07 2 sks | 13:00
s/d 15:00
2  SIC307  Pembelajaran Mesin  2  TI-C2  Rabu Kliah
jam 01 2 sks | 07:00
s/d 09:00
3  SIC308  Pembelajaran Mesin (Praktikum)  1  TI-C7
Kamis Kuliah jam 9 2 sks 15:00
s/d 17:00
4  SI329  Design Thinking  2  T-C2  Kamis Kuliah jam
01 2 sks | 07:00
s/d 09:00
5  SIJ304  Keamanan Cyber  2  TI-C2  |Selasa Kuliah
jam 09 2 sks |
15:00 s/d 17:00
6  SIJ305  Keamanan Cyber (Praktikum)  1  TI-C4
Selasa Kuliah jam 07 2 sks|
13:00 s/d 15:00''';

    test('keenam baris jadwalnya terbaca', () {
      expect(parseKrs(ocrAsli).length, 6);
    });

    test('hari dan jam diambil dari potongan yang berbeda', () {
      final hasil = parseKrs(ocrAsli);

      // Hari ada di potongan pertama, jam mulai di kedua, jam selesai di ketiga.
      expect(hasil[0].dayOfWeek, 3, reason: 'Rabu');
      expect(hasil[0].startTime, '13:00');
      expect(hasil[0].endTime, '15:00');

      expect(hasil[2].dayOfWeek, 4, reason: 'Kamis');
      expect(hasil[2].startTime, '15:00');
      expect(hasil[2].endTime, '17:00');

      expect(hasil[4].dayOfWeek, 2, reason: 'Selasa');
      expect(hasil[4].startTime, '15:00');
      expect(hasil[4].endTime, '17:00');
    });

    test('jam milik baris berikutnya tidak tertarik ke baris sebelumnya', () {
      final hasil = parseKrs(ocrAsli);

      // Baris 2 berjam 07:00-09:00 dan baris 3 berjam 15:00-17:00. Kalau
      // jendela penggabungan menyeberang, keduanya akan tertukar atau sama.
      expect(hasil[1].startTime, '07:00');
      expect(hasil[1].endTime, '09:00');
      expect(hasil[2].startTime, '15:00');
    });

    test('nama mata kuliah bersih dari kode kelas dan kata "Kuliah"', () {
      final nama = parseKrs(ocrAsli).map((e) => e.courseName).toList();

      expect(nama[1], 'Pembelajaran Mesin');
      expect(nama[2], 'Pembelajaran Mesin (Praktikum)');
      expect(nama[3], 'Design Thinking');
      expect(nama[4], 'Keamanan Cyber');
    });

    test('"Rabu" tidak dikira nama ruangan', () {
      // "r" dulu ikut jadi label ruangan yang berdiri sendiri, jadi setiap kata
      // berawalan R dianggap penanda ruangan.
      for (final entry in parseKrs(ocrAsli)) {
        expect(entry.room, isNull, reason: 'KRS ini memang tidak punya kolom ruangan');
      }
    });
  });

  group('parseKrs — kolom status menyelip di tengah rentang jam', () {
    // KRS yang sama, difoto dengan kolom STATUS dan AKSI ikut terlihat. Kolom
    // itu jatuh persis di antara jam mulai dan jam selesai:
    //
    //     2 sks | 13:00 Belum disetujui  Hapus
    //     s/d 15:00  dosen
    //
    // Disalin apa adanya, termasuk salah bacanya: "Islam Il", "sld" untuk
    // "s/d", dan dua nomor urut yang hilang (baris 2, 4, dan 8).
    const ocrAsli = '''
KODE  SKS
NO.  NAMA MATA KULIAH  KELAS  JADWAL  STATUS  AKSI
MTA  MTA
1  AGI401  Agama Islam Il  TI-C1  Rabu Kuliah jam 07
2 sks | 13:00 Belum disetujui  Hapus
s/d 15:00  dosen
SIC307  Pembelajaran Mesin  TI-C2  Rabu Kuliah jam 01
2 sks | 07:00 Belum disetujui  Hapus
s/d 09:00  dosen
3  SIC308  Pembelajaran Mesin (Praktikum)  TI-C7
Kamis Kuliah jam 09 2 sks| 15:00 Belum disetujui
Hapus
sld 17:00  dosen
SII329  Design Thinking  TI-C2  Kamis Kuliah jam 01 2
sks | 07:00 Belum disetujui  Hapus
s/d 09:00  dosen
5  SIJ304  Keamanan Cyber  2  TI-C2  Selasa Kuliah
jam 09 2 sks |  Belum disetujui  Hapus
15:00 s/d 17:00  dosen
6  SIJ305  Keamanan Cyber (Praktikum)  TI-C4  Selasa
Kuliah jam 07 2 sks |  Belum disetujui  Hapus
13:00 s/d 15:00  dosen
7  SIP374  Pemrograman Backend Lanjut  TI-C2  Kamis
Kuliah jam 05 2 sks | 11:00 Belum disetujui  Hapus
s/d 13:00  dosen
SIP375  Pemrograman Backend Lanjut (Praktikum)  2  TI-
C7  Senin Kuliah jam 08 4 sks | 14:00 Belum disetujui
Hapus
s/d 18:00  dosen
9  SIR302  Proyek 1 (Analisa dan Desain PL)  2  TI-C2
Rabu Kuliah jam 03 2 sks | 09:00 Belum disetujui
Hapus
s/d 11:00  dosen
10  SIR303  Jaminan Kualitas Perangkat Lunak  2  TI-
C2  Kamis Kuliah jam 03 2 sks | 09:00 Belum disetujui
Hapus
(Quality Assurance)  s/d 11:00  dosen
11  SIR307  Kewirausahaan Bidang IT  2  TI-C2  Rabu
Kuliah jam 11 2 sks | 17:00 Belum disetujui  Hapus
s/d 19:00  dosen
|Pesan Dosen :''';

    test('kesebelas baris jadwalnya terbaca', () {
      expect(parseKrs(ocrAsli).length, 11);
    });

    test('jam tetap benar walau kolom status menyelip di tengahnya', () {
      final hasil = parseKrs(ocrAsli);

      expect((hasil[0].startTime, hasil[0].endTime), ('13:00', '15:00'));
      expect((hasil[1].startTime, hasil[1].endTime), ('07:00', '09:00'));
      expect((hasil[6].startTime, hasil[6].endTime), ('11:00', '13:00'));
      expect((hasil[7].startTime, hasil[7].endTime), ('14:00', '18:00'));
      expect((hasil[10].startTime, hasil[10].endTime), ('17:00', '19:00'));
    });

    test('"sld" diterima sebagai salah baca dari "s/d"', () {
      expect((parseKrs(ocrAsli)[2].startTime, parseKrs(ocrAsli)[2].endTime), ('15:00', '17:00'));
    });

    test('harinya benar semua', () {
      expect(
        parseKrs(ocrAsli).map((e) => e.dayOfWeek).toList(),
        [3, 3, 4, 4, 2, 2, 4, 1, 3, 4, 3],
        reason: 'Rabu, Rabu, Kamis, Kamis, Selasa, Selasa, Kamis, Senin, Rabu, Kamis, Rabu',
      );
    });

    test('nama tidak kemasukan kolom STATUS dan AKSI', () {
      expect(parseKrs(ocrAsli).map((e) => e.courseName).toList(), [
        'Agama Islam Il',
        'Pembelajaran Mesin',
        'Pembelajaran Mesin (Praktikum)',
        'Design Thinking',
        'Keamanan Cyber',
        'Keamanan Cyber (Praktikum)',
        'Pemrograman Backend Lanjut',
        'Pemrograman Backend Lanjut (Praktikum)',
        'Proyek 1 (Analisa dan Desain PL)',
        'Jaminan Kualitas Perangkat Lunak',
        'Kewirausahaan Bidang IT',
      ]);
    });
  });

  group('parseKrs — KRS tanpa kolom nomor urut', () {
    // Format ketiga: tidak ada kolom NO. sama sekali, barisnya langsung dimulai
    // kode mata kuliah. Kolom Ruang juga panjang dan turun baris, jadi ada
    // potongan menggantung seperti "Rekayasa Perangkat" / "Lunak" di antara dua
    // jadwal.
    //
    // Disalin apa adanya, termasuk "sIC311" yang huruf pertamanya terbaca
    // kecil, "SI332" yang kehilangan satu huruf, dan garis tabel yang terbaca
    // sebagai "|".
    const ocrAsli = '''
Kode MK  Nama Mata Kuliah  sks  Kelas  Hari  Jam
Ruang
|SIC204  Kecerdasan Buatan  2  TI-B2  Selasa
13.00-15:00  C. R. Kuliah 203
|sIC311  Kecerdasan Buatan (Praktikum)  1  TI-B2
Rabu  13:00-15:00  C. Lab. Intelegence
SI332  Workshop Desain Ul  2  TI-B2  Jumat
07:00-09:00  |C. Lab. Komputer
Rekayasa Perangkat
Lunak
SIP245  Aplikasi Mobile  2  TI-B2  Senin  15:00-17:00
C. R. Kuliah 202
SIP246  Aplikasi Mobile (Praktikum)  2  TI-B2  Kamis
07:00-09:00  C. Lab. Komputer
Rekayasa Perangkat
Lunak
SIR207  Manajemen Proyek Perangkat Lunak  2  TI-B2
Selasa  |09:00-11:00  C.R. Kuliah 202
|SIR208  Manajemen Proyek Perangkat Lunak (Praktikum)
2  TI-B2  |Kamis  15:00-17:00  C. Lab. Komputer
Bahasa 2
SIR209  Pengujian Perangkat Lunak  2  TI-B2  Senin
13:00-15:00
| SIR210  Pengujian Perangkat Lunak (Praktikum)  2
TI-B2  Selasa  11:00-13:00  C. Lab. Intelegence
SIR311 Workshop Pengembangan Perangkat Lunak WEB
(Framework)  2  TI-B6  Kamis  13:00-15:00  |C. Lab.
Komputer
Praktikum  Rekayasa Perangkat
Lunak
Total SKS  19''';

    test('kesepuluh baris jadwalnya terbaca', () {
      expect(parseKrs(ocrAsli).length, 10);
    });

    test('baris header tidak ikut jadi jadwal', () {
      final nama = parseKrs(ocrAsli).map((e) => e.courseName);
      expect(nama.any((n) => n.contains('Nama Mata Kuliah')), isFalse);
    });

    test('mata kuliah pertama tidak tertelan baris header', () {
      // Tanpa penjagaan awal baris, jendela penggabungan berangkat dari header,
      // melahap dua baris berikutnya, lalu berhenti begitu menemukan hari dan
      // jam milik SIC204 — jadwal pertamanya hilang dan tergantikan header.
      final pertama = parseKrs(ocrAsli).first;
      expect(pertama.courseName, 'Kecerdasan Buatan');
      expect(pertama.dayOfWeek, 2);
      expect((pertama.startTime, pertama.endTime), ('13:00', '15:00'));
    });

    test('sisa kolom Ruang yang turun baris tidak bocor ke nama berikutnya', () {
      final nama = parseKrs(ocrAsli).map((e) => e.courseName).toList();

      // "Rekayasa Perangkat Lunak" dan "Bahasa 2" adalah ekor nama ruangan di
      // baris sebelumnya, bukan awalan nama mata kuliah.
      expect(nama[3], 'Aplikasi Mobile');
      expect(nama[5], 'Manajemen Proyek Perangkat Lunak');
      expect(nama[7], 'Pengujian Perangkat Lunak');
    });

    test('kode yang huruf besarnya salah baca tetap dibuang dari nama', () {
      expect(parseKrs(ocrAsli)[1].courseName, 'Kecerdasan Buatan (Praktikum)');
    });

    test('seluruh nama dan harinya benar', () {
      final hasil = parseKrs(ocrAsli);

      expect(hasil.map((e) => e.courseName).toList(), [
        'Kecerdasan Buatan',
        'Kecerdasan Buatan (Praktikum)',
        'Workshop Desain Ul',
        'Aplikasi Mobile',
        'Aplikasi Mobile (Praktikum)',
        'Manajemen Proyek Perangkat Lunak',
        'Manajemen Proyek Perangkat Lunak (Praktikum)',
        'Pengujian Perangkat Lunak',
        'Pengujian Perangkat Lunak (Praktikum)',
        'Workshop Pengembangan Perangkat Lunak WEB (Framework)',
      ]);

      expect(hasil.map((e) => e.dayOfWeek).toList(), [2, 3, 5, 1, 4, 2, 4, 1, 2, 4]);
    });

    test('"Total SKS 19" tidak dianggap jadwal', () {
      expect(parseKrs(ocrAsli).any((e) => e.courseName.contains('Total')), isFalse);
    });
  });

  group('parseKrs — baris yang jelas', () {
    test('baris lengkap terbaca utuh', () {
      final hasil = parseKrs('Senin  07:30 - 09:10  Basis Data  R.301');

      expect(hasil, hasLength(1));
      final entry = hasil.single;
      expect(entry.dayOfWeek, 1);
      expect(entry.startTime, '07:30');
      expect(entry.endTime, '09:10');
      expect(entry.courseName, 'Basis Data');
      expect(entry.room, '301');
    });

    test('beberapa baris jadwal sekaligus', () {
      const teks = '''
KARTU RENCANA STUDI
Semester Ganjil 2026/2027

Senin   07:30 - 09:10   Basis Data          R.301
Selasa  13:00 - 14:40   Jaringan Komputer   R.205
Kamis   09:20 - 11:00   Kecerdasan Buatan   Lab AI
''';

      final hasil = parseKrs(teks);
      expect(hasil, hasLength(3));
      expect([for (final e in hasil) e.dayOfWeek], [1, 2, 4]);
      expect(hasil[1].courseName, 'Jaringan Komputer');
    });

    test('jam tanpa titik dua tetap terbaca', () {
      final hasil = parseKrs('Rabu 0730-0910 Kalkulus');
      expect(hasil.single.startTime, '07:30');
      expect(hasil.single.endTime, '09:10');
    });

    test('jam dengan titik sebagai pemisah', () {
      final hasil = parseKrs('Rabu 07.30 - 09.10 Kalkulus');
      expect(hasil.single.startTime, '07:30');
    });

    test('jam satu digit diberi nol di depan', () {
      final hasil = parseKrs('Jumat 7:30 - 9:10 Agama');
      expect(hasil.single.startTime, '07:30');
      expect(hasil.single.endTime, '09:10');
    });

    test('pemisah s/d dikenali', () {
      final hasil = parseKrs('Senin 08:00 s/d 10:00 Statistika');
      expect(hasil.single.endTime, '10:00');
    });
  });

  group('parseKrs — nama hari', () {
    test('semua hari dikenali', () {
      const hari = {
        'Senin': 1,
        'Selasa': 2,
        'Rabu': 3,
        'Kamis': 4,
        'Jumat': 5,
        'Sabtu': 6,
        'Minggu': 7,
      };

      hari.forEach((nama, angka) {
        final hasil = parseKrs('$nama 08:00 - 10:00 Mata Kuliah Uji');
        expect(hasil.single.dayOfWeek, angka, reason: nama);
      });
    });

    test("jum'at dengan apostrof dikenali", () {
      expect(parseKrs("Jum'at 08:00 - 10:00 Agama Islam").single.dayOfWeek, 5);
    });

    test('huruf besar-kecil tidak berpengaruh', () {
      expect(parseKrs('SENIN 08:00 - 10:00 Fisika Dasar').single.dayOfWeek, 1);
    });

    test('singkatan hari dikenali', () {
      expect(parseKrs('Sel 08:00 - 10:00 Pemrograman Web').single.dayOfWeek, 2);
    });

    test('nama hari di dalam kata lain tidak tertangkap', () {
      // "sen" ada di dalam "Presentasi", tapi barisnya bukan hari Senin.
      final hasil = parseKrs('Presentasi Sensor 08:00 - 10:00');
      expect(hasil, isEmpty);
    });
  });

  group('parseKrs — pembersihan nama', () {
    test('kode mata kuliah dibuang dari nama', () {
      final hasil = parseKrs('Senin TIF3204 07:30 - 09:10 Basis Data R.301');
      expect(hasil.single.courseName, 'Basis Data');
    });

    test('jumlah SKS dibuang', () {
      final hasil = parseKrs('Senin 07:30 - 09:10 Basis Data 3 SKS R.301');
      expect(hasil.single.courseName, 'Basis Data');
    });

    test('pemisah tabel dibuang', () {
      final hasil = parseKrs('Senin | 07:30 - 09:10 | Basis Data | R.301');
      expect(hasil.single.courseName, 'Basis Data');
    });

    test('tanda baca di ujung dibersihkan', () {
      final hasil = parseKrs('Senin, 07:30 - 09:10, Basis Data, R.301');
      expect(hasil.single.courseName, 'Basis Data');
    });
  });

  group('parseKrs — ruangan', () {
    test('format R.301', () {
      expect(parseKrs('Senin 07:30 - 09:10 Basis Data R.301').single.room, '301');
    });

    test('kata Ruang dikenali', () {
      expect(
        parseKrs('Senin 07:30 - 09:10 Basis Data Ruang A1').single.room,
        'A1',
      );
    });

    test('laboratorium dikenali', () {
      expect(
        parseKrs('Senin 07:30 - 09:10 Basis Data Lab Komputer').single.room,
        'Komputer',
      );
    });

    test('tanpa ruangan menghasilkan null', () {
      expect(parseKrs('Senin 07:30 - 09:10 Basis Data').single.room, isNull);
    });
  });

  group('parseKrs — menolak yang meragukan', () {
    test('baris tanpa jam dilewati', () {
      expect(parseKrs('Senin Basis Data R.301'), isEmpty);
    });

    test('baris tanpa hari dilewati', () {
      expect(parseKrs('07:30 - 09:10 Basis Data R.301'), isEmpty);
    });

    test('jam selesai sebelum jam mulai ditolak', () {
      expect(parseKrs('Senin 09:10 - 07:30 Basis Data'), isEmpty);
    });

    test('jam mulai sama dengan selesai ditolak', () {
      expect(parseKrs('Senin 09:00 - 09:00 Basis Data'), isEmpty);
    });

    test('nama terlalu pendek ditolak', () {
      // Setelah hari, jam, dan ruangan dibuang, tidak tersisa nama apa pun.
      expect(parseKrs('Senin 07:30 - 09:10 R.301'), isEmpty);
    });

    test('teks kosong dan acak tidak error', () {
      expect(parseKrs(''), isEmpty);
      expect(parseKrs('asdf\n???\n123'), isEmpty);
    });

    test('judul dan header KRS tidak ikut jadi jadwal', () {
      const teks = '''
KARTU RENCANA STUDI
Nama : Rafi Fernandito
NIM  : 20250101
Semester Ganjil 2026/2027
Hari  Jam  Mata Kuliah  Ruang
''';
      expect(parseKrs(teks), isEmpty);
    });
  });

  group('KrsEntry.copyWith', () {
    test('mengubah sebagian tanpa menyentuh sisanya', () {
      const asal = KrsEntry(
        courseName: 'Basis Data',
        dayOfWeek: 1,
        startTime: '07:30',
        endTime: '09:10',
        room: '301',
      );

      final ubah = asal.copyWith(courseName: 'Basis Data Lanjut', dayOfWeek: 3);
      expect(ubah.courseName, 'Basis Data Lanjut');
      expect(ubah.dayOfWeek, 3);
      expect(ubah.startTime, '07:30');
      expect(ubah.room, '301');
    });
  });
}
