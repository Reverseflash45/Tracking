import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/hero_header.dart';
import '../data/academic_repository.dart';
import '../data/models/task.dart';
import 'academic_providers.dart';

final _dateFormat = DateFormat('d MMM y, HH:mm', 'id_ID');

Color priorityColor(TaskPriority priority) {
  switch (priority) {
    case TaskPriority.high:
      return AppColors.priorityHigh;
    case TaskPriority.medium:
      return AppColors.priorityMedium;
    case TaskPriority.low:
      return AppColors.priorityLow;
  }
}

Color _statusColor(TaskStatus status, ColorScheme colorScheme) {
  switch (status) {
    case TaskStatus.todo:
      return colorScheme.onSurfaceVariant;
    case TaskStatus.inProgress:
      return AppColors.statusInProgress;
    case TaskStatus.done:
      return AppColors.statusDone;
  }
}

/// Label relatif ke hari ini, biar urgensi kebaca sekilas tanpa hitung tanggal.
String _countdownLabel(DateTime deadline) {
  final now = DateTime.now();
  final deadlineDay = DateTime(deadline.year, deadline.month, deadline.day);
  final todayDay = DateTime(now.year, now.month, now.day);
  final diff = deadlineDay.difference(todayDay).inDays;

  if (diff < 0) return 'Terlambat ${-diff} hari';
  if (diff == 0) return 'Hari ini';
  if (diff == 1) return 'Besok';
  return '$diff hari lagi';
}

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
    final tasksAsync = ref.watch(tasksProvider);
    final allTasks = tasksAsync.value ?? const <AcademicTask>[];

    final unfinished = allTasks.where((t) => !t.isDone).length;
    final overdue = allTasks.where((t) => !t.isDone && t.deadline.isBefore(DateTime.now())).length;
    final done = allTasks.where((t) => t.isDone).length;

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
                data: (tasks) {
                  final filtered = tasks.where(_filter.matches).toList();
                  if (filtered.isEmpty) {
                    return EmptyState(
                      icon: Icons.checklist_outlined,
                      title: _filter == _TaskFilter.all
                          ? 'Belum ada tugas'
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
                          child: _TaskTile(task: task),
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

class _TaskTile extends ConsumerWidget {
  const _TaskTile({required this.task});

  final AcademicTask task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final accent = priorityColor(task.priority);
    final overdue = !task.isDone && task.deadline.isBefore(DateTime.now());
    final statusColor = _statusColor(task.status, colorScheme);

    return Dismissible(
      key: ValueKey(task.id),
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
          title: const Text('Hapus tugas?'),
          content: Text('Tugas "${task.title}" akan dihapus.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hapus')),
          ],
        ),
      ),
      onDismissed: (_) async {
        await ref.read(academicRepositoryProvider).deleteTask(task.id);
        ref.invalidate(tasksProvider);
      },
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/academic/tasks/${task.id}'),
          child: Container(
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: accent, width: 4)),
            ),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.sm,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                IconButton(
                  tooltip: task.isDone ? 'Tandai belum selesai' : 'Tandai selesai',
                  onPressed: () async {
                    final next = task.isDone ? TaskStatus.todo : TaskStatus.done;
                    await ref.read(academicRepositoryProvider).updateTaskStatus(task.id, next);
                    ref.invalidate(tasksProvider);
                  },
                  icon: Icon(
                    task.isDone ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: task.isDone ? AppColors.statusDone : colorScheme.onSurfaceVariant,
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        task.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          decoration: task.isDone ? TextDecoration.lineThrough : null,
                          color: task.isDone ? colorScheme.onSurfaceVariant : null,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _MetaPill(
                            icon: Icons.menu_book_outlined,
                            label: task.courseName ?? 'Umum',
                            color: colorScheme.onSurfaceVariant,
                          ),
                          _MetaPill(
                            icon: overdue ? Icons.warning_amber_rounded : Icons.event_outlined,
                            label: task.isDone
                                ? _dateFormat.format(task.deadline)
                                : _countdownLabel(task.deadline),
                            color: overdue ? AppColors.priorityHigh : colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                PopupMenuButton<TaskStatus>(
                  initialValue: task.status,
                  tooltip: 'Ubah status',
                  onSelected: (status) async {
                    await ref.read(academicRepositoryProvider).updateTaskStatus(task.id, status);
                    ref.invalidate(tasksProvider);
                  },
                  itemBuilder: (context) => TaskStatus.values
                      .map((status) => PopupMenuItem(value: status, child: Text(status.label)))
                      .toList(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      task.status.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
