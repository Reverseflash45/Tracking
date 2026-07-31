import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/hero_header.dart';
import '../../../core/widgets/section_header.dart';
import '../domain/muscle_guide.dart';

const _color = AppColors.workout;

class MuscleBuilderPage extends StatelessWidget {
  const MuscleBuilderPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          HeroHeader(
            title: 'Muscle Builder',
            subtitle: 'Pilih otot yang mau dikembangkan',
            color: _color,
            leading: HeroIconButton(
              icon: Icons.arrow_back,
              tooltip: 'Kembali',
              onPressed: () => context.pop(),
            ),
            stats: [
              HeroStatData(
                icon: Icons.grid_view,
                value: '${muscleGroups.length}',
                label: 'Kelompok Otot',
              ),
              HeroStatData(
                icon: Icons.fitness_center,
                value: '$_totalExercises',
                label: 'Latihan',
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(
                  title: 'Kelompok Otot',
                  icon: Icons.accessibility_new,
                  color: _color,
                ),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: AppSpacing.sm,
                    crossAxisSpacing: AppSpacing.sm,
                    childAspectRatio: 1.45,
                  ),
                  itemCount: muscleGroups.length,
                  itemBuilder: (context, index) => _MuscleCard(group: muscleGroups[index]),
                ),
                const SizedBox(height: AppSpacing.lg),
                const SectionHeader(
                  title: 'Nutrisi Pendukung',
                  icon: Icons.restaurant_outlined,
                  color: _color,
                ),
                const _NutritionCard(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Dihitung dari datanya supaya tidak basi kalau daftar latihannya berubah.
final _totalExercises =
    muscleGroups.fold<int>(0, (sum, group) => sum + group.exercises.length);

class _MuscleCard extends StatelessWidget {
  const _MuscleCard({required this.group});

  final MuscleGroup group;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/workout/muscle/${group.slug}'),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(group.icon, size: 18, color: _color),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    group.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${group.exercises.length} latihan - ${group.frequencyPerWeek}x/minggu',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NutritionCard extends StatelessWidget {
  const _NutritionCard();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Berlaku untuk semua kelompok otot. Tidak ada makanan yang menargetkan otot '
              'tertentu — latihanmu yang menentukan otot mana yang tumbuh, makanan menyediakan '
              'bahan bakunya.',
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            for (final tip in muscleNutritionGuide)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 5),
                      child: Icon(Icons.circle, size: 5, color: _color),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(tip, style: const TextStyle(fontSize: 12, height: 1.45)),
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
