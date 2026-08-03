import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/domain/achievements.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/hero_header.dart';
import '../../../core/widgets/section_header.dart';
import '../../academic/presentation/academic_providers.dart';
import '../../body/data/body_repository.dart';
import '../../body/domain/calorie_calculator.dart';
import '../../nutrition/data/nutrition_repository.dart';
import '../../workout/presentation/workout_providers.dart';
import '../domain/progress_stats.dart';

const _color = AppColors.dashboard;
final _numberFormat = NumberFormat.decimalPattern('id_ID');
final _dateFormat = DateFormat('d MMM', 'id_ID');

String _trim(double value) =>
    value == value.roundToDouble() ? value.round().toString() : value.toStringAsFixed(1);

class ProgressDashboardPage extends ConsumerStatefulWidget {
  const ProgressDashboardPage({super.key});

  @override
  ConsumerState<ProgressDashboardPage> createState() => _ProgressDashboardPageState();
}

class _ProgressDashboardPageState extends ConsumerState<ProgressDashboardPage> {
  StatsPeriod _period = StatsPeriod.bulan;

  @override
  Widget build(BuildContext context) {
    final weights = ref.watch(weightLogsProvider).value;
    final foods = ref.watch(foodLogsProvider).value;
    final sessions = ref.watch(workoutSessionsProvider).value;
    final profile = ref.watch(bodyProfileProvider).value;
    final currentWeight = ref.watch(currentWeightProvider).value;

    final loading = weights == null || foods == null || sessions == null;

    final stats = loading
        ? null
        : computeProgressStats(
            period: _period,
            now: DateTime.now(),
            weights: weights,
            foods: foods,
            sessions: sessions,
            targetWeightKg: profile?.targetWeightKg,
          );

    final targets = (profile == null || currentWeight == null)
        ? null
        : calculateCalories(profile: profile, weightKg: currentWeight, now: DateTime.now());

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(weightLogsProvider);
          ref.invalidate(foodLogsProvider);
          ref.invalidate(workoutSessionsProvider);
        },
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            HeroHeader.sub(
              title: 'Progres',
              subtitle: 'Perkembangan tubuh, nutrisi, dan latihanmu',
              color: _color,
              leading: HeroIconButton(
                icon: Icons.arrow_back,
                tooltip: 'Kembali',
                onPressed: () => context.pop(),
              ),
              stats: stats == null
                  ? const []
                  : [
                      HeroStatData(
                        icon: Icons.monitor_weight_outlined,
                        value: stats.weight.currentWeight == null
                            ? '-'
                            : '${_trim(stats.weight.currentWeight!)} kg',
                        label: 'Berat Kini',
                      ),
                      HeroStatData(
                        icon: Icons.fitness_center,
                        value: '${stats.workout.totalSessions}',
                        label: 'Sesi Workout',
                      ),
                      HeroStatData(
                        icon: Icons.restaurant_menu,
                        value: '${stats.nutrition.daysLogged}',
                        label: 'Hari Dicatat',
                      ),
                    ],
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SegmentedButton<StatsPeriod>(
                    segments: [
                      for (final p in StatsPeriod.values)
                        ButtonSegment(
                          value: p,
                          label: Text(p.label, style: const TextStyle(fontSize: 13)),
                        ),
                    ],
                    selected: {_period},
                    showSelectedIcon: false,
                    onSelectionChanged: (s) => setState(() => _period = s.first),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (stats!.kosong)
                    const _EmptyStats()
                  else ...[
                    _WeightSection(weight: stats.weight),
                    const SizedBox(height: AppSpacing.lg),
                    _NutritionSection(trend: stats.nutrition, targets: targets),
                    const SizedBox(height: AppSpacing.lg),
                    _WorkoutSection(trend: stats.workout),
                    const SizedBox(height: AppSpacing.lg),
                    const _AchievementSection(),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyStats extends StatelessWidget {
  const _EmptyStats();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: _color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.insights, size: 32, color: _color),
          ),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'Belum ada data di periode ini',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Catat berat badan, makanan, atau sesi workout dulu. '
            'Coba juga pilih periode yang lebih panjang.',
            textAlign: TextAlign.center,
            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _WeightSection extends StatelessWidget {
  const _WeightSection({required this.weight});

  final WeightProgress weight;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (weight.kosong) {
      return const _SectionPlaceholder(
        title: 'Berat Badan',
        icon: Icons.monitor_weight_outlined,
        message: 'Belum ada catatan berat di periode ini. '
            'Berat tercatat setiap kamu menyimpan Profil Tubuh.',
        route: '/workout/body',
        actionLabel: 'Catat Berat',
      );
    }

    final turun = weight.change < 0;
    final stabil = weight.change.abs() < 0.05;
    final warna = stabil
        ? colorScheme.onSurfaceVariant
        : (turun ? AppColors.statusDone : AppColors.priorityMedium);
    final persen = weight.targetProgressPercent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Berat Badan',
          icon: Icons.monitor_weight_outlined,
          color: _color,
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${_trim(weight.currentWeight!)} kg',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 32,
                        color: _color,
                        height: 1,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Row(
                        children: [
                          Icon(
                            stabil
                                ? Icons.trending_flat
                                : (turun ? Icons.trending_down : Icons.trending_up),
                            size: 16,
                            color: warna,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            stabil
                                ? 'stabil'
                                : '${weight.change > 0 ? "+" : ""}${_trim(weight.change)} kg',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: warna,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (weight.targetWeightKg != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Target ${_trim(weight.targetWeightKg!)} kg',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (persen != null)
                        Text(
                          '${persen.round()}% tercapai',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                  if (persen != null) ...[
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: LinearProgressIndicator(
                        value: persen / 100,
                        minHeight: 8,
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        valueColor: const AlwaysStoppedAnimation(_color),
                      ),
                    ),
                  ],
                ],
                if (weight.points.length >= 2) ...[
                  const SizedBox(height: AppSpacing.lg),
                  SizedBox(
                    height: 160,
                    child: _LineChartView(
                      points: weight.points,
                      color: _color,
                      unit: 'kg',
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Catat berat sekali lagi untuk melihat grafiknya.',
                    style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _NutritionSection extends StatelessWidget {
  const _NutritionSection({required this.trend, required this.targets});

  final NutritionTrend trend;
  final CalorieResult? targets;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (trend.kosong) {
      return const _SectionPlaceholder(
        title: 'Nutrisi',
        icon: Icons.restaurant_menu,
        message: 'Belum ada catatan makan di periode ini.',
        route: '/workout/nutrition',
        actionLabel: 'Catat Makanan',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Nutrisi',
          icon: Icons.restaurant_menu,
          color: _color,
          trailing: Text(
            'rata-rata ${trend.daysLogged} hari tercatat',
            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _AvgTile(
                      label: 'Kalori',
                      value: _numberFormat.format(trend.avgCalories.round()),
                      unit: 'kkal',
                      target: targets?.goalKcal.toDouble(),
                      actual: trend.avgCalories,
                    ),
                    _AvgTile(
                      label: 'Protein',
                      value: '${trend.avgProtein.round()}',
                      unit: 'g',
                      target: targets?.macros.proteinG.toDouble(),
                      actual: trend.avgProtein,
                    ),
                    _AvgTile(
                      label: 'Karbo',
                      value: '${trend.avgCarbs.round()}',
                      unit: 'g',
                      target: targets?.macros.carbsG.toDouble(),
                      actual: trend.avgCarbs,
                    ),
                    _AvgTile(
                      label: 'Lemak',
                      value: '${trend.avgFat.round()}',
                      unit: 'g',
                      target: targets?.macros.fatG.toDouble(),
                      actual: trend.avgFat,
                    ),
                  ],
                ),
                if (trend.calories.length >= 2) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Kalori harian',
                    style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SizedBox(
                    height: 160,
                    child: _LineChartView(
                      points: trend.calories,
                      color: AppColors.deadline,
                      unit: 'kkal',
                      targetLine: targets?.goalKcal.toDouble(),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AvgTile extends StatelessWidget {
  const _AvgTile({
    required this.label,
    required this.value,
    required this.unit,
    required this.target,
    required this.actual,
  });

  final String label;
  final String value;
  final String unit;
  final double? target;
  final double actual;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // Dianggap "pas" kalau dalam rentang 90-110% target.
    final rasio = (target == null || target! <= 0) ? null : actual / target!;
    final warna = rasio == null
        ? colorScheme.onSurface
        : (rasio >= 0.9 && rasio <= 1.1
            ? AppColors.statusDone
            : (rasio < 0.9 ? AppColors.priorityMedium : AppColors.priorityHigh));

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant)),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: warna),
          ),
          Text(unit, style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _WorkoutSection extends StatelessWidget {
  const _WorkoutSection({required this.trend});

  final WorkoutTrend trend;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (trend.kosong) {
      return const _SectionPlaceholder(
        title: 'Latihan',
        icon: Icons.fitness_center,
        message: 'Belum ada sesi workout di periode ini.',
        route: '/workout/new',
        actionLabel: 'Catat Sesi',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Latihan',
          icon: Icons.fitness_center,
          color: _color,
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _AvgTile(
                      label: 'Sesi',
                      value: '${trend.totalSessions}',
                      unit: 'kali',
                      target: null,
                      actual: 0,
                    ),
                    _AvgTile(
                      label: 'Total Set',
                      value: _numberFormat.format(trend.totalSets),
                      unit: 'set',
                      target: null,
                      actual: 0,
                    ),
                    _AvgTile(
                      label: 'Total Rep',
                      value: _numberFormat.format(trend.totalReps),
                      unit: 'rep',
                      target: null,
                      actual: 0,
                    ),
                    _AvgTile(
                      label: 'Volume',
                      value: _numberFormat.format(trend.totalVolume.round()),
                      unit: 'kg',
                      target: null,
                      actual: 0,
                    ),
                  ],
                ),
                if (trend.weeklySessions.length >= 2) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Sesi per minggu',
                    style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SizedBox(
                    height: 150,
                    child: _WeeklyBarChart(points: trend.weeklySessions),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Kalori terbakar tidak ditampilkan karena app ini tidak mencatat durasi '
                  'sesi maupun detak jantung — angkanya hanya akan jadi tebakan.',
                  style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AchievementSection extends ConsumerWidget {
  const _AchievementSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workoutStreak = ref.watch(workoutStreakProvider).value;
    final deadlineStreak = ref.watch(deadlineStreakProvider).value;
    final achievements = computeAchievements(
      // Hari istirahat menyambung streak, tapi bukan hari latihan — lencananya
      // dihitung dari hari yang benar-benar ada gerakannya.
      workoutStreak: workoutStreak?.activeInCurrent ?? 0,
      deadlineStreak: deadlineStreak?.current ?? 0,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Streak & Pencapaian',
          icon: Icons.emoji_events_outlined,
          color: _color,
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _AvgTile(
                      label: 'Streak Workout',
                      value: '${workoutStreak?.current ?? 0}',
                      unit: 'hari',
                      target: null,
                      actual: 0,
                    ),
                    _AvgTile(
                      label: 'Terbaik',
                      value: '${workoutStreak?.best ?? 0}',
                      unit: 'hari',
                      target: null,
                      actual: 0,
                    ),
                    _AvgTile(
                      label: 'Streak Deadline',
                      value: '${deadlineStreak?.current ?? 0}',
                      unit: 'tugas',
                      target: null,
                      actual: 0,
                    ),
                    _AvgTile(
                      label: 'Tepat Waktu',
                      value: '${(deadlineStreak?.onTimePercentage ?? 0).round()}',
                      unit: '%',
                      target: null,
                      actual: 0,
                    ),
                  ],
                ),
                if (achievements.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      for (final achievement in achievements)
                        Chip(
                          avatar: Icon(achievement.icon, size: 16, color: _color),
                          label: Text(
                            achievement.label,
                            style: const TextStyle(fontSize: 12),
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionPlaceholder extends StatelessWidget {
  const _SectionPlaceholder({
    required this.title,
    required this.icon,
    required this.message,
    required this.route,
    required this.actionLabel,
  });

  final String title;
  final IconData icon;
  final String message;
  final String route;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: title, icon: icon, color: _color),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                TextButton(
                  onPressed: () => context.push(route),
                  style: TextButton.styleFrom(foregroundColor: _color),
                  child: Text(
                    actionLabel,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _LineChartView extends StatelessWidget {
  const _LineChartView({
    required this.points,
    required this.color,
    required this.unit,
    this.targetLine,
  });

  final List<DailyPoint> points;
  final Color color;
  final String unit;

  /// Garis putus-putus sebagai pembanding, mis. target kalori harian.
  final double? targetLine;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final values = points.map((p) => p.value).toList();
    // Garis target ikut diperhitungkan supaya tidak keluar dari area grafik.
    final maxValue = [
      values.reduce((a, b) => a > b ? a : b),
      ?targetLine,
    ].reduce((a, b) => a > b ? a : b);
    final minValue = [
      values.reduce((a, b) => a < b ? a : b),
      ?targetLine,
    ].reduce((a, b) => a < b ? a : b);

    final padding = ((maxValue - minValue).abs() * 0.2).clamp(1.0, double.infinity);
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
              reservedSize: 24,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= points.length) return const SizedBox.shrink();
                final date = points[index].date;
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '${date.day}/${date.month}',
                    style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
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
                style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
              ),
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        extraLinesData: targetLine == null
            ? const ExtraLinesData()
            : ExtraLinesData(
                horizontalLines: [
                  HorizontalLine(
                    y: targetLine!,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                    strokeWidth: 1.5,
                    dashArray: [6, 4],
                  ),
                ],
              ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => color,
            getTooltipItems: (touchedSpots) => touchedSpots.map((spot) {
              final point = points[spot.x.toInt()];
              return LineTooltipItem(
                '${_numberFormat.format(point.value.round())} $unit\n',
                const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                children: [
                  TextSpan(
                    text: _dateFormat.format(point.date),
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
            spots: [
              for (var i = 0; i < points.length; i++) FlSpot(i.toDouble(), points[i].value),
            ],
            isCurved: true,
            curveSmoothness: 0.25,
            barWidth: 3,
            color: color,
            dotData: FlDotData(
              show: points.length <= 20,
              getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                radius: 3,
                color: Colors.white,
                strokeWidth: 2,
                strokeColor: color,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  color.withValues(alpha: 0.28),
                  color.withValues(alpha: 0.02),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklyBarChart extends StatelessWidget {
  const _WeeklyBarChart({required this.points});

  final List<DailyPoint> points;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final maxValue = points.map((p) => p.value).reduce((a, b) => a > b ? a : b);

    return BarChart(
      BarChartData(
        maxY: maxValue + 1,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: colorScheme.outlineVariant.withValues(alpha: 0.4),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= points.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _dateFormat.format(points[index].date),
                    style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: 1,
              getTitlesWidget: (value, meta) => Text(
                value.round().toString(),
                style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
              ),
            ),
          ),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => AppColors.workout,
            getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
              '${rod.toY.round()} sesi',
              const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < points.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: points[i].value,
                  color: AppColors.workout,
                  width: 14,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
