import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/hero_header.dart';
import '../../../core/widgets/section_header.dart';
import '../data/body_repository.dart';
import '../domain/body_profile.dart';
import '../domain/calorie_calculator.dart';

const _color = AppColors.workout;
final _numberFormat = NumberFormat.decimalPattern('id_ID');

class CaloriePage extends ConsumerStatefulWidget {
  const CaloriePage({super.key});

  @override
  ConsumerState<CaloriePage> createState() => _CaloriePageState();
}

class _CaloriePageState extends ConsumerState<CaloriePage> {
  FitnessGoal? _goalOverride;

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(bodyProfileProvider);
    final weightAsync = ref.watch(currentWeightProvider);

    final profile = profileAsync.value;
    final weight = weightAsync.value;
    final loading = profileAsync.isLoading || weightAsync.isLoading;

    final result = (profile == null || weight == null)
        ? null
        : calculateCalories(
            profile: profile,
            weightKg: weight,
            now: DateTime.now(),
            goalOverride: _goalOverride,
          );

    final goal = _goalOverride ?? profile?.goal ?? FitnessGoal.maintenance;

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          HeroHeader(
            title: 'Kalkulator Kalori',
            subtitle: result == null
                ? 'Butuh profil tubuh untuk menghitung'
                : 'BMR ${_numberFormat.format(result.bmr.round())} kkal - '
                    'TDEE ${_numberFormat.format(result.tdee.round())} kkal',
            color: _color,
            leading: HeroIconButton(
              icon: Icons.arrow_back,
              tooltip: 'Kembali',
              onPressed: () => context.pop(),
            ),
            trailing: HeroIconButton(
              icon: Icons.edit_outlined,
              tooltip: 'Ubah profil tubuh',
              onPressed: () => context.push('/workout/body'),
            ),
            stats: result == null
                ? const []
                : [
                    HeroStatData(
                      icon: Icons.monitor_weight_outlined,
                      value: '${_trim(weight!)} kg',
                      label: 'Berat Kini',
                    ),
                    HeroStatData(
                      icon: Icons.speed,
                      value: result.bmi.toStringAsFixed(1),
                      label: 'BMI',
                    ),
                    HeroStatData(
                      icon: Icons.local_fire_department,
                      value: _numberFormat.format(result.goalKcal),
                      label: 'Target Kalori',
                    ),
                  ],
          ),
          if (loading)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (result == null)
            _BelumAdaProfil(sudahAdaProfil: profile != null)
          else
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (result.targetCheck?.warning != null)
                    _WarningBanner(message: result.targetCheck!.warning!),
                  const SectionHeader(
                    title: 'Status Berat Badan',
                    icon: Icons.speed,
                    color: _color,
                  ),
                  _BmiCard(result: result),
                  const SizedBox(height: AppSpacing.lg),
                  const SectionHeader(
                    title: 'Kebutuhan Kalori',
                    icon: Icons.local_fire_department,
                    color: _color,
                  ),
                  SegmentedButton<FitnessGoal>(
                    segments: [
                      for (final g in FitnessGoal.values)
                        ButtonSegment(
                          value: g,
                          label: Text(
                            // Nama panjang tidak muat di layar HP.
                            g == FitnessGoal.recomposition ? 'Recomp' : g.label,
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                    ],
                    selected: {goal},
                    showSelectedIcon: false,
                    onSelectionChanged: (selection) =>
                        setState(() => _goalOverride = selection.first),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _KcalCard(result: result, goal: goal),
                  const SizedBox(height: AppSpacing.lg),
                  const SectionHeader(
                    title: 'Target Makro Harian',
                    icon: Icons.pie_chart_outline,
                    color: _color,
                  ),
                  _MacroCard(macros: result.macros),
                  const SizedBox(height: AppSpacing.lg),
                  const SectionHeader(
                    title: 'Target Harian Lain',
                    icon: Icons.checklist,
                    color: _color,
                  ),
                  _HabitCard(result: result),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    result.usedKatchMcArdle
                        ? 'BMR dihitung dengan rumus Katch-McArdle memakai persentase lemak tubuhmu.'
                        : 'BMR dihitung dengan rumus Mifflin-St Jeor. Isi persentase lemak tubuh '
                            'di profil untuk hasil yang lebih akurat.',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static String _trim(double value) =>
      value == value.roundToDouble() ? value.round().toString() : value.toStringAsFixed(1);
}

class _BelumAdaProfil extends StatelessWidget {
  const _BelumAdaProfil({required this.sudahAdaProfil});

  /// True kalau profilnya ada tapi berat badan belum pernah dicatat.
  final bool sudahAdaProfil;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: _color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.accessibility_new, size: 32, color: _color),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            sudahAdaProfil ? 'Berat badan belum dicatat' : 'Profil tubuh belum diisi',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Isi berat, tinggi, umur, dan tingkat aktivitas dulu supaya kalorimu bisa dihitung.',
            textAlign: TextAlign.center,
            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            onPressed: () => context.push('/workout/body'),
            style: FilledButton.styleFrom(
              backgroundColor: _color,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Isi Profil Tubuh'),
          ),
        ],
      ),
    );
  }
}

class _WarningBanner extends StatelessWidget {
  const _WarningBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    const warna = AppColors.priorityMedium;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: warna.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: warna.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: warna, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 12, height: 1.4, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class _BmiCard extends StatelessWidget {
  const _BmiCard({required this.result});

  final CalorieResult result;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final warna = switch (result.bmiCategory) {
      BmiCategory.normal => AppColors.statusDone,
      BmiCategory.kurang || BmiCategory.berlebih => AppColors.priorityMedium,
      BmiCategory.obesitas1 || BmiCategory.obesitas2 => AppColors.priorityHigh,
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  result.bmi.toStringAsFixed(1),
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 32, color: warna),
                ),
                Text('BMI', style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant)),
              ],
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: warna.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      result.bmiCategory.label,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: warna,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Memakai ambang BMI Asia-Pasifik, yang lebih rendah daripada ambang '
                    'internasional.',
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

class _KcalCard extends StatelessWidget {
  const _KcalCard({required this.result, required this.goal});

  final CalorieResult result;
  final FitnessGoal goal;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _numberFormat.format(result.goalKcal),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 34,
                    color: _color,
                    height: 1,
                  ),
                ),
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    'kkal/hari',
                    style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(goal.description, style: const TextStyle(fontSize: 12)),
            const Divider(height: AppSpacing.lg),
            for (final g in FitnessGoal.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        g.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: g == goal ? FontWeight.w800 : FontWeight.w400,
                          color: g == goal ? _color : colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Text(
                      '${_numberFormat.format(result.kcalFor(g))} kkal',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: g == goal ? FontWeight.w800 : FontWeight.w600,
                        color: g == goal ? _color : colorScheme.onSurface,
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

class _MacroCard extends StatelessWidget {
  const _MacroCard({required this.macros});

  final MacroTargets macros;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            _MacroTile(
              label: 'Protein',
              grams: macros.proteinG,
              color: AppColors.deadline,
              icon: Icons.egg_outlined,
            ),
            _MacroTile(
              label: 'Karbo',
              grams: macros.carbsG,
              color: AppColors.dashboard,
              icon: Icons.rice_bowl_outlined,
            ),
            _MacroTile(
              label: 'Lemak',
              grams: macros.fatG,
              color: AppColors.priorityMedium,
              icon: Icons.water_drop_outlined,
            ),
          ],
        ),
      ),
    );
  }
}

class _MacroTile extends StatelessWidget {
  const _MacroTile({
    required this.label,
    required this.grams,
    required this.color,
    required this.icon,
  });

  final String label;
  final int grams;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: 8),
          Text(
            '$grams g',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          Text(label, style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _HabitCard extends StatelessWidget {
  const _HabitCard({required this.result});

  final CalorieResult result;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          _HabitRow(
            icon: Icons.local_drink_outlined,
            label: 'Air minum',
            value: '${(result.waterMl / 1000).toStringAsFixed(1)} liter',
          ),
          const Divider(height: 1),
          _HabitRow(
            icon: Icons.directions_walk,
            label: 'Langkah kaki',
            value: '${_numberFormat.format(result.steps)} langkah',
          ),
          const Divider(height: 1),
          _HabitRow(
            icon: Icons.bedtime_outlined,
            label: 'Tidur',
            value: '${result.sleepHours} jam',
          ),
        ],
      ),
    );
  }
}

class _HabitRow extends StatelessWidget {
  const _HabitRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Icon(icon, size: 20, color: _color),
      title: Text(label, style: const TextStyle(fontSize: 13)),
      trailing: Text(
        value,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
      ),
    );
  }
}
