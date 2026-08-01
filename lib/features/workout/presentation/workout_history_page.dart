import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/hero_header.dart';
import '../data/models/exercise_entry.dart';
import '../data/models/workout_session.dart';
import '../data/rest_day_repository.dart';
import '../data/workout_repository.dart';
import '../domain/history_filter.dart';
import 'workout_providers.dart';

final _weekDayFormat = DateFormat('EEEE', 'id_ID');
final _monthFormat = DateFormat('MMM', 'id_ID');
final _volumeFormat = NumberFormat.decimalPattern('id_ID');

/// Ringkasan satu latihan menyesuaikan tipenya: beban punya kg, bodyweight
/// hanya set x rep, isometrik dalam detik, cardio dalam menit.
String _exerciseSummary(ExerciseEntry exercise) {
  final setsReps = '${exercise.sets ?? 0}x${exercise.reps ?? 0}';
  return switch (exercise.type) {
    ExerciseType.cardio => '${exercise.durationMinutes ?? 0} menit',
    ExerciseType.isometrik => '${exercise.sets ?? 0}x${exercise.durationSeconds ?? 0} detik',
    ExerciseType.bodyweight => exercise.weightKg != null && exercise.weightKg! > 0
        ? '+${exercise.weightKg} kg  ·  $setsReps'
        : setsReps,
    ExerciseType.beban => '${exercise.weightKg ?? 0} kg  ·  $setsReps',
  };
}

/// Riwayat lengkap: semua sesi latihan dan hari istirahat, bisa disaring.
///
/// Halaman terpisah dari dashboard Workout. Setahun latihan bisa ratusan
/// baris, dan tanpa saringan, mencari "kapan terakhir deadlift" berarti
/// menggulir sampai habis.
class WorkoutHistoryPage extends ConsumerStatefulWidget {
  const WorkoutHistoryPage({super.key});

  @override
  ConsumerState<WorkoutHistoryPage> createState() => _WorkoutHistoryPageState();
}

class _WorkoutHistoryPageState extends ConsumerState<WorkoutHistoryPage> {
  // Bawaan 30 hari, bukan "Semua". Yang dicari orang di riwayat hampir selalu
  // yang belum lama, dan memuat 400 baris untuk itu cuma bikin tersendat.
  HistoryFilter _filter = const HistoryFilter();
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sessionsAsync = ref.watch(workoutSessionsProvider);
    final sessions = sessionsAsync.value ?? const <WorkoutSession>[];
    final restDays = ref.watch(restDaysProvider).value ?? const <RestDay>[];

    final rows = filterHistory(
      sessions: sessions,
      restDays: restDays,
      filter: _filter,
      now: DateTime.now(),
    );
    final summary = summarizeHistory(rows, kind: _filter.kind);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(workoutSessionsProvider);
          ref.invalidate(restDaysProvider);
        },
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            HeroHeader(
              title: 'Riwayat Latihan',
              subtitle: 'Semua catatan, bisa disaring',
              color: AppColors.workout,
              leading: HeroIconButton(
                icon: Icons.arrow_back,
                tooltip: 'Kembali',
                onPressed: () => context.pop(),
              ),
              stats: [
                HeroStatData(
                  icon: Icons.fitness_center,
                  value: '${summary.sesi}',
                  label: 'Sesi',
                ),
                HeroStatData(
                  icon: Icons.scale_outlined,
                  value: summary.volumeKg > 0
                      ? _volumeFormat.format(summary.volumeKg.round())
                      : '0',
                  label: 'Volume (kg)',
                ),
                HeroStatData(
                  icon: Icons.bedtime_outlined,
                  value: '${summary.hariIstirahat}',
                  label: 'Istirahat',
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.xl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _FilterBar(
                    filter: _filter,
                    controller: _searchController,
                    onChanged: (filter) => setState(() => _filter = filter),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  sessionsAsync.when(
                    data: (_) => rows.isEmpty
                        ? _EmptyForFilter(filter: _filter)
                        : Column(
                            children: [
                              for (final row in rows)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                                  child: row.isRest
                                      ? _RestDayTile(restDay: row.rest!)
                                      : _SessionCard(session: row.session!),
                                ),
                            ],
                          ),
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (error, stackTrace) => EmptyState(
                      icon: Icons.error_outline,
                      title: 'Gagal memuat sesi',
                      subtitle: '$error',
                      color: AppColors.workout,
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

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.filter,
    required this.controller,
    required this.onChanged,
  });

  final HistoryFilter filter;
  final TextEditingController controller;
  final ValueChanged<HistoryFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: controller,
          onChanged: (value) => onChanged(filter.copyWith(query: value)),
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Cari nama latihan',
            hintStyle: const TextStyle(fontSize: 13),
            prefixIcon: const Icon(Icons.search, size: 19),
            suffixIcon: filter.query.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    tooltip: 'Hapus pencarian',
                    onPressed: () {
                      controller.clear();
                      onChanged(filter.copyWith(query: ''));
                    },
                  ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        _ChipRow(
          label: 'Periode',
          children: [
            for (final period in HistoryPeriod.values)
              _FilterChip(
                label: period.label,
                selected: filter.period == period,
                onTap: () => onChanged(filter.copyWith(period: period)),
              ),
          ],
        ),
        const SizedBox(height: 6),
        _ChipRow(
          label: 'Jenis',
          children: [
            for (final kind in HistoryKind.values)
              _FilterChip(
                label: kind.label,
                selected: filter.kind == kind,
                onTap: () => onChanged(filter.copyWith(kind: kind)),
              ),
          ],
        ),
        if (filter.aktif) ...[
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                controller.clear();
                onChanged(const HistoryFilter(period: HistoryPeriod.semua));
              },
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                foregroundColor: colorScheme.onSurfaceVariant,
              ),
              icon: const Icon(Icons.filter_alt_off_outlined, size: 16),
              label: const Text('Tampilkan semua', style: TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ],
    );
  }
}

/// Baris chip yang bisa digeser mendatar.
///
/// Digulir, bukan dibungkus ke bawah, supaya tinggi saringannya tetap dan
/// daftar di bawahnya tidak melompat tiap kali pilihan berubah.
class _ChipRow extends StatelessWidget {
  const _ChipRow({required this.label, required this.children});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          for (final child in children)
            Padding(padding: const EdgeInsets.only(right: 6), child: child),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        selectedColor: AppColors.workout.withValues(alpha: 0.18),
        labelStyle: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: selected ? AppColors.workout : colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Kosong karena belum ada catatan, atau kosong karena saringannya terlalu
/// sempit — dua hal yang berbeda dan butuh jawaban berbeda.
class _EmptyForFilter extends StatelessWidget {
  const _EmptyForFilter({required this.filter});

  final HistoryFilter filter;

  @override
  Widget build(BuildContext context) {
    if (!filter.aktif) {
      return const EmptyState(
        icon: Icons.fitness_center,
        title: 'Belum ada sesi workout',
        subtitle: 'Tekan tombol + di halaman Workout untuk mencatat latihan',
        color: AppColors.workout,
      );
    }

    return const EmptyState(
      icon: Icons.search_off,
      title: 'Tidak ada yang cocok',
      subtitle: 'Coba longgarkan saringannya — periode lebih panjang, '
          'jenis "Semua", atau hapus pencarian',
      color: AppColors.workout,
    );
  }
}

class _SessionCard extends ConsumerWidget {
  const _SessionCard({required this.session});

  final WorkoutSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    final volume = session.exercises.fold<double>(0, (sum, e) => sum + e.volume);
    final cardioMinutes = session.exercises
        .where((e) => e.type == ExerciseType.cardio)
        .fold<int>(0, (sum, e) => sum + (e.durationMinutes ?? 0));

    return Dismissible(
      key: ValueKey(session.id),
      direction: DismissDirection.endToStart,
      background: Container(
        decoration: BoxDecoration(
          color: colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(AppTheme.radius),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Icon(Icons.delete_outline, color: colorScheme.onErrorContainer),
      ),
      confirmDismiss: (_) => showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Hapus sesi?'),
          content: const Text('Sesi workout ini beserta semua latihannya akan dihapus.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hapus')),
          ],
        ),
      ),
      onDismissed: (_) async {
        await ref.read(workoutRepositoryProvider).deleteSession(session.id);
        ref.invalidate(workoutSessionsProvider);
      },
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
            childrenPadding: const EdgeInsets.only(bottom: AppSpacing.sm),
            leading: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.workout.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${session.sessionDate.day}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                      color: AppColors.workout,
                      height: 1.1,
                    ),
                  ),
                  Text(
                    _monthFormat.format(session.sessionDate),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.workout,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            title: Text(
              _weekDayFormat.format(session.sessionDate),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  _StatPill(
                    icon: Icons.fitness_center,
                    label: '${session.exercises.length} latihan',
                  ),
                  if (volume > 0)
                    _StatPill(
                      icon: Icons.scale_outlined,
                      label: '${_volumeFormat.format(volume.round())} kg',
                    ),
                  if (cardioMinutes > 0)
                    _StatPill(icon: Icons.directions_run, label: '$cardioMinutes menit'),
                ],
              ),
            ),
            children: [
              for (final exercise in session.exercises)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppColors.workout,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          exercise.exerciseName,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                      Text(
                        _exerciseSummary(exercise),
                        style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              if (session.notes != null && session.notes!.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.sm,
                    AppSpacing.md,
                    0,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.sticky_note_2_outlined,
                        size: 14,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          session.notes!,
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.sm, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () async {
                        await context.push('/workout/new?from=${session.id}');
                        ref.invalidate(workoutSessionsProvider);
                      },
                      icon: const Icon(Icons.replay, size: 18, color: AppColors.workout),
                      label: const Text('Ulangi', style: TextStyle(color: AppColors.workout)),
                    ),
                    TextButton.icon(
                      onPressed: () => context.push('/workout/${session.id}/edit'),
                      icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.workout),
                      label: const Text('Edit', style: TextStyle(color: AppColors.workout)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Baris riwayat untuk hari istirahat.
///
/// Sengaja dibuat lebih ramping dan berwarna lain dari kartu sesi — sekilas
/// harus kelihatan bahwa hari itu tidak ada latihannya.
class _RestDayTile extends ConsumerWidget {
  const _RestDayTile({required this.restDay});

  final RestDay restDay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return Dismissible(
      key: ValueKey('rest-${restDay.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        decoration: BoxDecoration(
          color: colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(AppTheme.radius),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Icon(Icons.delete_outline, color: colorScheme.onErrorContainer),
      ),
      onDismissed: (_) async {
        await ref.read(restDayRepositoryProvider).deleteRestDay(restDay.id);
        ref.invalidate(restDaysProvider);
      },
      child: Card(
        margin: EdgeInsets.zero,
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 10,
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.statusInProgress.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${restDay.restOn.day}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: AppColors.statusInProgress,
                        height: 1.1,
                      ),
                    ),
                    Text(
                      _monthFormat.format(restDay.restOn),
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: AppColors.statusInProgress,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _weekDayFormat.format(restDay.restOn),
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      restDay.note?.trim().isNotEmpty == true
                          ? restDay.note!
                          : 'Hari istirahat',
                      style: TextStyle(fontSize: 11.5, color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.bedtime_outlined,
                size: 17,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(fontSize: 12, color: color)),
      ],
    );
  }
}
