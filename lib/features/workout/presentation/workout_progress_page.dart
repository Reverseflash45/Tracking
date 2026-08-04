import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/hero_header.dart';
import '../../../core/widgets/section_header.dart';
import '../domain/exercise_progress.dart';
import '../domain/progressive_overload.dart';
import 'overload_suggestion_view.dart';
import 'workout_providers.dart';

const _workoutColor = AppColors.workout;
final _numberFormat = NumberFormat.decimalPattern('id_ID');
final _pointDateFormat = DateFormat('d MMM y', 'id_ID');
final _shortDateFormat = DateFormat('d MMM', 'id_ID');

String _trimNumber(double value) =>
    value == value.roundToDouble() ? value.round().toString() : value.toStringAsFixed(1);

class WorkoutProgressPage extends ConsumerStatefulWidget {
  const WorkoutProgressPage({super.key});

  @override
  ConsumerState<WorkoutProgressPage> createState() => _WorkoutProgressPageState();
}

class _WorkoutProgressPageState extends ConsumerState<WorkoutProgressPage> {
  /// null = mode "Semua".
  String? _selectedKey;

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(exerciseProgressProvider).value ?? const <ExerciseProgress>[];

    ExerciseProgress? selected;
    if (_selectedKey != null) {
      for (final progress in all) {
        if (progress.name.toLowerCase() == _selectedKey) {
          selected = progress;
          break;
        }
      }
      // Latihan yang dipilih bisa hilang setelah sesinya dihapus.
      if (selected == null) _selectedKey = null;
    }

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _buildHero(all, selected),
          if (all.isEmpty)
            const EmptyState(
              icon: Icons.show_chart,
              title: 'Belum ada data latihan',
              subtitle: 'Catat sesi workout dulu untuk melihat perkembanganmu',
              color: _workoutColor,
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionHeader(
                    title: 'Pilih Latihan',
                    icon: Icons.fitness_center,
                    color: _workoutColor,
                    trailing: Text(
                      '${all.length} latihan',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ChoiceChip(
                          label: const Text('Semua'),
                          avatar: Icon(
                            Icons.grid_view,
                            size: 15,
                            color: _selectedKey == null
                                ? _workoutColor
                                : Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          selected: _selectedKey == null,
                          onSelected: (_) => setState(() => _selectedKey = null),
                          selectedColor: _workoutColor.withValues(alpha: 0.18),
                          labelStyle: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: _selectedKey == null
                                ? _workoutColor
                                : Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        for (final progress in all) ...[
                          const SizedBox(width: AppSpacing.sm),
                          ChoiceChip(
                            label: Text(progress.name),
                            selected: _selectedKey == progress.name.toLowerCase(),
                            onSelected: (_) => setState(
                              () => _selectedKey = progress.name.toLowerCase(),
                            ),
                            selectedColor: _workoutColor.withValues(alpha: 0.18),
                            labelStyle: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: _selectedKey == progress.name.toLowerCase()
                                  ? _workoutColor
                                  : Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (selected == null)
                    _AllExercisesView(
                      items: all,
                      onTap: (progress) => setState(
                        () => _selectedKey = progress.name.toLowerCase(),
                      ),
                    )
                  else
                    _DetailView(progress: selected),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHero(List<ExerciseProgress> all, ExerciseProgress? selected) {
    final leading = HeroIconButton(
      icon: Icons.arrow_back,
      tooltip: 'Kembali',
      onPressed: () {
        // Dari detail, tombol kembali pulang dulu ke daftar "Semua".
        if (_selectedKey != null) {
          setState(() => _selectedKey = null);
        } else {
          context.pop();
        }
      },
    );

    if (selected != null) {
      return HeroHeader.sub(
        title: selected.name,
        subtitle: '${selected.type.label} - progres ${selected.metric.label.toLowerCase()}',
        color: _workoutColor,
        leading: leading,
        stats: [
          HeroStatData(
            icon: Icons.emoji_events_outlined,
            value: '${_trimNumber(selected.best)} ${selected.metric.unit}',
            label: 'Terbaik',
          ),
          HeroStatData(
            icon: Icons.timeline,
            // "3 x 10" kalau setnya tercatat, angka tunggal kalau tidak.
            value: selected.points.last.ringkasSetRep ?? _trimNumber(selected.latest),
            label: 'Terakhir',
          ),
          if (selected.metrikBeban case final beban? when selected.punyaBeban)
            HeroStatData(
              icon: Icons.bar_chart,
              value: _trimNumber(selected.bebanTerakhir!),
              label: beban.label,
            )
          else
            HeroStatData(
              icon: Icons.history,
              value: '${selected.sessionCount}',
              label: 'Sesi Tercatat',
            ),
        ],
      );
    }

    final totalSesi = all.fold<int>(0, (sum, p) => sum + p.sessionCount);
    final naik = all.where((p) => p.delta > 0).length;

    return HeroHeader.sub(
      title: 'Progress Latihan',
      subtitle: 'Perkembangan semua latihanmu',
      color: _workoutColor,
      leading: leading,
      stats: [
        HeroStatData(
          icon: Icons.fitness_center,
          value: '${all.length}',
          label: 'Jenis Latihan',
        ),
        HeroStatData(icon: Icons.history, value: '$totalSesi', label: 'Total Catatan'),
        HeroStatData(icon: Icons.trending_up, value: '$naik', label: 'Sedang Naik'),
      ],
    );
  }
}

/// Daftar ringkas semua latihan: satu baris per latihan dengan sparkline dan
/// selisih dari catatan pertama.
class _AllExercisesView extends StatelessWidget {
  const _AllExercisesView({required this.items, required this.onTap});

  final List<ExerciseProgress> items;
  final ValueChanged<ExerciseProgress> onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Semua Latihan',
          icon: Icons.list_alt,
          color: _workoutColor,
        ),
        for (final progress in items)
          _SummaryCard(progress: progress, onTap: () => onTap(progress)),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.progress, required this.onTap});

  final ExerciseProgress progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final delta = progress.delta;
    final warna = delta > 0
        ? AppColors.statusDone
        : (delta < 0 ? AppColors.priorityHigh : colorScheme.onSurfaceVariant);

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            progress.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _workoutColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            progress.type.label,
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: _workoutColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      // Set ikut ditulis di sini. Tanpa ini, "10 rep" pada 3 set
                      // dan pada 5 set terbaca persis sama.
                      '${progress.points.last.ringkasSetRep ?? _trimNumber(progress.latest)}'
                      ' ${progress.metric.unit}'
                      '  ·  ${progress.sessionCount} sesi'
                      '  ·  ${_shortDateFormat.format(progress.lastDate)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          delta > 0
                              ? Icons.trending_up
                              : (delta < 0 ? Icons.trending_down : Icons.trending_flat),
                          size: 14,
                          color: warna,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          progress.sessionCount < 2
                              ? 'Baru 1 sesi'
                              : '${delta > 0 ? "+" : ""}${_trimNumber(delta)} '
                                  '${progress.metric.unit} sejak awal',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: warna,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              SizedBox(
                width: 64,
                height: 34,
                child: _Sparkline(
                  values: [for (final p in progress.points) p.value],
                  color: warna,
                ),
              ),
              Icon(Icons.chevron_right, size: 20, color: colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

/// Grafik mini tanpa sumbu, cukup untuk melihat arah tren sekilas.
class _Sparkline extends StatelessWidget {
  const _Sparkline({required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (values.length < 2) {
      return Center(
        child: Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      );
    }
    return CustomPaint(painter: _SparklinePainter(values: values, color: color));
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final min = values.reduce((a, b) => a < b ? a : b);
    final max = values.reduce((a, b) => a > b ? a : b);
    // Garis datar digambar di tengah, bukan menempel di tepi bawah.
    final range = (max - min).abs() < 0.0001 ? 1.0 : max - min;

    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = size.width * (i / (values.length - 1));
      final y = size.height - ((values[i] - min) / range) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_SparklinePainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.color != color;
}

class _DetailView extends ConsumerWidget {
  const _DetailView({required this.progress});

  final ExerciseProgress progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final OverloadSuggestion? suggestion =
        ref.watch(overloadSuggestionsProvider).value?[progress.name.toLowerCase()];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (progress.sessionCount >= 2)
          _DeltaBanner(delta: progress.delta, metric: progress.metric),
        if (suggestion != null) ...[
          const SectionHeader(
            title: 'Target Sesi Berikutnya',
            icon: Icons.flag_outlined,
            color: _workoutColor,
          ),
          OverloadCard(suggestion: suggestion),
          const SizedBox(height: AppSpacing.lg),
        ],
        SectionHeader(
          title: '${progress.metric.label} (${progress.metric.unit})',
          icon: _metricIcon(progress.metric),
          color: _workoutColor,
        ),
        if (progress.sessionCount < 2)
          _SingleSessionNote(progress: progress)
        else
          _ChartCard(points: progress.points, useVolume: false, metric: progress.metric),
        // Grafik kedua: berapa banyak kerjanya, bukan seberapa berat satu
        // repetisinya. Dulu ini cuma muncul untuk latihan berbeban, karena
        // rumusnya beban x set x rep — dan untuk bodyweight bebannya nol, jadi
        // hasilnya selalu nol dan grafiknya tidak pernah tampil. Sekarang tiap
        // tipe punya ukuran kerjanya sendiri: total rep untuk bodyweight, total
        // detik tahanan untuk isometrik, kilogram untuk beban.
        if (progress.metrikBeban case final beban? when progress.punyaBeban) ...[
          const SizedBox(height: AppSpacing.lg),
          SectionHeader(
            title: '${beban.label} (${beban.unit})',
            icon: Icons.bar_chart,
            color: _workoutColor,
          ),
          _ChartCard(
            points: progress.titikBeban,
            useVolume: true,
            metric: progress.metric,
          ),
          if (progress.titikBeban.length < progress.sessionCount)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                '${progress.sessionCount - progress.titikBeban.length} catatan lama '
                'tidak ikut karena setnya belum diisi',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ],
    );
  }

  static IconData _metricIcon(ProgressMetric metric) => switch (metric) {
        ProgressMetric.beban => Icons.monitor_weight_outlined,
        ProgressMetric.rep => Icons.repeat,
        ProgressMetric.tahanan => Icons.timer_outlined,
        ProgressMetric.durasi => Icons.timelapse,
      };
}

/// Satu titik tidak membentuk garis, jadi tampilkan angkanya saja.
class _SingleSessionNote extends StatelessWidget {
  const _SingleSessionNote({required this.progress});

  final ExerciseProgress progress;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _workoutColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.timeline, size: 20, color: _workoutColor),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${_trimNumber(progress.latest)} ${progress.metric.unit}',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Baru satu sesi (${_pointDateFormat.format(progress.lastDate)}). '
                    'Catat sekali lagi untuk melihat grafiknya.',
                    style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
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

/// Ringkasan naik/turun dari sesi pertama ke sesi terakhir.
class _DeltaBanner extends StatelessWidget {
  const _DeltaBanner({required this.delta, required this.metric});

  final double delta;
  final ProgressMetric metric;

  @override
  Widget build(BuildContext context) {
    final naik = delta > 0;
    final turun = delta < 0;
    final color = naik
        ? AppColors.statusDone
        : (turun ? AppColors.priorityHigh : Theme.of(context).colorScheme.onSurfaceVariant);
    final icon = naik
        ? Icons.trending_up
        : (turun ? Icons.trending_down : Icons.trending_flat);
    final label = naik
        ? 'Naik ${_trimNumber(delta)} ${metric.unit} sejak sesi pertama'
        : (turun
            ? 'Turun ${_trimNumber(-delta)} ${metric.unit} sejak sesi pertama'
            : '${metric.label} stabil sejak sesi pertama');

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontWeight: FontWeight.w600, color: color, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.points,
    required this.useVolume,
    required this.metric,
  });

  final List<ProgressPoint> points;
  final bool useVolume;
  final ProgressMetric metric;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.sm,
        ),
        child: SizedBox(
          height: 190,
          child: _LineChart(points: points, useVolume: useVolume, metric: metric),
        ),
      ),
    );
  }
}

class _LineChart extends StatelessWidget {
  const _LineChart({
    required this.points,
    required this.useVolume,
    required this.metric,
  });

  final List<ProgressPoint> points;
  final bool useVolume;
  final ProgressMetric metric;

  /// Saat menggambar kerja total, angkanya diambil dari [ProgressPoint.bebanKerja]
  /// — bukan dari `volume`, yang rumusnya beban x set x rep dan karenanya selalu
  /// nol untuk latihan tanpa beban.
  double _valueOf(ProgressPoint point) =>
      useVolume ? (point.bebanKerja ?? point.volume) : point.value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final spots = <FlSpot>[
      for (var i = 0; i < points.length; i++) FlSpot(i.toDouble(), _valueOf(points[i])),
    ];

    final values = points.map(_valueOf).toList();
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final minValue = values.reduce((a, b) => a < b ? a : b);
    // Beri ruang di atas & bawah supaya garisnya tidak menempel tepi kartu.
    final padding = ((maxValue - minValue).abs() * 0.2).clamp(1.0, double.infinity);

    // Label sumbu X dibatasi supaya tidak tumpang tindih saat titiknya banyak.
    final labelInterval = (points.length / 4).ceil().toDouble().clamp(1.0, double.infinity);
    final satuan = useVolume ? '' : ' ${metric.unit}';

    return LineChart(
      LineChartData(
        minY: (minValue - padding).clamp(0, double.infinity),
        maxY: maxValue + padding,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: colorScheme.outlineVariant.withValues(alpha: 0.4),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: labelInterval,
              reservedSize: 26,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= points.length) return const SizedBox.shrink();
                final date = points[index].date;
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '${date.day}/${date.month}',
                    style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 42,
              getTitlesWidget: (value, meta) => Text(
                _numberFormat.format(value.round()),
                style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant),
              ),
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => _workoutColor,
            getTooltipItems: (touchedSpots) => touchedSpots.map((spot) {
              final point = points[spot.x.toInt()];
              return LineTooltipItem(
                '${_numberFormat.format(_valueOf(point))}$satuan\n',
                const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                children: [
                  TextSpan(
                    text: _pointDateFormat.format(point.date),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w400,
                      fontSize: 11,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.25,
            barWidth: 3,
            color: _workoutColor,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                radius: 3.5,
                color: Colors.white,
                strokeWidth: 2,
                strokeColor: _workoutColor,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  _workoutColor.withValues(alpha: 0.28),
                  _workoutColor.withValues(alpha: 0.02),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
