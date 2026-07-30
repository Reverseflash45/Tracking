import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'workout_providers.dart';

class WorkoutProgressPage extends ConsumerStatefulWidget {
  const WorkoutProgressPage({super.key});

  @override
  ConsumerState<WorkoutProgressPage> createState() => _WorkoutProgressPageState();
}

class _WorkoutProgressPageState extends ConsumerState<WorkoutProgressPage> {
  String? _selectedExercise;

  @override
  Widget build(BuildContext context) {
    final namesAsync = ref.watch(exerciseNamesProvider);
    final sessionsAsync = ref.watch(workoutSessionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Progress Latihan')),
      body: namesAsync.when(
        data: (names) {
          if (names.isEmpty) {
            return const Center(child: Text('Belum ada data latihan beban.'));
          }
          _selectedExercise ??= names.first;

          return sessionsAsync.when(
            data: (sessions) {
              final points = <_ProgressPoint>[];
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

              return Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: _selectedExercise,
                      decoration: const InputDecoration(labelText: 'Pilih Latihan'),
                      items: names
                          .map((name) => DropdownMenuItem(value: name, child: Text(name)))
                          .toList(),
                      onChanged: (value) => setState(() => _selectedExercise = value),
                    ),
                    const SizedBox(height: 24),
                    if (points.isEmpty)
                      const Expanded(
                        child: Center(child: Text('Belum ada data untuk latihan ini')),
                      )
                    else ...[
                      Text('Berat (kg)', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      SizedBox(height: 200, child: _LineChart(points: points, useVolume: false)),
                      const SizedBox(height: 24),
                      Text('Volume Latihan (berat × set × rep)',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      SizedBox(height: 200, child: _LineChart(points: points, useVolume: true)),
                    ],
                  ],
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => Center(child: Text('Gagal memuat: $error')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('Gagal memuat: $error')),
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

class _LineChart extends StatelessWidget {
  const _LineChart({required this.points, required this.useVolume});

  final List<_ProgressPoint> points;
  final bool useVolume;

  @override
  Widget build(BuildContext context) {
    final spots = <FlSpot>[
      for (var i = 0; i < points.length; i++)
        FlSpot(i.toDouble(), useVolume ? points[i].volume : points[i].weight),
    ];

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: true),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= points.length) return const SizedBox.shrink();
                final date = points[index].date;
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('${date.day}/${date.month}', style: const TextStyle(fontSize: 10)),
                );
              },
            ),
          ),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
        ),
        borderData: FlBorderData(show: true),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            barWidth: 3,
            dotData: const FlDotData(show: true),
            color: Theme.of(context).colorScheme.primary,
          ),
        ],
      ),
    );
  }
}
