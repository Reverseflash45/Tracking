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
