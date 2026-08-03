import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/section_header.dart';
import '../data/academic_repository.dart';
import '../data/models/task.dart';
import 'academic_providers.dart';
import 'tasks_page.dart' show priorityColor;

final _fullFormat = DateFormat('EEEE, d MMMM y - HH:mm', 'id_ID');

class TaskDetailPage extends ConsumerWidget {
  const TaskDetailPage({super.key, required this.taskId});

  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(tasksProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Tugas'),
        actions: [
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.push('/academic/tasks/$taskId/edit'),
          ),
        ],
      ),
      body: tasksAsync.when(
        data: (tasks) {
          AcademicTask? task;
          for (final item in tasks) {
            if (item.id == taskId) task = item;
          }

          if (task == null) {
            return const EmptyState(
              icon: Icons.search_off,
              title: 'Tugas tidak ditemukan',
              subtitle: 'Mungkin sudah dihapus',
              color: AppColors.deadline,
            );
          }

          return _TaskDetailBody(task: task);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => EmptyState(
          icon: Icons.error_outline,
          title: 'Gagal memuat tugas',
          subtitle: '$error',
          color: AppColors.deadline,
        ),
      ),
    );
  }
}

class _TaskDetailBody extends ConsumerWidget {
  const _TaskDetailBody({required this.task});

  final AcademicTask task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final accent = priorityColor(task.priority);
    final overdue = !task.isDone && task.deadline.isBefore(DateTime.now());
    final description = task.description?.trim() ?? '';

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Card(
          clipBehavior: Clip.antiAlias,
          child: Container(
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: accent, width: 5)),
            ),
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        decoration: task.isDone ? TextDecoration.lineThrough : null,
                      ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    _Badge(
                      label: 'Prioritas ${task.priority.label}',
                      color: accent,
                      icon: Icons.flag,
                    ),
                    if (overdue)
                      const _Badge(
                        label: 'Terlambat',
                        color: AppColors.priorityHigh,
                        icon: Icons.warning_amber_rounded,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        const SectionHeader(
          title: 'Status',
          icon: Icons.published_with_changes,
          color: AppColors.deadline,
        ),
        SegmentedButton<TaskStatus>(
          segments: TaskStatus.values
              .map((status) => ButtonSegment(value: status, label: Text(status.label)))
              .toList(),
          selected: {task.status},
          showSelectedIcon: false,
          onSelectionChanged: (selection) async {
            await ref
                .read(academicRepositoryProvider)
                .updateTaskStatus(task.id, selection.first);
            ref.invalidate(tasksProvider);
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        const SectionHeader(
          title: 'Deskripsi',
          icon: Icons.notes,
          color: AppColors.deadline,
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Text(
              description.isEmpty ? 'Tidak ada deskripsi.' : description,
              style: TextStyle(
                height: 1.5,
                color: description.isEmpty ? colorScheme.onSurfaceVariant : null,
                fontStyle: description.isEmpty ? FontStyle.italic : null,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        const SectionHeader(
          title: 'Informasi',
          icon: Icons.info_outline,
          color: AppColors.deadline,
        ),
        Card(
          child: Column(
            children: [
              _InfoRow(
                icon: Icons.menu_book_outlined,
                label: 'Mata Kuliah',
                value: task.courseName ?? 'Umum',
              ),
              _InfoRow(
                icon: Icons.event_outlined,
                label: 'Deadline',
                value: _fullFormat.format(task.deadline),
                valueColor: overdue ? AppColors.priorityHigh : null,
              ),
              _InfoRow(
                icon: Icons.add_circle_outline,
                label: 'Dibuat',
                value: _fullFormat.format(task.createdAt),
              ),
              if (task.completedAt != null)
                _InfoRow(
                  icon: Icons.check_circle_outline,
                  label: 'Diselesaikan',
                  value: _fullFormat.format(task.completedAt!),
                  valueColor: task.isOnTime ? AppColors.statusDone : AppColors.priorityHigh,
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        OutlinedButton.icon(
          onPressed: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Hapus tugas?'),
                content: Text('Tugas "${task.title}" akan dihapus.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Batal'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Hapus'),
                  ),
                ],
              ),
            );
            if (confirmed != true || !context.mounted) return;
            await ref.read(academicRepositoryProvider).deleteTask(task.id);
            ref.invalidate(tasksProvider);
            if (context.mounted) context.pop();
          },
          icon: Icon(Icons.delete_outline, color: colorScheme.error),
          label: Text('Hapus Tugas', style: TextStyle(color: colorScheme.error)),
          style: OutlinedButton.styleFrom(side: BorderSide(color: colorScheme.error)),
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color, required this.icon});

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            flex: 2,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
