import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/hero_header.dart';
import '../../academic/presentation/academic_providers.dart';
import '../../run/data/run_repository.dart';
import '../../workout/presentation/workout_providers.dart';
import '../domain/correlation.dart';

const _color = AppColors.dashboard;

/// Pola yang ditemukan dari data, dihitung ulang tiap halaman dibuka.
final insightsProvider = Provider.autoDispose<AsyncValue<List<Insight>>>((ref) {
  final tasks = ref.watch(tasksProvider);
  final sessions = ref.watch(workoutSessionsProvider);
  final runs = ref.watch(runsProvider);

  final error = tasks.error ?? sessions.error ?? runs.error;
  if (error != null) {
    return AsyncValue.error(
      error,
      tasks.stackTrace ?? sessions.stackTrace ?? runs.stackTrace ?? StackTrace.current,
    );
  }

  final t = tasks.value;
  final s = sessions.value;
  final r = runs.value;
  if (t == null || s == null || r == null) return const AsyncValue.loading();

  return AsyncValue.data(findInsights(tasks: t, sessions: s, runs: r));
});

/// Berapa minggu lagi sampai pola pertama bisa dihitung.
final insightReadinessProvider = Provider.autoDispose<int?>((ref) {
  final tasks = ref.watch(tasksProvider).value ?? const [];
  final sessions = ref.watch(workoutSessionsProvider).value ?? const [];
  final runs = ref.watch(runsProvider).value ?? const [];
  return weeksUntilReady(tasks: tasks, sessions: sessions, runs: runs);
});

class InsightPage extends ConsumerWidget {
  const InsightPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insightsAsync = ref.watch(insightsProvider);
    final sisaMinggu = ref.watch(insightReadinessProvider);

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          HeroHeader.sub(
            title: 'Pola',
            subtitle: 'Hubungan antara kebiasaan dan hasilmu',
            color: _color,
            leading: HeroIconButton(
              icon: Icons.arrow_back,
              tooltip: 'Kembali',
              onPressed: () => context.pop(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: insightsAsync.when(
              data: (insights) => insights.isEmpty
                  ? _BelumCukup(sisaMinggu: sisaMinggu)
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _Pengantar(),
                        const SizedBox(height: AppSpacing.md),
                        for (final insight in insights)
                          Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: _InsightCard(insight: insight),
                          ),
                        const SizedBox(height: AppSpacing.md),
                        const _Peringatan(),
                      ],
                    ),
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => EmptyState(
                icon: Icons.error_outline,
                title: 'Gagal memuat',
                subtitle: '$error',
                color: _color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pengantar extends StatelessWidget {
  const _Pengantar();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Aplikasi lain tidak bisa menghitung ini: Strava tidak tahu nilaimu, '
      'aplikasi tugas tidak tahu kamu olahraga. Di sini keduanya ada.',
      style: TextStyle(
        fontSize: 14,
        height: 1.5,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.insight});

  final Insight insight;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final icon = switch (insight.kind) {
      InsightKind.olahragaVsKetepatan => Icons.task_alt,
      InsightKind.olahragaVsKecepatan => Icons.schedule,
      InsightKind.konsistensi => Icons.repeat,
    };

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: _color),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    insight.headline,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              insight.detail,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            // Ukuran sampel ditampilkan terang-terangan. Pola dari 3 minggu
            // dan dari 30 minggu tidak sama bobotnya, dan kamu berhak tahu
            // yang mana yang sedang kamu baca.
            Text(
              insight.kind == InsightKind.konsistensi
                  ? 'Dari ${insight.totalWeeks} minggu'
                  : 'Dibanding dari ${insight.weeksHigh} minggu aktif dan '
                      '${insight.weeksLow} minggu jarang olahraga',
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Peringatan extends StatelessWidget {
  const _Peringatan();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, size: 16, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Ini pola, bukan sebab-akibat. Bisa jadi olahraga membuatmu lebih '
                'teratur — bisa juga minggu yang longgar memang memberi ruang '
                'untuk keduanya sekaligus. Angkanya menunjukkan yang terjadi '
                'bersamaan, bukan yang menyebabkan.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BelumCukup extends StatelessWidget {
  const _BelumCukup({required this.sisaMinggu});

  final int? sisaMinggu;

  @override
  Widget build(BuildContext context) {
    // Dua keadaan berbeda: datanya belum cukup, atau datanya cukup tapi memang
    // tidak ada pola yang cukup kuat. Keduanya jangan disamakan.
    final belumCukupData = sisaMinggu != null;

    return EmptyState(
      icon: belumCukupData ? Icons.hourglass_empty : Icons.check_circle_outline,
      title: belumCukupData ? 'Belum cukup data' : 'Belum ada pola yang jelas',
      subtitle: belumCukupData
          ? 'Butuh sekitar $sisaMinggu minggu lagi yang ada tugas selesainya. '
              'Pola dari sampel kecil cuma derau yang kebetulan berbentuk '
              'kalimat meyakinkan.'
          : 'Datamu sudah cukup, tapi perbedaan antar minggu masih terlalu '
              'kecil untuk disimpulkan. Itu bukan kabar buruk — artinya '
              'hasilmu stabil.',
      color: _color,
    );
  }
}
