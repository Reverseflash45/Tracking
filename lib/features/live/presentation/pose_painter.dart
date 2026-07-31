import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/pose_geometry.dart';

/// Menggambar kerangka tubuh di atas preview kamera.
///
/// Titik dengan keyakinan rendah tidak digambar sama sekali. Menggambarnya
/// dengan warna pudar terdengar informatif, tapi hasilnya garis yang menjulur
/// ke tempat acak dan membuat user mengira deteksinya rusak.
class PosePainter extends CustomPainter {
  PosePainter({
    required this.pose,
    required this.imageSize,
    required this.mirror,
    this.warning = false,
  });

  final Pose? pose;

  /// Ukuran gambar yang dianalisis, sesudah rotasi. Dipakai untuk memetakan
  /// koordinat titik ke ukuran kanvas.
  final Size imageSize;

  /// True untuk kamera depan, yang previewnya ditampilkan seperti cermin.
  final bool mirror;

  /// Mewarnai kerangka saat ada peringatan postur yang aktif.
  final bool warning;

  @override
  void paint(Canvas canvas, Size size) {
    final pose = this.pose;
    if (pose == null || imageSize.isEmpty) return;

    final color = warning ? AppColors.priorityHigh : AppColors.workout;

    final bonePaint = Paint()
      ..color = color
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final jointPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // Preview memakai BoxFit.cover, jadi skalanya mengikuti sisi terpanjang
    // dan sisi lainnya terpotong rata di kedua ujung.
    final scale = (size.width / imageSize.width) > (size.height / imageSize.height)
        ? size.width / imageSize.width
        : size.height / imageSize.height;
    final dx = (size.width - imageSize.width * scale) / 2;
    final dy = (size.height - imageSize.height * scale) / 2;

    Offset? project(PoseLandmarkType type) {
      final landmark = pose.landmarks[type];
      if (landmark == null || landmark.likelihood < kMinLikelihood) return null;

      final x = mirror ? imageSize.width - landmark.x : landmark.x;
      return Offset(x * scale + dx, landmark.y * scale + dy);
    }

    for (final bone in kSkeletonBones) {
      final start = project(bone.first);
      final end = project(bone.last);
      if (start == null || end == null) continue;
      canvas.drawLine(start, end, bonePaint);
    }

    for (final type in pose.landmarks.keys) {
      final point = project(type);
      if (point == null) continue;
      canvas.drawCircle(point, 4, jointPaint);
    }
  }

  @override
  bool shouldRepaint(PosePainter oldDelegate) {
    return oldDelegate.pose != pose ||
        oldDelegate.warning != warning ||
        oldDelegate.imageSize != imageSize;
  }
}
