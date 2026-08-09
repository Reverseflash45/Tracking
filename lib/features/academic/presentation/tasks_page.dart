import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/hero_header.dart';
import '../data/models/task.dart';
import 'academic_providers.dart';
import 'task_tile.dart';

enum _TaskFilter {
  all('Semua'),
  todo('Belum'),
  inProgress('Proses'),
  done('Selesai');

  const _TaskFilter(this.label);
  final String label;

  bool matches(AcademicTask task) {
    switch (this) {
      case _TaskFilter.all:
        return true;
      case _TaskFilter.todo:
        return task.status == TaskStatus.todo;
      case _TaskFilter.inProgress:
        return task.status == TaskStatus.inProgress;
      case _TaskFilter.done:
        return task.status == TaskStatus.done;
    }
  }
}

class TasksPage extends ConsumerStatefulWidget {
  const TasksPage({super.key});

  @override
  ConsumerState<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends ConsumerState<TasksPage> {
  _TaskFilter _filter = _TaskFilter.all;

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(tasksTampilProvider);

    // Halaman ini khusus tugas kuliah; urusan pribadi punya halamannya sendiri.
    // Keduanya dipisah karena dilihat pada waktu yang berbeda: daftar kuliah
    // dibuka saat memikirkan kuliah, dan mencampurnya dengan "servis motor"
    // membuat keduanya sama-sama sulit dibaca.
    final kuliah = (tasksAsync.value ?? const <AcademicTask>[])
        .where((t) => t.kind == TaskKind.kuliah)
        .toList();

    final unfinished = kuliah.where((t) => !t.isDone).length;
    final overdue =
        kuliah.where((t) => !t.isDone && t.deadline.isBefore(DateTime.now())).length;
    final done = kuliah.where((t) => t.isDone).length;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/academic/tasks/new');
          ref.invalidate(tasksProvider);
        },
        backgroundColor: AppColors.deadline,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Tugas'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(tasksProvider),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            HeroHeader(
              title: 'Tugas Kuliah',
              subtitle: 'Pantau deadline dan progres pengerjaan',
              color: AppColors.deadline,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  HeroIconButton(
                    icon: Icons.person_outline,
                    tooltip: 'Tugas pribadi',
                    onPressed: () async {
                      await context.push('/academic/tasks/pribadi');
                      ref.invalidate(tasksProvider);
                    },
                  ),
                  const SizedBox(width: 6),
                  HeroIconButton(
                    icon: Icons.event_repeat,
                    tooltip: 'Tugas berulang',
                    onPressed: () async {
                      await context.push('/academic/tasks/recurring');
                      ref.invalidate(tasksProvider);
                    },
                  ),
                ],
              ),
              stats: [
                HeroStatData(
                  icon: Icons.pending_actions,
                  value: '$unfinished',
                  label: 'Belum Selesai',
                ),
                HeroStatData(
                  icon: Icons.warning_amber_rounded,
                  value: '$overdue',
                  label: 'Terlambat',
                ),
                HeroStatData(icon: Icons.task_alt, value: '$done', label: 'Selesai'),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final filter in _TaskFilter.values) ...[
                      if (filter != _TaskFilter.values.first) const SizedBox(width: AppSpacing.sm),
                      FilterChip(
                        label: Text(filter.label),
                        selected: _filter == filter,
                        onSelected: (_) => setState(() => _filter = filter),
                        selectedColor: AppColors.deadline.withValues(alpha: 0.18),
                        checkmarkColor: AppColors.deadline,
                        labelStyle: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: _filter == filter
                              ? AppColors.deadline
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, 96),
              child: tasksAsync.when(
                data: (_) {
                  final filtered = kuliah.where(_filter.matches).toList();
                  if (filtered.isEmpty) {
                    return EmptyState(
                      icon: Icons.checklist_outlined,
                      title: _filter == _TaskFilter.all
                          ? 'Belum ada tugas kuliah'
                          : 'Tidak ada tugas ${_filter.label.toLowerCase()}',
                      subtitle: _filter == _TaskFilter.all
                          ? 'Tekan tombol + untuk menambahkan'
                          : 'Coba ganti filter di atas',
                      color: AppColors.deadline,
                    );
                  }
                  return Column(
                    children: [
                      for (final task in filtered)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: TaskTile(task: task),
                        ),
                    ],
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, stackTrace) => EmptyState(
                  icon: Icons.error_outline,
                  title: 'Gagal memuat tugas',
                  subtitle: '$error',
                  color: AppColors.deadline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
