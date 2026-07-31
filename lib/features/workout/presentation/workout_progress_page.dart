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
import 'workout_providers.dart';

const _workoutColor = AppColors.workout;
final _numberFormat = NumberFormat.decimalPattern('id_ID');
final _pointDateFormat = DateFormat('d MMM y', 'id_ID');

class WorkoutProgressPage extends ConsumerStatefulWidget {
  const WorkoutProgressPage({super.key});

  @override
  ConsumerState<WorkoutProgressPage> createState() => _WorkoutProgressPageState();
}

class _WorkoutProgressPageState extends ConsumerState<WorkoutProgressPage> {
  String? _selectedExercise;

  @override
  Widget build(BuildContext context) {
    final names = ref.watch(exerciseNamesProvider).value ?? const <String>[];
    final sessions = ref.watch(workoutSessionsProvider).value;

    if (names.isNotEmpty && !names.contains(_selectedExercise)) {
      _selectedExercise = names.first;
    }

    final points = <_ProgressPoint>[];
    if (sessions != null && _selectedExercise != null) {
      for (final session in sessions) {
        for (final exercise in session.exercises) {
          if (exercise.exerciseName == _selectedExercise && !exercise.isCardio) {
            points.add(_ProgressPoint(
              date: session.sessionDate,
              weight: exercise.weightKg ?? 0,
              volume: exercise.volume,
            ));
          }
        }
      }
      points.sort((a, b) => a.date.compareTo(b.date));
    }

    final maxWeight = points.isEmpty
        ? 0.0
        : points.map((p) => p.weight).reduce((a, b) => a > b ? a : b);
    final maxVolume = points.isEmpty
        ? 0.0
        : points.map((p) => p.volume).reduce((a, b) => a > b ? a : b);
    final delta = points.length < 2 ? 0.0 : points.last.weight - points.first.weight;

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          HeroHeader(
            title: 'Progress Latihan',
            subtitle: _selectedExercise ?? 'Perkembangan beban dan volume',
            color: _workoutColor,
            leading: HeroIconButton(
              icon: Icons.arrow_back,
              tooltip: 'Kembali',
              onPressed: () => context.pop(),
            ),
            stats: [
              HeroStatData(
                icon: Icons.monitor_weight_outlined,
                value: '${_numberFormat.format(maxWeight)} kg',
                label: 'Beban Terberat',
              ),
              HeroStatData(
                icon: Icons.bar_chart,
                value: _numberFormat.format(maxVolume.round()),
                label: 'Volume Terbaik',
              ),
              HeroStatData(
                icon: Icons.history,
                value: '${points.length}',
                label: 'Sesi Tercatat',
              ),
            ],
          ),
          if (names.isEmpty)
            const EmptyState(
              icon: Icons.show_chart,
              title: 'Belum ada data latihan beban',
              subtitle: 'Catat sesi workout dengan berat, set, dan rep untuk melihat grafik',
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
                  const SectionHeader(
                    title: 'Pilih Latihan',
                    icon: Icons.fitness_center,
                    color: _workoutColor,
                  ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final name in names) ...[
                          if (name != names.first) const SizedBox(width: AppSpacing.sm),
                          ChoiceChip(
                            label: Text(name),
                            selected: _selectedExercise == name,
                            onSelected: (_) => setState(() => _selectedExercise = name),
                            selectedColor: _workoutColor.withValues(alpha: 0.18),
                            labelStyle: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: _selectedExercise == name
                                  ? _workoutColor
                                  : Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (points.isEmpty)
                    const EmptyState(
                      icon: Icons.query_stats,
                      title: 'Belum ada data untuk latihan ini',
                      color: _workoutColor,
                    )
                  else ...[
                    if (points.length >= 2) _DeltaBanner(delta: delta),
                    const SectionHeader(
                      title: 'Beban (kg)',
                      icon: Icons.monitor_weight_outlined,
                      color: _workoutColor,
                    ),
                    _ChartCard(points: points, useVolume: false),
                    const SizedBox(height: AppSpacing.lg),
                    const SectionHeader(
                      title: 'Volume Latihan',
                      icon: Icons.bar_chart,
                      color: _workoutColor,
                    ),
                    _ChartCard(points: points, useVolume: true),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ProgressPoint {
  _ProgressPoint({required this.date, required this.weight, required this.volume});

  final DateTime date;
  final double weight;
  final double volume;
}

/// Ringkasan naik/turun beban dari sesi pertama ke sesi terakhir.
class _DeltaBanner extends StatelessWidget {
  const _DeltaBanner({required this.delta});

  final double delta;

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
        ? 'Naik ${_numberFormat.format(delta)} kg sejak sesi pertama'
        : (turun
            ? 'Turun ${_numberFormat.format(-delta)} kg sejak sesi pertama'
            : 'Beban stabil sejak sesi pertama');

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
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
  const _ChartCard({required this.points, required this.useVolume});

  final List<_ProgressPoint> points;
  final bool useVolume;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.lg, AppSpacing.md, AppSpacing.sm),
        child: SizedBox(
          height: 190,
          child: _LineChart(points: points, useVolume: useVolume),
        ),
      ),
    );
  }
}

class _LineChart extends StatelessWidget {
  const _LineChart({required this.points, required this.useVolume});

  final List<_ProgressPoint> points;
  final bool useVolume;

  double _valueOf(_ProgressPoint point) => useVolume ? point.volume : point.weight;

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
                '${_numberFormat.format(_valueOf(point))}${useVolume ? '' : ' kg'}\n',
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
