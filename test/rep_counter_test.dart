import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:tracking/features/live/domain/guided_exercise.dart';
import 'package:tracking/features/live/domain/pose_geometry.dart';
import 'package:tracking/features/live/domain/rep_counter.dart';

PoseLandmark _mark(
  PoseLandmarkType type,
  double x,
  double y, {
  double likelihood = 0.9,
}) {
  return PoseLandmark(type: type, x: x, y: y, z: 0, likelihood: likelihood);
}

Pose _pose(List<PoseLandmark> landmarks) {
  return Pose(landmarks: {for (final l in landmarks) l.type: l});
}

/// Jalankan satu siklus gerakan penuh: lurus -> tekuk -> lurus.
List<RepEvent> _cycle(
  RepCounter counter,
  List<double> angles, {
  int stepMs = 100,
}) {
  final events = <RepEvent>[];
  for (var i = 0; i < angles.length; i++) {
    final event = counter.update(angles[i], nowMs: i * stepMs);
    if (event != null) events.add(event);
  }
  return events;
}

void main() {
  group('jointAngle', () {
    test('sudut siku-siku terbaca 90 derajat', () {
      final a = _mark(PoseLandmarkType.leftShoulder, 0, 0);
      final b = _mark(PoseLandmarkType.leftElbow, 0, 10);
      final c = _mark(PoseLandmarkType.leftWrist, 10, 10);

      expect(jointAngle(a, b, c), closeTo(90, 0.001));
    });

    test('titik segaris terbaca 180 derajat', () {
      final a = _mark(PoseLandmarkType.leftShoulder, 0, 0);
      final b = _mark(PoseLandmarkType.leftElbow, 0, 10);
      final c = _mark(PoseLandmarkType.leftWrist, 0, 20);

      expect(jointAngle(a, b, c), closeTo(180, 0.001));
    });

    test('lengan terlipat penuh mendekati 0 derajat', () {
      final a = _mark(PoseLandmarkType.leftShoulder, 0, 0);
      final b = _mark(PoseLandmarkType.leftElbow, 0, 10);
      final c = _mark(PoseLandmarkType.leftWrist, 0, 0.5);

      expect(jointAngle(a, b, c), lessThan(10));
    });

    test('hasilnya tidak pernah melebihi 180', () {
      // Susunan cermin dari kasus 90 derajat; sudut dalam tetap 90, bukan 270.
      final a = _mark(PoseLandmarkType.leftShoulder, 0, 0);
      final b = _mark(PoseLandmarkType.leftElbow, 0, 10);
      final c = _mark(PoseLandmarkType.leftWrist, -10, 10);

      expect(jointAngle(a, b, c), closeTo(90, 0.001));
    });
  });

  group('readBestSide', () {
    const pair = JointPair(
      left: JointTriple(
        PoseLandmarkType.leftShoulder,
        PoseLandmarkType.leftElbow,
        PoseLandmarkType.leftWrist,
      ),
      right: JointTriple(
        PoseLandmarkType.rightShoulder,
        PoseLandmarkType.rightElbow,
        PoseLandmarkType.rightWrist,
      ),
    );

    test('memilih sisi dengan keyakinan tertinggi', () {
      final pose = _pose([
        // Sisi kiri tertutup badan: sudutnya lurus tapi tidak dipercaya.
        _mark(PoseLandmarkType.leftShoulder, 0, 0, likelihood: 0.2),
        _mark(PoseLandmarkType.leftElbow, 0, 10, likelihood: 0.2),
        _mark(PoseLandmarkType.leftWrist, 0, 20, likelihood: 0.2),
        // Sisi kanan jelas terlihat, sudutnya 90.
        _mark(PoseLandmarkType.rightShoulder, 0, 0, likelihood: 0.95),
        _mark(PoseLandmarkType.rightElbow, 0, 10, likelihood: 0.95),
        _mark(PoseLandmarkType.rightWrist, 10, 10, likelihood: 0.95),
      ]);

      final reading = readBestSide(pose, pair)!;
      expect(reading.degrees, closeTo(90, 0.001));
      expect(reading.reliable, isTrue);
    });

    test('keyakinan diambil dari titik terlemah, bukan rata-rata', () {
      final pose = _pose([
        _mark(PoseLandmarkType.rightShoulder, 0, 0, likelihood: 0.99),
        _mark(PoseLandmarkType.rightElbow, 0, 10, likelihood: 0.99),
        // Satu titik hilang sudah cukup membuat sudutnya tak bisa dipercaya.
        _mark(PoseLandmarkType.rightWrist, 10, 10, likelihood: 0.1),
      ]);

      final reading = readBestSide(pose, pair)!;
      expect(reading.confidence, closeTo(0.1, 0.001));
      expect(reading.reliable, isFalse);
    });

    test('null kalau titiknya tidak ada sama sekali', () {
      expect(readBestSide(_pose([]), pair), isNull);
    });

    test('memakai sisi yang ada kalau sisi lain hilang', () {
      final pose = _pose([
        _mark(PoseLandmarkType.leftShoulder, 0, 0),
        _mark(PoseLandmarkType.leftElbow, 0, 10),
        _mark(PoseLandmarkType.leftWrist, 10, 10),
      ]);

      expect(readBestSide(pose, pair)!.degrees, closeTo(90, 0.001));
    });
  });

  group('RepCounter', () {
    RepCounter pushUp() => RepCounter(
          flexBelow: 95,
          extendAbove: 155,
          countOn: RepPhase.lurus,
        );

    test('satu siklus turun-naik menghasilkan satu repetisi', () {
      final counter = pushUp();
      final events = _cycle(counter, [170, 120, 80, 120, 170]);

      expect(counter.reps, 1);
      expect(events, hasLength(1));
      expect(events.single.index, 1);
    });

    test('mulai dari posisi bawah tidak memberi repetisi gratis', () {
      final counter = pushUp();
      // Kamera baru menangkap badan saat sudah di bawah.
      _cycle(counter, [80, 170]);

      expect(counter.reps, 1);

      final lain = pushUp();
      // Hanya turun lalu berhenti: belum genap satu repetisi.
      _cycle(lain, [80, 90, 85]);
      expect(lain.reps, 0);
    });

    test('getaran di sekitar satu ambang tidak menghitung berkali-kali', () {
      final counter = pushUp();
      // Naik-turun tepat di sekitar 95 tanpa pernah mencapai 155.
      _cycle(counter, [170, 94, 96, 93, 97, 92, 98, 94]);

      expect(counter.reps, 0);
    });

    test('berhenti di zona antara tidak mengubah hitungan', () {
      final counter = pushUp();
      _cycle(counter, [170, 120, 130, 125, 140]);

      expect(counter.reps, 0);
      expect(counter.phase, RepPhase.lurus);
    });

    test('tiga siklus penuh menghasilkan tiga repetisi', () {
      final counter = pushUp();
      final events = _cycle(counter, [
        170, 80, 170, //
        80, 170, //
        80, 170,
      ]);

      expect(counter.reps, 3);
      expect([for (final e in events) e.index], [1, 2, 3]);
    });

    test('rentang gerak dicatat per repetisi', () {
      final counter = pushUp();
      final events = _cycle(counter, [170, 120, 70, 120, 175]);

      expect(events.single.minAngle, 70);
      expect(events.single.maxAngle, 175);
      expect(events.single.rangeOfMotion, 105);
    });

    test('rentang gerak repetisi berikutnya tidak mewarisi yang lama', () {
      final counter = pushUp();
      final events = _cycle(counter, [170, 40, 170, 90, 170]);

      expect(events, hasLength(2));
      expect(events[0].minAngle, 40);
      // Repetisi kedua hanya turun sampai 90, bukan ikut membaca 40.
      expect(events[1].minAngle, 90);
    });

    test('durasi repetisi dihitung dari waktu yang diberikan', () {
      final counter = pushUp();
      final events = _cycle(counter, [170, 80, 170], stepMs: 500);

      expect(events.single.durationMs, 1000);
    });

    test('interrupt mencegah gerakan tak terlihat ikut terhitung', () {
      final counter = pushUp();
      counter.update(170, nowMs: 0);
      counter.update(80, nowMs: 100);

      // Badan keluar frame di tengah gerakan.
      counter.interrupt();

      counter.update(170, nowMs: 200);
      expect(counter.reps, 0);
    });

    test('reset mengosongkan hitungan', () {
      final counter = pushUp();
      _cycle(counter, [170, 80, 170]);
      expect(counter.reps, 1);

      counter.reset();
      expect(counter.reps, 0);
      expect(counter.phase, isNull);
    });

    test('jumping jack dihitung saat tangan kembali turun', () {
      final counter = RepCounter(
        flexBelow: 45,
        extendAbove: 140,
        countOn: RepPhase.tekuk,
      );

      // Mulai tangan di bawah, angkat, turun lagi = 1 repetisi.
      final events = _cycle(counter, [20, 160, 20]);
      expect(counter.reps, 1);
      expect(events, hasLength(1));

      // Mengangkat tangan saja belum menambah hitungan.
      counter.update(160, nowMs: 500);
      expect(counter.reps, 1);
    });

    test('ambang tekuk harus di bawah ambang lurus', () {
      expect(
        () => RepCounter(flexBelow: 160, extendAbove: 90, countOn: RepPhase.lurus),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('GuidedExercise', () {
    test('semua slug unik', () {
      final slugs = [for (final e in guidedExercises) e.slug];
      expect(slugs.toSet().length, slugs.length);
    });

    test('tiap gerakan punya ambang yang masuk akal', () {
      for (final exercise in guidedExercises) {
        expect(
          exercise.flexBelow,
          lessThan(exercise.extendAbove),
          reason: '${exercise.name} punya ambang terbalik',
        );
        // Jarak antar ambang harus cukup lebar supaya getaran tidak menembus
        // keduanya dalam satu frame.
        expect(
          exercise.extendAbove - exercise.flexBelow,
          greaterThanOrEqualTo(50),
          reason: '${exercise.name} ambangnya terlalu berdekatan',
        );
      }
    });

    test('peringatan kedalaman hanya muncul saat rentang geraknya kurang', () {
      final pushUp = guidedExerciseBySlug('push-up')!;

      const dangkal = RepEvent(index: 1, minAngle: 130, maxAngle: 170, durationMs: 800);
      const dalam = RepEvent(index: 2, minAngle: 80, maxAngle: 170, durationMs: 900);

      expect(pushUp.depthWarning(dangkal), 'Rep 1 kurang dalam');
      expect(pushUp.depthWarning(dalam), isNull);
    });

    test('gerakan tanpa target kedalaman tidak pernah mengeluh', () {
      final press = guidedExerciseBySlug('shoulder-press')!;
      const event = RepEvent(index: 1, minAngle: 140, maxAngle: 170, durationMs: 800);

      expect(press.depthWarning(event), isNull);
    });

    test('slug tak dikenal mengembalikan null', () {
      expect(guidedExerciseBySlug('bench-press'), isNull);
    });
  });

  group('PostureRule', () {
    test('pinggul turun terdeteksi saat push up', () {
      final pushUp = guidedExerciseBySlug('push-up')!;

      // Bahu-pinggul-lutut membentuk sudut tajam: pinggul melorot.
      final melorot = _pose([
        _mark(PoseLandmarkType.rightShoulder, 0, 0),
        _mark(PoseLandmarkType.rightHip, 10, 5),
        _mark(PoseLandmarkType.rightKnee, 20, 0),
      ]);

      expect(pushUp.postureWarnings(melorot), isNotEmpty);
    });

    test('badan lurus tidak memicu peringatan', () {
      final pushUp = guidedExerciseBySlug('push-up')!;

      final lurus = _pose([
        _mark(PoseLandmarkType.rightShoulder, 0, 0),
        _mark(PoseLandmarkType.rightHip, 10, 0),
        _mark(PoseLandmarkType.rightKnee, 20, 0),
      ]);

      expect(pushUp.postureWarnings(lurus), isEmpty);
    });

    test('titik yang tidak terlihat tidak dianggap pelanggaran', () {
      final pushUp = guidedExerciseBySlug('push-up')!;

      final samar = _pose([
        _mark(PoseLandmarkType.rightShoulder, 0, 0, likelihood: 0.1),
        _mark(PoseLandmarkType.rightHip, 10, 5, likelihood: 0.1),
        _mark(PoseLandmarkType.rightKnee, 20, 0, likelihood: 0.1),
      ]);

      // Sudutnya melanggar, tapi keyakinannya terlalu rendah untuk menuduh.
      expect(pushUp.postureWarnings(samar), isEmpty);
    });
  });

  group('bodyVisible', () {
    test('butuh minimal satu bahu dan satu pinggul terlihat', () {
      final samping = _pose([
        _mark(PoseLandmarkType.rightShoulder, 0, 0),
        _mark(PoseLandmarkType.rightHip, 0, 10),
        _mark(PoseLandmarkType.leftShoulder, 0, 0, likelihood: 0.1),
        _mark(PoseLandmarkType.leftHip, 0, 10, likelihood: 0.1),
      ]);

      expect(bodyVisible(samping), isTrue);
    });

    test('frame tanpa tubuh ditandai tidak terlihat', () {
      expect(bodyVisible(_pose([])), isFalse);

      final wajahSaja = _pose([_mark(PoseLandmarkType.nose, 0, 0)]);
      expect(bodyVisible(wajahSaja), isFalse);
    });
  });
}
