import 'dart:math';

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

/// Ambang keyakinan minimum sebuah titik dianggap benar-benar terlihat.
///
/// ML Kit tetap menebak posisi sendi yang tertutup badan, dengan likelihood
/// rendah. Menghitung sudut dari tebakan itu menghasilkan angka yang terlihat
/// wajar padahal ngawur — lebih baik bilang "tidak terlihat".
const double kMinLikelihood = 0.5;

/// Sudut di titik [b], antara ruas b→a dan b→c, dalam derajat 0-180.
///
/// Ini murni 2D. Kedalaman (sumbu z) sengaja tidak dipakai: nilai z dari ML Kit
/// relatif terhadap pinggul dan tidak berskala metrik, jadi memasukkannya
/// menambah derau tanpa menambah ketelitian.
double jointAngle(PoseLandmark a, PoseLandmark b, PoseLandmark c) {
  final radians =
      atan2(c.y - b.y, c.x - b.x) - atan2(a.y - b.y, a.x - b.x);
  var degrees = radians * 180 / pi;
  degrees = degrees.abs();
  if (degrees > 180) degrees = 360 - degrees;
  return degrees;
}

/// Tiga titik yang membentuk satu sudut sendi.
class JointTriple {
  const JointTriple(this.a, this.b, this.c);

  final PoseLandmarkType a;

  /// Titik puncak, tempat sudutnya diukur.
  final PoseLandmarkType b;

  final PoseLandmarkType c;
}

/// Pasangan kiri/kanan dari sudut yang sama.
class JointPair {
  const JointPair({required this.left, required this.right});

  final JointTriple left;
  final JointTriple right;
}

/// Hasil pembacaan satu sudut, lengkap dengan seberapa yakin pembacaannya.
class AngleReading {
  const AngleReading({required this.degrees, required this.confidence});

  final double degrees;

  /// Likelihood terendah dari ketiga titik pembentuknya. Dipakai rantai
  /// terlemah, bukan rata-rata: satu titik yang tidak terlihat sudah cukup
  /// membuat sudutnya tidak bisa dipercaya.
  final double confidence;

  bool get reliable => confidence >= kMinLikelihood;
}

AngleReading? _read(Pose pose, JointTriple triple) {
  final a = pose.landmarks[triple.a];
  final b = pose.landmarks[triple.b];
  final c = pose.landmarks[triple.c];
  if (a == null || b == null || c == null) return null;

  final confidence = [a.likelihood, b.likelihood, c.likelihood].reduce(min);
  return AngleReading(degrees: jointAngle(a, b, c), confidence: confidence);
}

/// Baca sudut dari sisi tubuh yang paling jelas terlihat.
///
/// Saat merekam dari samping, satu sisi tubuh menutupi sisi lainnya. Memaksa
/// memakai sisi kiri (atau merata-ratakan keduanya) akan menarik sudutnya ke
/// arah sisi yang tertutup. Jadi dipilih sisi dengan keyakinan tertinggi.
AngleReading? readBestSide(Pose pose, JointPair pair) {
  final left = _read(pose, pair.left);
  final right = _read(pose, pair.right);

  if (left == null) return right;
  if (right == null) return left;
  return left.confidence >= right.confidence ? left : right;
}

/// True kalau titik-titik inti tubuh terlihat cukup jelas untuk mulai menilai.
///
/// Dipakai untuk memberi tahu user "mundur, badanmu belum masuk frame" alih-alih
/// diam saja sambil tidak menghitung apa-apa.
bool bodyVisible(Pose pose) {
  const inti = [
    PoseLandmarkType.leftShoulder,
    PoseLandmarkType.rightShoulder,
    PoseLandmarkType.leftHip,
    PoseLandmarkType.rightHip,
  ];

  var terlihat = 0;
  for (final type in inti) {
    final landmark = pose.landmarks[type];
    if (landmark != null && landmark.likelihood >= kMinLikelihood) terlihat++;
  }
  // Cukup satu bahu dan satu pinggul: saat difoto dari samping, sisi yang jauh
  // memang wajar tidak terlihat.
  return terlihat >= 2;
}

/// Ruas tubuh yang digambar sebagai kerangka di atas preview kamera.
const List<List<PoseLandmarkType>> kSkeletonBones = [
  [PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder],
  [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow],
  [PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist],
  [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow],
  [PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist],
  [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip],
  [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip],
  [PoseLandmarkType.leftHip, PoseLandmarkType.rightHip],
  [PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee],
  [PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle],
  [PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee],
  [PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle],
];
