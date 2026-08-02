import 'package:flutter_test/flutter_test.dart';
import 'package:tracking/features/academic/domain/grade.dart';
import 'package:tracking/features/academic/domain/khs_parser.dart';

void main() {
  group('parseKhs — bentuk baris yang umum', () {
    test('kode, nama, sks, huruf, bobot', () {
      final hasil = parseKhs('TIF3204  Basis Data  3  A  4.00');

      expect(hasil, hasLength(1));
      expect(hasil.single.courseName, 'Basis Data');
      expect(hasil.single.sks, 3);
      expect(hasil.single.huruf, 'A');
      expect(hasil.single.bobot, 4.00);
    });

    test('ada kolom nomor urut di depan', () {
      // Nomor urut 1 tidak boleh tertukar dengan sks 3.
      final hasil = parseKhs('1  TIF3204  Basis Data  3  A  4.00');
      expect(hasil.single.sks, 3);
      expect(hasil.single.courseName, 'Basis Data');
    });

    test('tanpa bobot tetap terbaca', () {
      final hasil = parseKhs('MKU101  Pancasila  2  B+');
      expect(hasil.single.huruf, 'B+');
      expect(hasil.single.sks, 2);
      expect(hasil.single.bobot, isNull);
    });

    test('bobot berkoma juga terbaca', () {
      final hasil = parseKhs('TIF3204  Basis Data  3  A-  3,70');
      expect(hasil.single.bobot, closeTo(3.70, 0.001));
      expect(hasil.single.huruf, 'A-');
    });

    test('skala setengah: AB terbaca utuh, bukan A', () {
      final hasil = parseKhs('TIF3204  Basis Data  3  AB  3.50');
      expect(hasil.single.huruf, 'AB');
    });

    test('pemisah garis tegak dari tabel ikut dibersihkan', () {
      final hasil = parseKhs('TIF3204 | Struktur Data | 4 | B | 3.00');
      expect(hasil.single.courseName, 'Struktur Data');
      expect(hasil.single.sks, 4);
      expect(hasil.single.huruf, 'B');
    });

    test('beberapa baris sekaligus', () {
      final hasil = parseKhs('''
TIF3204  Basis Data           3  A   4.00
MKU101   Pancasila            2  B+  3.30
TIF3301  Jaringan Komputer    3  B   3.00
''');
      expect(hasil, hasLength(3));
      expect(hasil.map((e) => e.huruf), ['A', 'B+', 'B']);
    });
  });

  group('parseKhs — yang harus dilewati', () {
    test('baris tanpa huruf mutu dilewati', () {
      // Ini daftar mata kuliah, bukan nilai — sudah tugasnya pembaca KRS.
      expect(parseKhs('TIF3204  Basis Data  3'), isEmpty);
    });

    test('baris IPS/IPK dilewati', () {
      // Angka 3.45 bentuknya persis bobot, dan namanya kosong.
      expect(parseKhs('Indeks Prestasi Semester (IPS)  3.45'), isEmpty);
      expect(parseKhs('IPK  3.52'), isEmpty);
    });

    test('kepala tabel dilewati', () {
      expect(parseKhs('No  Kode  Mata Kuliah  SKS  Nilai  Bobot'), isEmpty);
    });

    test('identitas mahasiswa dilewati', () {
      expect(parseKhs('NIM : 2101234  Nama Mahasiswa : Rafi A'), isEmpty);
    });

    test('jumlah sks dilewati', () {
      expect(parseKhs('Jumlah SKS  20  A'), isEmpty);
    });

    test('nama terlalu pendek dilewati', () {
      expect(parseKhs('TIF3204  3  A  4.00'), isEmpty);
    });

    test('teks kosong tidak error', () {
      expect(parseKhs(''), isEmpty);
      expect(parseKhs('   \n  \n'), isEmpty);
    });
  });

  group('parseKhs — huruf mutu diambil dari yang paling kanan', () {
    test('kelas berhuruf di nama tidak tertukar dengan nilainya', () {
      // "Bahasa Inggris B" itu kelas B; nilainya A di ujung kanan.
      final hasil = parseKhs('MKU202  Bahasa Inggris B  2  A  4.00');
      expect(hasil.single.huruf, 'A');
      expect(hasil.single.courseName, 'Bahasa Inggris B');
    });
  });

  group('KhsEntry.janggal', () {
    test('huruf cocok dengan bobotnya', () {
      final hasil = parseKhs('TIF3204  Basis Data  3  A  4.00');
      expect(hasil.single.janggal(GradeScale.plusMinus), isFalse);
    });

    test('huruf tidak cocok dengan bobotnya ditandai', () {
      // A seharusnya 4.00, bukan 2.00 — salah satunya salah baca.
      final hasil = parseKhs('TIF3204  Basis Data  3  A  2.00');
      expect(hasil.single.janggal(GradeScale.plusMinus), isTrue);
    });

    test('tanpa bobot tidak bisa dianggap janggal', () {
      final hasil = parseKhs('TIF3204  Basis Data  3  A');
      expect(hasil.single.janggal(GradeScale.plusMinus), isFalse);
    });

    test('huruf dari skala lain tetap dikenali bobotnya', () {
      // AB hanya ada di skala setengah, tapi bobotnya jelas 3.50.
      final hasil = parseKhs('TIF3204  Basis Data  3  AB  3.50');
      expect(hasil.single.janggal(GradeScale.plusMinus), isFalse);
    });
  });

  group('findSemester', () {
    test('tahun ajaran dan istilahnya digabung', () {
      expect(
        findSemester('KARTU HASIL STUDI\nSemester Ganjil 2026/2027'),
        '2026/2027 Ganjil',
      );
    });

    test('tahun ajaran saja tetap berguna', () {
      expect(findSemester('Tahun Akademik 2026/2027'), '2026/2027');
    });

    test('gasal dikenali sama seperti ganjil', () {
      expect(findSemester('Semester Gasal'), 'Gasal');
    });

    test('tanpa petunjuk apa pun menghasilkan null', () {
      // Lebih baik kamu ketik sendiri daripada diisi tebakan yang salah:
      // nama semester yang mengelompokkan seluruh daftar nilaimu.
      expect(findSemester('TIF3204 Basis Data 3 A'), isNull);
    });
  });

  group('stepForLetter', () {
    test('huruf dari skala yang dipilih ketemu', () {
      expect(stepForLetter('A-', GradeScale.plusMinus)?.bobot, 3.70);
    });

    test('huruf dari skala satunya tetap ketemu', () {
      expect(stepForLetter('BC', GradeScale.plusMinus)?.bobot, 2.50);
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
      // Komponen 50 → C, tapi KHS bilang A.
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
