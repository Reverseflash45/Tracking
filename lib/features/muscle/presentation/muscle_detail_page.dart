import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/hero_header.dart';
import '../../../core/widgets/section_header.dart';
import '../domain/muscle_guide.dart';

const _color = AppColors.workout;

class MuscleDetailPage extends StatelessWidget {
  const MuscleDetailPage({super.key, required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context) {
    final group = muscleGroupBySlug(slug);

    if (group == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Kelompok Otot')),
        body: const EmptyState(
          icon: Icons.search_off,
          title: 'Kelompok otot tidak ditemukan',
          color: _color,
        ),
      );
    }

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          HeroHeader.sub(
            title: group.name,
            subtitle: group.summary,
            color: _color,
            leading: HeroIconButton(
              icon: Icons.arrow_back,
              tooltip: 'Kembali',
              onPressed: () => context.pop(),
            ),
            stats: [
              HeroStatData(
                icon: Icons.repeat,
                value: '${group.frequencyPerWeek}x',
                label: 'Per Minggu',
              ),
              HeroStatData(
                icon: Icons.fitness_center,
                value: '${group.exercises.length}',
                label: 'Latihan',
              ),
              HeroStatData(
                icon: Icons.layers_outlined,
                value: '${group.exercises.fold<int>(0, (s, e) => s + e.sets)}',
                label: 'Total Set',
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(
                  title: 'Rekomendasi Latihan',
                  icon: Icons.fitness_center,
                  color: _color,
                ),
                for (final exercise in group.exercises) _ExerciseCard(exercise: exercise),
                const SizedBox(height: AppSpacing.md),
                FilledButton.icon(
                  onPressed: () => context.push('/workout/new'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _color,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Catat Sesi Workout'),
                ),
                const SizedBox(height: AppSpacing.lg),
                const SectionHeader(
                  title: 'Stretching',
                  icon: Icons.self_improvement,
                  color: _color,
                ),
                _BulletCard(items: group.stretching, icon: Icons.self_improvement),
                const SizedBox(height: AppSpacing.lg),
                const SectionHeader(
                  title: 'Recovery',
                  icon: Icons.bedtime_outlined,
                  color: _color,
                ),
                _BulletCard(items: group.recovery, icon: Icons.bedtime_outlined),
                const SizedBox(height: AppSpacing.lg),
                const SectionHeader(
                  title: 'Nutrisi Pendukung',
                  icon: Icons.restaurant_outlined,
                  color: _color,
                ),
                _BulletCard(items: muscleNutritionGuide, icon: Icons.restaurant_outlined),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({required this.exercise});

  final MuscleExercise exercise;

  Future<void> _openVideo(BuildContext context) async {
    final uri = Uri.parse(exercise.videoSearchUrl);
    final berhasil = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!berhasil && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak bisa membuka YouTube')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    exercise.name,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    exercise.type.label,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                _Spec(label: 'Set', value: '${exercise.sets}'),
                _Spec(label: 'Rep', value: exercise.reps),
                _Spec(label: 'Istirahat', value: exercise.restLabel),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lightbulb_outline, size: 14, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    exercise.cue,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.4,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _openVideo(context),
                style: TextButton.styleFrom(
                  foregroundColor: _color,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.play_circle_outline, size: 16),
                label: const Text(
                  'Lihat contoh gerakan',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Spec extends StatelessWidget {
  const _Spec({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant)),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _BulletCard extends StatelessWidget {
  const _BulletCard({required this.items, required this.icon});

  final List<String> items;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < items.length; i++)
              Padding(
                padding: EdgeInsets.only(bottom: i == items.length - 1 ? 0 : 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, size: 14, color: _color),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        items[i],
                        style: const TextStyle(fontSize: 12, height: 1.45),
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
