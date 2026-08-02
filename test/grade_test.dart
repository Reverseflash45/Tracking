import 'package:flutter_test/flutter_test.dart';
import 'package:tracking/features/academic/domain/grade.dart';

GradeComponent _komponen(String nama, double bobot, [double? skor]) => GradeComponent(
      id: nama,
      courseId: 'c1',
      name: nama,
      weight: bobot,
      score: skor,
    );

CourseGrade _matkul({
  String id = 'c1',
  String nama = 'Basis Data',
  int? sks = 3,
  String? semester = '2026/2027 Ganjil',
  List<GradeComponent> komponen = const [],
}) =>
    CourseGrade(
      courseId: id,
      courseName: nama,
      sks: sks,
      semester: semester,
      components: komponen,
    );

void main() {
  group('letterFor', () {
    test('skala plus-minus', () {
      expect(letterFor(90, GradeScale.plusMinus).huruf, 'A');
      expect(letterFor(85, GradeScale.plusMinus).huruf, 'A');
      expect(letterFor(84.9, GradeScale.plusMinus).huruf, 'A-');
      expect(letterFor(70, GradeScale.plusMinus).huruf, 'B');
      expect(letterFor(0, GradeScale.plusMinus).huruf, 'E');
    });

    test('skala setengah', () {
      expect(letterFor(82, GradeScale.setengah).huruf, 'A');
      expect(letterFor(76, GradeScale.setengah).huruf, 'AB');
      expect(letterFor(66, GradeScale.setengah).huruf, 'BC');
    });

    test('bobot IP mengikuti hurufnya', () {
      expect(letterFor(90, GradeScale.plusMinus).bobot, 4.0);
      expect(letterFor(76, GradeScale.setengah).bobot, 3.5);
    });

    test('skala yang tidak dikenal jatuh ke plus-minus', () {
      expect(GradeScale.fromName('entah'), GradeScale.plusMinus);
      expect(GradeScale.fromName(null), GradeScale.plusMinus);
    });
  });

  group('CourseGrade.skor', () {
    test('semua komponen terisi: rata-rata tertimbang biasa', () {
      final matkul = _matkul(komponen: [
        _komponen('Tugas', 20, 80),
        _komponen('UTS', 30, 70),
        _komponen('UAS', 50, 90),
      ]);
      // 80*0.2 + 70*0.3 + 90*0.5 = 16 + 21 + 45 = 82
      expect(matkul.skor, closeTo(82, 0.001));
      expect(matkul.lengkap, isTrue);
    });

    test('komponen yang belum dinilai tidak dianggap nol', () {
      final matkul = _matkul(komponen: [
        _komponen('Tugas', 20, 80),
        _komponen('UTS', 30, 70),
        _komponen('UAS', 50), // belum keluar
      ]);
      // Dinormalkan ke bobot yang terisi: (80*20 + 70*30) / 50 = 74
      expect(matkul.skor, closeTo(74, 0.001));
      expect(matkul.lengkap, isFalse);
      expect(matkul.porsiTerisi, closeTo(0.5, 0.001));
    });

    test('kalau nol dianggap nilai, hasilnya jauh berbeda', () {
      // Penjaga niat: kalau UAS kosong pernah dihitung nol, skornya jadi 37 —
      // mahasiswa yang baru selesai UTS akan melihat E untuk semua matkul.
      final matkul = _matkul(komponen: [
        _komponen('Tugas', 20, 80),
        _komponen('UTS', 30, 70),
        _komponen('UAS', 50),
      ]);
      expect(matkul.skor, isNot(closeTo(37, 1)));
    });

    test('tanpa satu pun nilai, skornya null', () {
      final matkul = _matkul(komponen: [_komponen('UAS', 100)]);
      expect(matkul.skor, isNull);
      expect(matkul.huruf(GradeScale.plusMinus), isNull);
    });

    test('tanpa komponen sama sekali, skornya null', () {
      expect(_matkul().skor, isNull);
      expect(_matkul().lengkap, isFalse);
    });
  });

  group('bobotJanggal', () {
    test('berjumlah 100 dianggap benar', () {
      final matkul = _matkul(komponen: [
        _komponen('UTS', 40, 80),
        _komponen('UAS', 60, 80),
      ]);
      expect(matkul.bobotJanggal, isFalse);
    });

    test('99,9 dari tiga kali 33,3 tidak diributkan', () {
      final matkul = _matkul(komponen: [
        for (var i = 0; i < 3; i++) _komponen('K$i', 33.3, 80),
      ]);
      expect(matkul.bobotJanggal, isFalse);
    });

    test('salah ketik yang nyata ditandai', () {
      final matkul = _matkul(komponen: [
        _komponen('UTS', 40, 80),
        _komponen('UAS', 40, 80),
      ]);
      expect(matkul.bobotJanggal, isTrue);
    });

    test('tanpa komponen tidak dianggap janggal', () {
      expect(_matkul().bobotJanggal, isFalse);
    });
  });

  group('summarizeGrades', () {
    test('IP ditimbang sks, bukan rata-rata biasa', () {
      final hasil = summarizeGrades(
        [
          _matkul(id: 'a', sks: 4, komponen: [_komponen('UAS', 100, 90)]), // A, 4.0
          _matkul(id: 'b', sks: 2, komponen: [_komponen('UAS', 100, 71)]), // B, 3.0
        ],
        GradeScale.plusMinus,
      );
      // (4.0*4 + 3.0*2) / 6 = 22/6 = 3.667
      expect(hasil.ip, closeTo(3.6667, 0.001));
      expect(hasil.sksDinilai, 6);
    });

    test('matkul tanpa sks tidak ikut dihitung tapi tetap dilaporkan', () {
      final hasil = summarizeGrades(
        [
          _matkul(id: 'a', sks: 3, komponen: [_komponen('UAS', 100, 90)]),
          _matkul(id: 'b', sks: null, komponen: [_komponen('UAS', 100, 50)]),
        ],
        GradeScale.plusMinus,
      );

      expect(hasil.ip, 4.0);
      expect(hasil.matkulDinilai, 1);
      expect(hasil.matkulTotal, 2);
      expect(hasil.sebagian, isTrue);
    });

    test('matkul tanpa nilai tidak menyeret IP ke bawah', () {
      final hasil = summarizeGrades(
        [
          _matkul(id: 'a', sks: 3, komponen: [_komponen('UAS', 100, 90)]),
          _matkul(id: 'b', sks: 3),
        ],
        GradeScale.plusMinus,
      );

      expect(hasil.ip, 4.0);
      expect(hasil.sksDinilai, 3);
      // Sks-nya tetap tercatat supaya terlihat masih ada yang menggantung.
      expect(hasil.sksTotal, 6);
    });

    test('nilai sementara ikut menghitung IP', () {
      // Ini disengaja: IP sementara berguna, asal ditandai sementara di UI.
      final hasil = summarizeGrades(
        [
          _matkul(sks: 3, komponen: [_komponen('UTS', 30, 90), _komponen('UAS', 70)]),
        ],
        GradeScale.plusMinus,
      );
      expect(hasil.ip, 4.0);
    });

    test('daftar kosong tidak menghasilkan nol palsu', () {
      final hasil = summarizeGrades(const [], GradeScale.plusMinus);
      expect(hasil.ip, isNull);
      expect(hasil.kosong, isTrue);
      expect(hasil.sebagian, isFalse);
    });

    test('skala yang berbeda menghasilkan IP yang berbeda', () {
      final matkul = [
        _matkul(sks: 3, komponen: [_komponen('UAS', 100, 82)]),
      ];
      // 82 → A- (3.7) di plus-minus, tapi A (4.0) di skala setengah.
      expect(summarizeGrades(matkul, GradeScale.plusMinus).ip, closeTo(3.7, 0.001));
      expect(summarizeGrades(matkul, GradeScale.setengah).ip, closeTo(4.0, 0.001));
    });
  });

  group('groupBySemester', () {
    test('semester terbaru di atas', () {
      final hasil = groupBySemester([
        _matkul(id: 'a', semester: '2025/2026 Genap'),
        _matkul(id: 'b', semester: '2026/2027 Ganjil'),
      ]);
      expect(hasil.keys.first, '2026/2027 Ganjil');
    });

    test('yang belum diberi semester selalu paling bawah', () {
      final hasil = groupBySemester([
        _matkul(id: 'a', semester: null),
        _matkul(id: 'b', semester: '2020/2021 Ganjil'),
      ]);
      expect(hasil.keys.last, kSemesterTanpaNama);
    });

    test('semester kosong disamakan dengan tanpa semester', () {
      final hasil = groupBySemester([_matkul(semester: '   ')]);
      expect(hasil.keys.single, kSemesterTanpaNama);
    });

    test('daftar kosong menghasilkan peta kosong', () {
      expect(groupBySemester(const []), isEmpty);
    });
  });

  group('GradeComponent.fromMap', () {
    test('nilai null tetap null, bukan nol', () {
      final komponen = GradeComponent.fromMap({
        'id': 'k',
        'course_id': 'c',
        'name': 'UAS',
        'weight': 50,
        'score': null,
      });
      expect(komponen.score, isNull);
      expect(komponen.dinilai, isFalse);
    });

    test('nilai nol yang memang nol tetap terbaca nol', () {
      final komponen = GradeComponent.fromMap({
        'id': 'k',
        'course_id': 'c',
        'name': 'UAS',
        'weight': 50,
        'score': 0,
      });
      expect(komponen.score, 0);
      expect(komponen.dinilai, isTrue);
    });
  });
}
