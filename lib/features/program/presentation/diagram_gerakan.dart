import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/pose_gerakan.dart';

/// Menggambar satu pose sebagai stick figure.
///
/// Warnanya diambil dari tema saat menggambar, jadi satu definisi pose ini
/// cukup untuk tema terang maupun gelap.
class PosePainter extends CustomPainter {
  const PosePainter({
    required this.pose,
    required this.warnaBadan,
    required this.warnaBenda,
    required this.warnaBeban,
    this.tebal = 2.4,
  });

  final Pose pose;
  final Color warnaBadan;
  final Color warnaBenda;
  final Color warnaBeban;
  final double tebal;

  Offset _p(Size size, Sendi sendi) {
    final t = pose[sendi];
    return Offset(t.dx * size.width, t.dy * size.height);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final badan = Paint()
      ..color = warnaBadan
      ..strokeWidth = tebal
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final benda = Paint()
      ..color = warnaBenda
      ..strokeWidth = tebal * 0.7
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    if (pose.props.contains(Prop.lantai)) {
      final y = 0.90 * size.height;
      canvas.drawLine(Offset(size.width * 0.04, y), Offset(size.width * 0.96, y), benda);
    }

    if (pose.props.contains(Prop.kursi)) {
      _gambarKursi(canvas, size, benda);
    }

    if (pose.garisBantu case final pasangan?) {
      _gambarPutusPutus(
        canvas,
        _p(size, pasangan.$1),
        _p(size, pasangan.$2),
        Paint()
          ..color = warnaBenda
          ..strokeWidth = tebal * 0.6
          ..strokeCap = StrokeCap.round,
      );
    }

    // Badan digambar setelah benda supaya orangnya selalu di depan kursi.
    final leher = _p(size, Sendi.leher);
    final pinggul = _p(size, Sendi.pinggul);
    canvas.drawLine(leher, pinggul, badan);

    for (final (siku, tangan) in [
      (Sendi.sikuKiri, Sendi.tanganKiri),
      (Sendi.sikuKanan, Sendi.tanganKanan),
    ]) {
      canvas.drawLine(leher, _p(size, siku), badan);
      canvas.drawLine(_p(size, siku), _p(size, tangan), badan);
    }

    for (final (lutut, kaki) in [
      (Sendi.lututKiri, Sendi.kakiKiri),
      (Sendi.lututKanan, Sendi.kakiKanan),
    ]) {
      canvas.drawLine(pinggul, _p(size, lutut), badan);
      canvas.drawLine(_p(size, lutut), _p(size, kaki), badan);
    }

    final kepala = _p(size, Sendi.kepala);
    canvas.drawCircle(kepala, size.shortestSide * 0.075, badan);

    final isiBeban = Paint()..color = warnaBeban;
    if (pose.props.contains(Prop.beban)) {
      _gambarBeban(canvas, size, _p(size, Sendi.tanganKiri), isiBeban);
      _gambarBeban(canvas, size, _p(size, Sendi.tanganKanan), isiBeban);
    } else if (pose.props.contains(Prop.bebanKanan)) {
      _gambarBeban(canvas, size, _p(size, Sendi.tanganKanan), isiBeban);
    }
  }

  void _gambarKursi(Canvas canvas, Size size, Paint cat) {
    // Kursi dilihat dari samping: dudukan setinggi lutut plus dua kaki.
    final kiri = size.width * 0.06;
    final kanan = size.width * 0.40;
    final dudukan = size.height * 0.66;
    final lantai = size.height * 0.90;

    canvas.drawLine(Offset(kiri, dudukan), Offset(kanan, dudukan), cat);
    canvas.drawLine(Offset(kiri + 2, dudukan), Offset(kiri + 2, lantai), cat);
    canvas.drawLine(Offset(kanan - 2, dudukan), Offset(kanan - 2, lantai), cat);
  }

  void _gambarBeban(Canvas canvas, Size size, Offset di, Paint cat) {
    final lebar = size.shortestSide * 0.13;
    final tinggi = size.shortestSide * 0.07;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: di, width: lebar, height: tinggi),
        Radius.circular(tinggi * 0.35),
      ),
      cat,
    );
  }

  void _gambarPutusPutus(Canvas canvas, Offset dari, Offset ke, Paint cat) {
    const panjang = 5.0;
    const sela = 4.0;
    final total = (ke - dari).distance;
    if (total == 0) return;
    final arah = (ke - dari) / total;

    var jalan = 0.0;
    while (jalan < total) {
      final akhir = (jalan + panjang).clamp(0.0, total);
      canvas.drawLine(dari + arah * jalan, dari + arah * akhir, cat);
      jalan = akhir + sela;
    }
  }

  @override
  bool shouldRepaint(PosePainter oldDelegate) =>
      oldDelegate.pose != pose ||
      oldDelegate.warnaBadan != warnaBadan ||
      oldDelegate.warnaBenda != warnaBenda ||
      oldDelegate.warnaBeban != warnaBeban;
}

/// Satu pose, ukurannya mengikuti kotak yang diberikan.
class GambarPose extends StatelessWidget {
  const GambarPose({super.key, required this.pose, this.tebal = 2.4});

  final Pose pose;
  final double tebal;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return CustomPaint(
      painter: PosePainter(
        pose: pose,
        warnaBadan: colorScheme.onSurface,
        warnaBenda: colorScheme.onSurfaceVariant.withValues(alpha: 0.55),
        warnaBeban: AppColors.workout,
        tebal: tebal,
      ),
    );
  }
}

/// Ikon kecil di daftar gerakan: pose akhirnya saja.
///
/// Yang ditampilkan pose akhir, bukan awal — posisi awal hampir semua gerakan
/// adalah "berdiri", dan enam ikon orang berdiri tidak membedakan apa pun.
class IkonGerakan extends StatelessWidget {
  const IkonGerakan({super.key, required this.diagram, this.ukuran = 40});

  final DiagramGerakan diagram;
  final double ukuran;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: ukuran,
      height: ukuran,
      child: GambarPose(pose: diagram.akhir, tebal: 1.6),
    );
  }
}

/// Dua pose berdampingan dengan panah di antaranya, seperti di panduan gerakan.
class GambarGerakan extends StatelessWidget {
  const GambarGerakan({super.key, required this.diagram, this.tinggi = 150});

  final DiagramGerakan diagram;
  final double tinggi;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final sama = diagram.labelMulai == diagram.labelAkhir;

    Widget sisi(Pose pose, String label) => Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: tinggi, child: GambarPose(pose: pose)),
              const SizedBox(height: AppSpacing.xs),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        );

    // Gerakan isometrik tidak berpindah posisi, jadi menggambarnya dua kali
    // dengan panah di tengah justru berbohong: tidak ada yang bergerak.
    if (sama || _posenyaSama) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: tinggi, child: GambarPose(pose: diagram.mulai)),
          const SizedBox(height: AppSpacing.xs),
          Text(
            diagram.labelAkhir,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sisi(diagram.mulai, diagram.labelMulai),
        Padding(
          padding: EdgeInsets.only(top: tinggi / 2 - 10),
          child: Icon(
            Icons.arrow_forward,
            size: 18,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        sisi(diagram.akhir, diagram.labelAkhir),
      ],
    );
  }

  bool get _posenyaSama =>
      diagram.mulai.titik.toString() == diagram.akhir.titik.toString();
}
