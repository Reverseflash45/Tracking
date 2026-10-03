// Cincin harian: asupan, minum, dan gerak hari ini.
part of 'dashboard_page.dart';

class _DataCincin {
  const _DataCincin({
    required this.label,
    required this.nilai,
    required this.target,
    required this.satuan,
    required this.warna,
    required this.onTap,
  });

  final String label;
  final double nilai;
  final double target;
  final String satuan;
  final Color warna;
  final VoidCallback onTap;

  double get rasio => target <= 0 ? 0 : (nilai / target).clamp(0.0, 1.0);
}

/// Tiga cincin konsentris ala Apple Fitness: latihan minggu ini, asupan hari
/// ini, dan tugas minggu ini. Satu gambar yang langsung menjawab "sudah
/// seberapa jauh aku", dengan angka persisnya di samping.
class _KartuCincin extends ConsumerWidget {
  const _KartuCincin();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sekarang = DateTime.now();
    final awal = _awalMinggu(sekarang);
    final akhir = awal.add(const Duration(days: 7));

    // Latihan dihitung tujuh hari terakhir, bukan pekan kalender: di hari
    // Senin pekan kalender selalu nol padahal kamu baru latihan kemarin.
    final hariIni = DateTime(sekarang.year, sekarang.month, sekarang.day);
    final tujuhHari = hariIni.subtract(const Duration(days: 6));
    final aktif = ref.watch(activeDatesProvider);
    final hariLatihan = {
      for (final d in aktif)
        if (!DateTime(d.year, d.month, d.day).isBefore(tujuhHari) &&
            !d.isAfter(sekarang))
          DateTime(d.year, d.month, d.day),
    }.length;

    final asupan = ref.watch(todayNutritionProvider).value;
    final profil = ref.watch(bodyProfileProvider).value;
    final berat = ref.watch(currentWeightProvider).value;
    final targetKkal = (profil == null || berat == null)
        ? null
        : calculateCalories(
            profile: profil,
            weightKg: berat,
            now: sekarang,
          ).goalKcal;

    final tugas = ref.watch(tasksProvider).value ?? const <AcademicTask>[];
    final tugasMinggu = tugas
        .where(
          (t) =>
              !t.tenggatLokal.isBefore(awal) && t.tenggatLokal.isBefore(akhir),
        )
        .toList();
    final tugasBeres = tugasMinggu.where((t) => t.isDone).length;

    final cincin = [
      _DataCincin(
        label: 'Latihan · 7 hari',
        nilai: hariLatihan.toDouble(),
        target: _targetLatihanMingguan.toDouble(),
        satuan: '/$_targetLatihanMingguan hari',
        warna: AppColors.workout,
        onTap: () => _keTab(context, kTabWorkout),
      ),
      _DataCincin(
        label: 'Asupan',
        nilai: asupan?.calories ?? 0,
        target: (targetKkal ?? 2000).toDouble(),
        satuan: targetKkal == null ? ' kkal' : '/${_ribuan(targetKkal)} kkal',
        warna: _warnaAsupan,
        onTap: () => context.push('/workout/nutrition'),
      ),
      _DataCincin(
        label: 'Tugas',
        nilai: tugasBeres.toDouble(),
        target: tugasMinggu.length.toDouble(),
        satuan: '/${tugasMinggu.length} pekan ini',
        warna: AppColors.deadline,
        onTap: () => _keTab(context, kTabTugas),
      ),
    ];

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
        child: Row(
          children: [
            SizedBox.square(
              dimension: 116,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutCubic,
                builder: (context, t, _) => CustomPaint(
                  painter: _LukisCincin(cincin: cincin, t: t),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                children: [for (final c in cincin) _BarisCincin(c)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _ribuan(num n) => NumberFormat.decimalPattern('id_ID').format(n.round());

class _BarisCincin extends StatelessWidget {
  const _BarisCincin(this.c);

  final _DataCincin c;

  @override
  Widget build(BuildContext context) {
    final redup = Theme.of(context).colorScheme.onSurfaceVariant;
    return InkWell(
      onTap: c.onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 30,
              decoration: BoxDecoration(
                color: c.warna,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.label,
                    style: TextStyle(fontSize: 12, color: redup, height: 1.2),
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: _ribuan(c.nilai),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                            ),
                          ),
                          TextSpan(
                            text: c.satuan,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: redup,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      style: const TextStyle(
                        height: 1.25,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
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

class _LukisCincin extends CustomPainter {
  _LukisCincin({required this.cincin, required this.t});

  final List<_DataCincin> cincin;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    const tebal = 12.0;
    const jarak = 3.5;
    final pusat = size.center(Offset.zero);
    var jari = size.shortestSide / 2 - tebal / 2;

    for (final c in cincin) {
      final kotak = Rect.fromCircle(center: pusat, radius: jari);
      final kuas = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = tebal
        ..strokeCap = StrokeCap.round;

      canvas.drawCircle(
        pusat,
        jari,
        kuas..color = c.warna.withValues(alpha: 0.18),
      );
      final sudut = 2 * math.pi * c.rasio * t;
      if (sudut > 0) {
        canvas.drawArc(
          kotak,
          -math.pi / 2,
          sudut,
          false,
          kuas..color = c.warna,
        );
      }
      jari -= tebal + jarak;
    }
  }

  @override
  bool shouldRepaint(_LukisCincin old) => old.t != t || old.cincin != cincin;
}

// ---------------------------------------------------------------------------
// Minggu ini
// ---------------------------------------------------------------------------
