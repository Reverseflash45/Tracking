import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/finance_stats.dart';
import '../domain/transaction.dart';

/// Warna tetap per kategori, dipakai di donat, legenda, dan ikon riwayat —
/// "Makan" selalu oranye di mana pun ia muncul.
Color warnaKategori(TxCategory c) => switch (c) {
  TxCategory.makan => const Color(0xFFEF8A3C),
  TxCategory.transport => const Color(0xFF3F8FD1),
  TxCategory.kuliah => const Color(0xFF7C62D6),
  TxCategory.belanja => const Color(0xFFD9669B),
  TxCategory.hiburan => const Color(0xFFB45BD6),
  TxCategory.kesehatan => const Color(0xFFE0555A),
  TxCategory.pulsa => const Color(0xFF1E9E8C),
  TxCategory.lainnya => const Color(0xFF8A909A),
  _ => AppColors.finance,
};

DateTime _tgl(DateTime d) => DateTime(d.year, d.month, d.day);

/// Batang pengeluaran per hari sepanjang periode anggaran, dengan garis
/// putus-putus di jatah rata-rata. Hari yang melewati jatah berwarna koral,
/// jadi pola "boros tiap akhir pekan" kelihatan tanpa membaca angka.
class GrafikPengeluaranHarian extends StatefulWidget {
  const GrafikPengeluaranHarian({
    super.key,
    required this.transaksi,
    required this.mulai,
    required this.akhir,
    this.anggaran,
  });

  final List<Transaction> transaksi;
  final DateTime mulai;
  final DateTime akhir;
  final double? anggaran;

  @override
  State<GrafikPengeluaranHarian> createState() => _GrafikPengeluaranHarianState();
}

class _GrafikPengeluaranHarianState extends State<GrafikPengeluaranHarian> {
  /// Batang yang sedang diketuk. Null berarti menampilkan rata-rata.
  int? _pilih;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final transaksi = widget.transaksi;
    final anggaran = widget.anggaran;
    final akhir = widget.akhir;
    final awal = _tgl(widget.mulai);
    final jumlahHari = _tgl(akhir).difference(awal).inDays + 1;
    if (jumlahHari <= 0 || jumlahHari > 62) return const SizedBox.shrink();

    final perHari = List<double>.filled(jumlahHari, 0);
    for (final t in transaksi) {
      if (t.kind != TxKind.pengeluaran) continue;
      final i = _tgl(t.occurredOn).difference(awal).inDays;
      if (i >= 0 && i < jumlahHari) perHari[i] += t.amount;
    }
    final hariIni = _tgl(DateTime.now()).difference(awal).inDays;
    final jatah = (anggaran != null && anggaran > 0) ? anggaran / jumlahHari : null;
    final terisi = perHari.take(math.min(hariIni + 1, jumlahHari)).toList();
    final rataRata = terisi.isEmpty ? 0.0 : terisi.reduce((a, b) => a + b) / terisi.length;
    // Skala dipatok supaya satu hari yang luar biasa (bayar kos, beli
    // sepatu) tidak memipihkan semua batang lain. Batang yang melewatinya
    // digambar penuh dengan tanda patah di ujungnya.
    final urut = [...perHari]..sort();
    final tertinggi = urut.isEmpty ? 0.0 : urut.last;
    final keduaTertinggi = urut.length > 1 ? urut[urut.length - 2] : tertinggi;
    final puncak = math
        .min(tertinggi, math.max((jatah ?? 0) * 2.5, keduaTertinggi * 1.25))
        .clamp(0.0, double.infinity)
        .toDouble();

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _pilih == null
                            ? 'Rata-rata per hari'
                            : DateFormat(
                                'EEEE, d MMM',
                                'id_ID',
                              ).format(awal.add(Duration(days: _pilih!))),
                        style: TextStyle(fontSize: 12.5, color: colorScheme.onSurfaceVariant),
                      ),
                      Text(
                        formatRupiah(_pilih == null ? rataRata : perHari[_pilih!]),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
                if (jatah != null)
                  Row(
                    children: [
                      CustomPaint(
                        size: const Size(18, 2),
                        painter: _GarisPutus(colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Jatah ${formatRupiahRingkas(jatah)}',
                        style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 120,
              child: puncak <= 0
                  ? Center(
                      child: Text(
                        'Belum ada pengeluaran periode ini',
                        style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, c) => GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        // Ketuk batang untuk melihat angka hari itu; ketuk
                        // lagi untuk kembali ke rata-rata.
                        onTapDown: (d) {
                          final i = (d.localPosition.dx / c.maxWidth * jumlahHari).floor().clamp(
                            0,
                            jumlahHari - 1,
                          );
                          setState(() => _pilih = (_pilih == i || i > hariIni) ? null : i);
                        },
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: 1),
                          duration: const Duration(milliseconds: 700),
                          curve: Curves.easeOutCubic,
                          builder: (context, t, _) => CustomPaint(
                            size: Size.infinite,
                            painter: _LukisBatang(
                              nilai: perHari,
                              puncak: puncak,
                              jatah: jatah,
                              hariIni: _pilih ?? hariIni,
                              batasIsi: hariIni,
                              t: t,
                              aman: AppColors.finance,
                              lewat: AppColors.deadline,
                              kosong: colorScheme.surfaceContainerHigh,
                              garis: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  '${awal.day}/${awal.month}',
                  style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                ),
                const Spacer(),
                Text(
                  '${_tgl(akhir).day}/${_tgl(akhir).month}',
                  style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LukisBatang extends CustomPainter {
  _LukisBatang({
    required this.nilai,
    required this.puncak,
    required this.jatah,
    required this.hariIni,
    required this.batasIsi,
    required this.t,
    required this.aman,
    required this.lewat,
    required this.kosong,
    required this.garis,
  });

  final List<double> nilai;
  final double puncak;
  final double? jatah;

  /// Batang yang digambar paling pekat (hari ini, atau yang diketuk).
  final int hariIni;

  /// Indeks hari ini: batang sesudahnya belum terjadi.
  final int batasIsi;
  final double t;
  final Color aman;
  final Color lewat;
  final Color kosong;
  final Color garis;

  @override
  void paint(Canvas canvas, Size size) {
    final n = nilai.length;
    final celah = n > 20 ? 3.0 : 5.0;
    final lebar = (size.width - celah * (n - 1)) / n;
    final r = Radius.circular(math.min(4, lebar / 2));

    for (var i = 0; i < n; i++) {
      final x = i * (lebar + celah);
      final nanti = i > batasIsi;
      final v = nilai[i];
      if (v <= 0 || nanti) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(x, size.height - 4, lebar, 4), r),
          Paint()..color = kosong.withValues(alpha: nanti ? 0.5 : 1),
        );
        continue;
      }
      final patah = v > puncak;
      final h = math.max(4.0, math.min(v, puncak) / puncak * size.height * t);
      final warna = (jatah != null && v > jatah!) ? lewat : aman;
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(x, size.height - h, lebar, h),
          topLeft: r,
          topRight: r,
        ),
        Paint()..color = i == hariIni ? warna : warna.withValues(alpha: 0.75),
      );
      if (patah && t > 0.95) {
        // Dua garis miring putih: "batang ini sebenarnya lebih tinggi".
        final pena = Paint()
          ..color = Colors.white
          ..strokeWidth = 2;
        for (final dy in [10.0, 16.0]) {
          canvas.drawLine(
            Offset(x - 1, size.height - h + dy + 3),
            Offset(x + lebar + 1, size.height - h + dy - 3),
            pena,
          );
        }
      }
    }

    if (jatah != null && jatah! <= puncak) {
      final y = size.height - jatah! / puncak * size.height;
      final cat = Paint()
        ..color = garis
        ..strokeWidth = 1.2;
      for (double x = 0; x < size.width; x += 7) {
        canvas.drawLine(Offset(x, y), Offset(math.min(x + 4, size.width), y), cat);
      }
    }
  }

  @override
  bool shouldRepaint(_LukisBatang old) =>
      old.t != t || old.nilai != nilai || old.hariIni != hariIni;
}

class _GarisPutus extends CustomPainter {
  _GarisPutus(this.warna);

  final Color warna;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = warna
      ..strokeWidth = 1.5;
    for (double x = 0; x < size.width; x += 6) {
      canvas.drawLine(Offset(x, size.height / 2), Offset(x + 3.5, size.height / 2), p);
    }
  }

  @override
  bool shouldRepaint(_GarisPutus old) => old.warna != warna;
}

/// Donat pembagian pengeluaran per kategori plus legenda berpersentase.
class DonatKategori extends StatelessWidget {
  const DonatKategori({super.key, required this.summary});

  final FinanceSummary summary;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final total = summary.perKategori.fold<double>(0, (a, c) => a + c.total);
    if (total <= 0) return const SizedBox.shrink();

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox.square(
              dimension: 128,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOutCubic,
                    builder: (context, t, _) => CustomPaint(
                      painter: _LukisDonat(
                        bagian: [
                          for (final c in summary.perKategori)
                            (c.total / total, warnaKategori(c.category)),
                        ],
                        t: t,
                      ),
                    ),
                  ),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Total',
                          style: TextStyle(fontSize: 11.5, color: colorScheme.onSurfaceVariant),
                        ),
                        Text(
                          formatRupiahRingkas(total),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                children: [
                  for (final c in summary.perKategori.take(6))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: warnaKategori(c.category),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              c.category.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          ),
                          Text(
                            '${(c.total / total * 100).round()}%',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: colorScheme.onSurfaceVariant,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (summary.perKategori.length > 6)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '+${summary.perKategori.length - 6} kategori lain',
                        style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LukisDonat extends CustomPainter {
  _LukisDonat({required this.bagian, required this.t});

  final List<(double, Color)> bagian;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    const tebal = 18.0;
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: size.shortestSide / 2 - tebal / 2,
    );
    const celah = 0.04;
    var sudut = -math.pi / 2;
    final totalSudut = 2 * math.pi * t;
    for (final (porsi, warna) in bagian) {
      final sapuan = porsi * totalSudut;
      final gambar = math.max(0.0, sapuan - (bagian.length > 1 ? celah : 0));
      if (gambar > 0) {
        canvas.drawArc(
          rect,
          sudut,
          gambar,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = tebal
            ..strokeCap = StrokeCap.butt
            ..color = warna,
        );
      }
      sudut += sapuan;
    }
  }

  @override
  bool shouldRepaint(_LukisDonat old) => old.t != t || old.bagian != bagian;
}
