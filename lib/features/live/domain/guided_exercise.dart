import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../../workout/data/models/exercise_entry.dart';
import 'pose_geometry.dart';
import 'rep_counter.dart';

/// Aturan postur yang bisa dinilai dari satu kamera 2D.
///
/// Sengaja sedikit. Banyak kesalahan teknik yang populer disebut aplikasi
/// kebugaran (lutut masuk ke dalam, bahu tidak sejajar) butuh pandangan depan
/// atau kedalaman yang tidak dimiliki kamera tunggal. Yang masuk daftar ini
/// hanya yang benar-benar terbaca dari samping.
class PostureRule {
  const PostureRule({
    required this.warning,
    required this.joint,
    this.minDegrees,
    this.maxDegrees,
  });

  /// Kalimat yang ditampilkan ke user saat aturan ini dilanggar.
  final String warning;

  final JointPair joint;

  final double? minDegrees;
  final double? maxDegrees;

  /// Null kalau sudutnya tidak terbaca cukup yakin — bukan berarti lolos.
  bool? evaluate(Pose pose) {
    final reading = readBestSide(pose, joint);
    if (reading == null || !reading.reliable) return null;

    if (minDegrees != null && reading.degrees < minDegrees!) return false;
    if (maxDegrees != null && reading.degrees > maxDegrees!) return false;
    return true;
  }
}

/// Satu gerakan yang bisa dipandu kamera.
class GuidedExercise {
  const GuidedExercise({
    required this.slug,
    required this.name,
    required this.type,
    required this.icon,
    required this.joint,
    required this.flexBelow,
    required this.extendAbove,
    required this.countOn,
    required this.setup,
    required this.cue,
    this.goodDepthBelow,
    this.postureRules = const [],
  });

  final String slug;
  final String name;
  final ExerciseType type;
  final IconData icon;

  /// Sudut sendi yang dilacak untuk menghitung repetisi.
  final JointPair joint;

  final double flexBelow;
  final double extendAbove;
  final RepPhase countOn;

  /// Cara menaruh HP supaya gerakannya terbaca.
  final String setup;

  /// Satu petunjuk teknik terpenting.
  final String cue;

  /// Sudut terkecil yang sebaiknya dicapai tiap repetisi. Dipakai untuk
  /// memberi tahu rentang geraknya kurang dalam.
  final double? goodDepthBelow;

  final List<PostureRule> postureRules;

  RepCounter newCounter() => RepCounter(
        flexBelow: flexBelow,
        extendAbove: extendAbove,
        countOn: countOn,
      );

  /// Peringatan postur yang sedang berlaku pada frame ini.
  List<String> postureWarnings(Pose pose) => [
        for (final rule in postureRules)
          if (rule.evaluate(pose) == false) rule.warning,
      ];

  /// Catatan rentang gerak untuk satu repetisi yang baru selesai. Null kalau
  /// kedalamannya sudah memadai.
  String? depthWarning(RepEvent event) {
    final target = goodDepthBelow;
    if (target == null || event.minAngle <= target) return null;
    return 'Rep ${event.index} kurang dalam';
  }
}

// --- Sudut sendi yang dipakai berulang ---

const _sikuKiri = JointTriple(
  PoseLandmarkType.leftShoulder,
  PoseLandmarkType.leftElbow,
  PoseLandmarkType.leftWrist,
);
const _sikuKanan = JointTriple(
  PoseLandmarkType.rightShoulder,
  PoseLandmarkType.rightElbow,
  PoseLandmarkType.rightWrist,
);
const _siku = JointPair(left: _sikuKiri, right: _sikuKanan);

const _lututKiri = JointTriple(
  PoseLandmarkType.leftHip,
  PoseLandmarkType.leftKnee,
  PoseLandmarkType.leftAnkle,
);
const _lututKanan = JointTriple(
  PoseLandmarkType.rightHip,
  PoseLandmarkType.rightKnee,
  PoseLandmarkType.rightAnkle,
);
const _lutut = JointPair(left: _lututKiri, right: _lututKanan);

/// Sudut pinggul: bahu-pinggul-lutut. Lurus (~180) berarti badan sebaris.
const _pinggulKiri = JointTriple(
  PoseLandmarkType.leftShoulder,
  PoseLandmarkType.leftHip,
  PoseLandmarkType.leftKnee,
);
const _pinggulKanan = JointTriple(
  PoseLandmarkType.rightShoulder,
  PoseLandmarkType.rightHip,
  PoseLandmarkType.rightKnee,
);
const _pinggul = JointPair(left: _pinggulKiri, right: _pinggulKanan);

/// Sudut bahu: pinggul-bahu-siku. Kecil berarti lengan atas menempel badan.
const _bahuKiri = JointTriple(
  PoseLandmarkType.leftHip,
  PoseLandmarkType.leftShoulder,
  PoseLandmarkType.leftElbow,
);
const _bahuKanan = JointTriple(
  PoseLandmarkType.rightHip,
  PoseLandmarkType.rightShoulder,
  PoseLandmarkType.rightElbow,
);
const _bahu = JointPair(left: _bahuKiri, right: _bahuKanan);

/// Sudut bahu ke pergelangan: dipakai jumping jack, karena yang bergerak besar
/// adalah lengan terangkat, bukan tekukan siku.
const _angkatKiri = JointTriple(
  PoseLandmarkType.leftHip,
  PoseLandmarkType.leftShoulder,
  PoseLandmarkType.leftWrist,
);
const _angkatKanan = JointTriple(
  PoseLandmarkType.rightHip,
  PoseLandmarkType.rightShoulder,
  PoseLandmarkType.rightWrist,
);
const _angkat = JointPair(left: _angkatKiri, right: _angkatKanan);

/// Lima gerakan yang sudutnya benar-benar terbaca andal dari satu kamera.
///
/// Bench press, deadlift, dan pull up sengaja tidak masuk: bench press sudut
/// kameranya mustahil, deadlift dari depan membuat tubuh saling menutupi, dan
/// pull up memutar badan sehingga titiknya hilang di tengah gerakan.
const List<GuidedExercise> guidedExercises = [
  GuidedExercise(
    slug: 'push-up',
    name: 'Push Up',
    type: ExerciseType.bodyweight,
    icon: Icons.accessibility_new,
    joint: _siku,
    flexBelow: 95,
    extendAbove: 155,
    countOn: RepPhase.lurus,
    goodDepthBelow: 100,
    setup: 'Taruh HP di lantai sejajar badan, 2-3 meter di sampingmu.',
    cue: 'Badan satu garis dari kepala sampai tumit.',
    postureRules: [
      PostureRule(
        warning: 'Pinggul turun — kencangkan perut',
        joint: _pinggul,
        minDegrees: 155,
      ),
    ],
  ),
  GuidedExercise(
    slug: 'squat',
    name: 'Squat',
    type: ExerciseType.bodyweight,
    icon: Icons.airline_seat_legroom_reduced,
    joint: _lutut,
    flexBelow: 100,
    extendAbove: 160,
    countOn: RepPhase.lurus,
    goodDepthBelow: 100,
    setup: 'Taruh HP setinggi pinggang, 2-3 meter di sampingmu.',
    cue: 'Turun sampai paha minimal sejajar lantai.',
  ),
  GuidedExercise(
    slug: 'bicep-curl',
    name: 'Bicep Curl',
    type: ExerciseType.beban,
    icon: Icons.fitness_center,
    joint: _siku,
    flexBelow: 60,
    extendAbove: 150,
    countOn: RepPhase.lurus,
    goodDepthBelow: 60,
    setup: 'Taruh HP setinggi dada, 2-3 meter di sampingmu.',
    cue: 'Siku diam menempel badan, jangan mengayun.',
    postureRules: [
      PostureRule(
        warning: 'Siku terlalu maju — jangan mengayun',
        joint: _bahu,
        maxDegrees: 45,
      ),
    ],
  ),
  GuidedExercise(
    slug: 'shoulder-press',
    name: 'Shoulder Press',
    type: ExerciseType.beban,
    icon: Icons.arrow_upward,
    joint: _siku,
    flexBelow: 90,
    extendAbove: 160,
    countOn: RepPhase.lurus,
    setup: 'Taruh HP setinggi dada, 2-3 meter di sampingmu.',
    cue: 'Jangan melengkungkan punggung untuk membantu dorongan.',
    postureRules: [
      PostureRule(
        warning: 'Punggung melengkung ke belakang',
        joint: _pinggul,
        minDegrees: 160,
      ),
    ],
  ),
  GuidedExercise(
    slug: 'jumping-jack',
    name: 'Jumping Jack',
    type: ExerciseType.bodyweight,
    icon: Icons.directions_run,
    joint: _angkat,
    flexBelow: 45,
    extendAbove: 140,
    // Dihitung saat tangan kembali turun, bukan saat terangkat, supaya satu
    // repetisi berarti satu siklus penuh.
    countOn: RepPhase.tekuk,
    setup: 'Taruh HP menghadapmu dari depan, 3 meter jauhnya.',
    cue: 'Tangan sampai bertemu di atas kepala.',
  ),
];

GuidedExercise? guidedExerciseBySlug(String slug) {
  for (final exercise in guidedExercises) {
    if (exercise.slug == slug) return exercise;
  }
  return null;
}
