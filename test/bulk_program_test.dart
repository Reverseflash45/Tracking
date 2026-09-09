import 'package:flutter_test/flutter_test.dart';
import 'package:tracking/features/program/domain/bulk_program.dart';
import 'package:tracking/features/program/domain/pose_gerakan.dart';
import 'package:tracking/features/workout/data/models/exercise_entry.dart';
import 'package:tracking/features/workout/domain/bodyweight_progression.dart';

void main() {
  final kursi = programNaikBerat(VariasiAlat.denganKursi);
  final tanpa = programNaikBerat(VariasiAlat.tanpaKursi);

  group('bentuk program', () {
    test('kedua variasi punya dua sesi bergantian', () {
      for (final program in [kursi, tanpa]) {
        expect(program.sesi.map((s) => s.kode), ['A', 'B']);
      }
    });

    test('tiap sesi berisi jumlah gerakan yang sama di kedua variasi', () {
      // Versi tanpa kursi bukan versi yang dipangkas. Kalau jumlahnya beda,
      // salah satunya diam-diam jadi program yang lebih ringan — dan yang
      // memilihnya justru karena alat, bukan karena ingin lebih santai.
      for (var i = 0; i < 2; i++) {
        expect(kursi.sesi[i].gerakan.length, tanpa.sesi[i].gerakan.length);
      }
    });

    test('tidak ada nama gerakan yang kembar di dalam satu sesi', () {
      for (final program in [kursi, tanpa]) {
        for (final sesi in program.sesi) {
          final nama = sesi.gerakan.map((g) => g.nama).toList();
          expect(nama.toSet().length, nama.length, reason: '${sesi.nama} punya gerakan kembar');
        }
      }
    });

    test('tiap sesi melatih dorong, tarik, dan kaki dalam satu minggu', () {
      for (final program in [kursi, tanpa]) {
        final semua = [
          for (final sesi in program.sesi)
            for (final g in sesi.gerakan) g.nama.toLowerCase(),
        ];
        expect(semua.any((n) => n.contains('press') || n.contains('push')), isTrue);
        expect(semua.any((n) => n.contains('row') || n.contains('curl')), isTrue);
        expect(semua.any((n) => n.contains('squat')), isTrue);
        expect(semua.any((n) => n.contains('deadlift')), isTrue);
      }
    });
  });

  group('takaran', () {
    test('gerakan repetisi ditulis set x rep', () {
      const gerakan = GerakanProgram(
        nama: 'Goblet Squat',
        tipe: ExerciseType.beban,
        set: 3,
        rep: 10,
        istirahatDetik: 90,
        cue: '-',
      );
      expect(gerakan.takaran, '3 × 10');
      expect(gerakan.giliran, 3);
    });

    test('gerakan per sisi disebut per sisi dan memakan dua kali giliran', () {
      const gerakan = GerakanProgram(
        nama: 'One Arm Row',
        tipe: ExerciseType.beban,
        set: 3,
        rep: 12,
        perSisi: true,
        istirahatDetik: 75,
        cue: '-',
      );
      expect(gerakan.takaran, '3 × 12 / sisi');
      expect(gerakan.giliran, 6);
    });

    test('gerakan isometrik ditulis dalam detik, bukan repetisi', () {
      const gerakan = GerakanProgram(
        nama: 'Plank',
        tipe: ExerciseType.isometrik,
        set: 3,
        detik: 40,
        istirahatDetik: 45,
        cue: '-',
      );
      expect(gerakan.takaran, '3 × 40 detik');
    });

    test('isometrik memang tidak punya angka repetisi', () {
      for (final program in [kursi, tanpa]) {
        for (final sesi in program.sesi) {
          for (final g in sesi.gerakan) {
            if (g.tipe == ExerciseType.isometrik) {
              expect(g.detik, isNotNull, reason: '${g.nama} isometrik tanpa durasi');
              expect(g.rep, isNull, reason: '${g.nama} isometrik tapi punya rep');
            } else {
              expect(g.rep, isNotNull, reason: '${g.nama} tanpa rep');
            }
          }
        }
      }
    });
  });

  group('perkiraan durasi', () {
    test('masuk akal untuk sesi di sela kuliah', () {
      for (final program in [kursi, tanpa]) {
        for (final sesi in program.sesi) {
          expect(sesi.perkiraanMenit, greaterThanOrEqualTo(25));
          expect(sesi.perkiraanMenit, lessThanOrEqualTo(60),
              reason: '${sesi.nama} terlalu panjang untuk dikerjakan rutin');
        }
      }
    });

    test('dibulatkan ke kelipatan lima', () {
      for (final program in [kursi, tanpa]) {
        for (final sesi in program.sesi) {
          expect(sesi.perkiraanMenit % 5, 0);
        }
      }
    });
  });

  group('nama gerakan dikenali mesin progresi yang sudah ada', () {
    test('tiap gerakan bodyweight punya tangga progresinya', () {
      // Kalau ejaannya meleset, saran "naik level" berhenti muncul untuk
      // gerakan itu tanpa satu pun error — jadi ini yang diuji, bukan dilihat.
      for (final program in [kursi, tanpa]) {
        for (final sesi in program.sesi) {
          for (final g in sesi.gerakan) {
            if (g.tipe != ExerciseType.bodyweight) continue;
            expect(ladderFor(g.nama), isNotNull, reason: '${g.nama} tidak punya tangga progresi');
          }
        }
      }
    });

    test('plank isometrik juga dikenali', () {
      expect(ladderFor('Plank'), isNotNull);
    });
  });

  group('sesiKe', () {
    test('berselang-seling A B A B', () {
      expect(sesiKe(kursi, 0).kode, 'A');
      expect(sesiKe(kursi, 1).kode, 'B');
      expect(sesiKe(kursi, 2).kode, 'A');
      expect(sesiKe(kursi, 3).kode, 'B');
    });

    test('minggu kedua mulai dari B karena seminggu tiga sesi', () {
      expect(sesiKe(kursi, kSesiPerMinggu).kode, 'B');
    });
  });

  group('mingguKe', () {
    test('hari pertama sudah disebut minggu 1, bukan minggu 0', () {
      final mulai = DateTime(2026, 9, 7);
      expect(mingguKe(mulai, mulai), 1);
    });

    test('hari ketujuh masih minggu 1, hari kedelapan minggu 2', () {
      final mulai = DateTime(2026, 9, 7);
      expect(mingguKe(mulai, DateTime(2026, 9, 13)), 1);
      expect(mingguKe(mulai, DateTime(2026, 9, 14)), 2);
    });

    test('jam tidak ikut menggeser hitungan', () {
      final mulai = DateTime(2026, 9, 7, 23, 30);
      expect(mingguKe(mulai, DateTime(2026, 9, 8, 0, 30)), 1);
    });

    test('tanggal sebelum mulai tidak menghasilkan minggu negatif', () {
      final mulai = DateTime(2026, 9, 7);
      expect(mingguKe(mulai, DateTime(2026, 9, 1)), 1);
    });
  });

  group('VariasiAlat.fromDb', () {
    test('nilai yang tidak dikenal jatuh ke tanpa kursi', () {
      // Yang paling sedikit syaratnya, bukan yang paling lengkap: menebak
      // "punya kursi" berarti menyodorkan gerakan yang mungkin tidak bisa
      // dikerjakan sama sekali.
      expect(VariasiAlat.fromDb(null), VariasiAlat.tanpaKursi);
      expect(VariasiAlat.fromDb('entah'), VariasiAlat.tanpaKursi);
      expect(VariasiAlat.fromDb('kursi'), VariasiAlat.denganKursi);
    });
  });

  group('gambar gerakan', () {
    test('tiap gerakan di kedua program punya gambarnya', () {
      // Ini penjaga yang sebenarnya. Gerakan tanpa gambar tidak melempar error
      // apa pun — dia cuma muncul sebagai ikon polos, dan itu baru ketahuan
      // setelah APK terpasang di HP.
      final tanpaGambar = <String>[];
      for (final program in [kursi, tanpa]) {
        for (final sesi in program.sesi) {
          for (final g in sesi.gerakan) {
            if (diagramGerakan(g.nama) == null) tanpaGambar.add(g.nama);
          }
        }
      }
      expect(tanpaGambar, isEmpty,
          reason: 'gerakan berikut belum digambar: ${tanpaGambar.join(", ")}');
    });

    test('gerakan pengganti yang disebut juga punya gambarnya', () {
      // "Terlalu berat? Push Up biasa" tidak berguna kalau Push Up sendiri
      // tidak ada di katalog gambar.
      expect(diagramGerakan('Push Up'), isNotNull);
      expect(diagramGerakan('Split Squat'), isNotNull);
    });

    test('tiap pose mengisi kesebelas sendinya', () {
      // Sendi yang kosong jatuh ke tengah kanvas, dan hasilnya anggota badan
      // yang menempel ke titik acak — salah, tapi tetap tergambar.
      for (final nama in gerakanBergambar) {
        final diagram = diagramGerakan(nama)!;
        for (final pose in [diagram.mulai, diagram.akhir]) {
          expect(pose.titik.keys.toSet(), Sendi.values.toSet(),
              reason: '$nama punya sendi yang belum diisi');
        }
      }
    });

    test('semua titik berada di dalam kanvas', () {
      for (final nama in gerakanBergambar) {
        final diagram = diagramGerakan(nama)!;
        for (final pose in [diagram.mulai, diagram.akhir]) {
          for (final entry in pose.titik.entries) {
            expect(entry.value.dx, inInclusiveRange(0.0, 1.0),
                reason: '$nama: ${entry.key.name} keluar kanvas mendatar');
            expect(entry.value.dy, inInclusiveRange(0.0, 1.0),
                reason: '$nama: ${entry.key.name} keluar kanvas tegak');
          }
        }
      }
    });

    test('tidak ada kaki yang tenggelam di bawah lantai', () {
      // Lantai ada di y = 0.90. Kaki yang lebih rendah dari itu terbaca seperti
      // berdiri di dalam tanah.
      for (final nama in gerakanBergambar) {
        final diagram = diagramGerakan(nama)!;
        for (final pose in [diagram.mulai, diagram.akhir]) {
          for (final sendi in [Sendi.kakiKiri, Sendi.kakiKanan]) {
            expect(pose[sendi].dy, lessThanOrEqualTo(0.901), reason: '$nama: ${sendi.name}');
          }
        }
      }
    });

    test('gerakan berkursi memang menggambar kursinya', () {
      for (final nama in ['Bulgarian Split Squat', 'Step Up', 'Tricep Dip', 'Hip Thrust']) {
        final diagram = diagramGerakan(nama)!;
        expect(diagram.mulai.props, contains(Prop.kursi), reason: nama);
      }
    });

    test('gerakan tanpa alat tidak menggambar kursi', () {
      for (final nama in ['Split Squat', 'Pike Push Up', 'Glute Bridge', 'Plank']) {
        final diagram = diagramGerakan(nama)!;
        expect(diagram.mulai.props, isNot(contains(Prop.kursi)), reason: nama);
      }
    });

    test('gerakan bodyweight tidak menggambar dumbbell', () {
      for (final program in [kursi, tanpa]) {
        for (final sesi in program.sesi) {
          for (final g in sesi.gerakan) {
            if (g.tipe != ExerciseType.bodyweight) continue;
            final diagram = diagramGerakan(g.nama)!;
            expect(diagram.mulai.props, isNot(contains(Prop.beban)), reason: g.nama);
          }
        }
      }
    });
  });
}
