import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/hero_header.dart';
import '../../../core/widgets/section_header.dart';
import '../../body/data/body_repository.dart';
import '../../body/domain/calorie_calculator.dart';
import '../data/nutrition_repository.dart';
import '../domain/daily_nutrition.dart';
import '../domain/food_log.dart';
import 'food_form_sheet.dart';

const _color = AppColors.deadline;
final _numberFormat = NumberFormat.decimalPattern('id_ID');
final _timeFormat = DateFormat('HH:mm', 'id_ID');

class NutritionPage extends ConsumerWidget {
  const NutritionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayAsync = ref.watch(todayNutritionProvider);
    final today = todayAsync.value;

    final profile = ref.watch(bodyProfileProvider).value;
    final weight = ref.watch(currentWeightProvider).value;

    // Target hanya bisa dihitung kalau profil tubuh sudah diisi.
    final targets = (profile == null || weight == null)
        ? null
        : calculateCalories(profile: profile, weightKg: weight, now: DateTime.now());

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showFoodFormSheet(context),
        backgroundColor: _color,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Makanan'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(foodLogsProvider);
          ref.invalidate(waterLogsProvider);
        },
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            HeroHeader.sub(
              title: 'Nutrisi Hari Ini',
              subtitle: targets == null
                  ? 'Isi profil tubuh untuk melihat targetmu'
                  : 'Target ${_numberFormat.format(targets.goalKcal)} kkal - '
                      '${targets.macros.proteinG} g protein',
              color: _color,
              leading: HeroIconButton(
                icon: Icons.arrow_back,
                tooltip: 'Kembali',
                onPressed: () => context.pop(),
              ),
              stats: [
                HeroStatData(
                  icon: Icons.local_fire_department,
                  value: _numberFormat.format((today?.calories ?? 0).round()),
                  label: 'Kalori Masuk',
                ),
                HeroStatData(
                  icon: Icons.egg_outlined,
                  value: '${(today?.proteinG ?? 0).round()} g',
                  label: 'Protein',
                ),
                HeroStatData(
                  icon: Icons.local_drink_outlined,
                  value: '${((today?.waterMl ?? 0) / 1000).toStringAsFixed(1)} L',
                  label: 'Air Minum',
                ),
              ],
            ),
            if (todayAsync.isLoading)
              const Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (todayAsync.hasError)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text('Gagal memuat: ${todayAsync.error}'),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.md,
                  96,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (targets == null)
                      const _TargetPrompt()
                    else ...[
                      const SectionHeader(
                        title: 'Progres Target',
                        icon: Icons.track_changes,
                        color: _color,
                      ),
                      _TargetCard(today: today!, targets: targets),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    SectionHeader(
                      title: 'Air Minum',
                      icon: Icons.local_drink_outlined,
                      color: _color,
                      trailing: targets == null
                          ? null
                          : Text(
                              '${today!.waterMl} / ${targets.waterMl} ml',
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                    ),
                    _WaterCard(waterMl: today!.waterMl, targetMl: targets?.waterMl),
                    const SizedBox(height: AppSpacing.lg),
                    const SectionHeader(
                      title: 'Makanan Hari Ini',
                      icon: Icons.restaurant_menu,
                      color: _color,
                    ),
                    for (final meal in Meal.values) _MealSection(meal: meal, today: today),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TargetPrompt extends StatelessWidget {
  const _TargetPrompt();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        onTap: () => context.push('/workout/body'),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.accessibility_new, size: 18, color: _color),
        ),
        title: const Text(
          'Profil tubuh belum diisi',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          'Catatanmu tetap tersimpan, tapi belum ada target pembandingnya.',
          style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

class _TargetCard extends StatelessWidget {
  const _TargetCard({required this.today, required this.targets});

  final DailyNutrition today;
  final CalorieResult targets;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final sisa = targets.goalKcal - today.calories;

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
                  _numberFormat.format(today.calories.round()),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 32,
                    color: _color,
                    height: 1,
                  ),
                ),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '/ ${_numberFormat.format(targets.goalKcal)} kkal',
                    style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    sisa >= 0
                        ? 'Sisa ${_numberFormat.format(sisa.round())}'
                        : 'Lebih ${_numberFormat.format((-sisa).round())}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: sisa >= 0 ? AppColors.statusDone : AppColors.priorityHigh,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _ProgressBar(
              value: today.calories,
              target: targets.goalKcal.toDouble(),
              color: _color,
            ),
            const SizedBox(height: AppSpacing.lg),
            _MacroProgress(
              label: 'Protein',
              value: today.proteinG,
              target: targets.macros.proteinG.toDouble(),
              color: AppColors.deadline,
            ),
            const SizedBox(height: 12),
            _MacroProgress(
              label: 'Karbohidrat',
              value: today.carbsG,
              target: targets.macros.carbsG.toDouble(),
              color: AppColors.dashboard,
            ),
            const SizedBox(height: 12),
            _MacroProgress(
              label: 'Lemak',
              value: today.fatG,
              target: targets.macros.fatG.toDouble(),
              color: AppColors.priorityMedium,
            ),
            if (today.fiberG != null || today.sugarG != null || today.sodiumMg != null) ...[
              const Divider(height: AppSpacing.lg),
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: 6,
                children: [
                  if (today.fiberG != null)
                    _MiniStat(label: 'Serat', value: '${today.fiberG!.round()} g'),
                  if (today.sugarG != null)
                    _MiniStat(label: 'Gula', value: '${today.sugarG!.round()} g'),
                  if (today.sodiumMg != null)
                    _MiniStat(label: 'Natrium', value: '${today.sodiumMg!.round()} mg'),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label ', style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant)),
        Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _MacroProgress extends StatelessWidget {
  const _MacroProgress({
    required this.label,
    required this.value,
    required this.target,
    required this.color,
  });

  final String label;
  final double value;
  final double target;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ),
            Text(
              '${value.round()} / ${target.round()} g',
              style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
        const SizedBox(height: 5),
        _ProgressBar(value: value, target: target, color: color),
      ],
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.value, required this.target, required this.color});

  final double value;
  final double target;
  final Color color;

  @override
  Widget build(BuildContext context) {
    // Target nol terjadi kalau makro-nya memang 0 g; jangan sampai dibagi nol.
    final ratio = target <= 0 ? 0.0 : (value / target).clamp(0.0, 1.0);
    final lewat = target > 0 && value > target;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: LinearProgressIndicator(
        value: ratio.toDouble(),
        minHeight: 8,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        valueColor: AlwaysStoppedAnimation(lewat ? AppColors.priorityHigh : color),
      ),
    );
  }
}

class _WaterCard extends ConsumerWidget {
  const _WaterCard({required this.waterMl, required this.targetMl});

  final int waterMl;
  final int? targetMl;

  Future<void> _addWater(WidgetRef ref, int ml) async {
    final userId = ref.read(currentUserProvider)?.id;
    if (userId == null) return;
    await ref.read(nutritionRepositoryProvider).addWater(userId: userId, ml: ml);
    ref.invalidate(waterLogsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final gelas = waterMl ~/ kGlassMl;
    final targetGelas = targetMl == null ? null : (targetMl! / kGlassMl).ceil();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '${(waterMl / 1000).toStringAsFixed(2)} L',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 24,
                    color: _color,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    targetGelas == null
                        ? '$gelas gelas'
                        : '$gelas dari $targetGelas gelas',
                    style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
            if (targetMl != null) ...[
              const SizedBox(height: AppSpacing.sm),
              _ProgressBar(
                value: waterMl.toDouble(),
                target: targetMl!.toDouble(),
                color: AppColors.dashboard,
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _addWater(ref, kGlassMl),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _color,
                      side: const BorderSide(color: _color),
                    ),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('1 gelas', style: TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _addWater(ref, 600),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _color,
                      side: const BorderSide(color: _color),
                    ),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('1 botol', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MealSection extends ConsumerWidget {
  const _MealSection({required this.meal, required this.today});

  final Meal meal;
  final DailyNutrition today;

  Future<void> _delete(WidgetRef ref, FoodLog food) async {
    await ref.read(nutritionRepositoryProvider).deleteFood(food.id);
    ref.invalidate(foodLogsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = today.forMeal(meal);
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(meal.icon, size: 18, color: _color),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      meal.label,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                  ),
                  Text(
                    '${_numberFormat.format(today.caloriesForMeal(meal).round())} kkal',
                    style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, size: 20),
                    color: _color,
                    tooltip: 'Tambah ke ${meal.label}',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => showFoodFormSheet(context, meal: meal),
                  ),
                ],
              ),
              if (items.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Belum ada catatan',
                    style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                  ),
                )
              else
                for (final food in items)
                  Dismissible(
                    key: ValueKey(food.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.delete_outline, color: colorScheme.onErrorContainer),
                    ),
                    onDismissed: (_) => _delete(ref, food),
                    child: InkWell(
                      onTap: () => showFoodFormSheet(context, existing: food),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    food.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    '${_timeFormat.format(food.loggedAt)}'
                                    '${food.servingGrams != null ? " · ${food.servingGrams!.round()} g" : ""}'
                                    ' · P${food.proteinG.round()} K${food.carbsG.round()} L${food.fatG.round()}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              '${_numberFormat.format(food.calories.round())} kkal',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.edit_outlined,
                              size: 14,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
