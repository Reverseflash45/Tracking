import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_value_view.dart';
import '../data/academic_repository.dart';
import '../data/models/task.dart';
import 'academic_providers.dart';

final _dateFormat = DateFormat('d MMM y, HH:mm', 'id_ID');

Color priorityColor(TaskPriority priority) {
  switch (priority) {
    case TaskPriority.high:
      return Colors.red;
    case TaskPriority.medium:
      return Colors.orange;
    case TaskPriority.low:
      return Colors.green;
  }
}

class TasksPage extends ConsumerWidget {
  const TasksPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(tasksProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Tugas Kuliah')),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await context.push('/academic/tasks/new');
          ref.invalidate(tasksProvider);
        },
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(tasksProvider),
        child: AsyncValueView(
          value: tasksAsync,
          emptyIcon: Icons.checklist_outlined,
          emptyTitle: 'Belum ada tugas',
          emptySubtitle: 'Tekan tombol + untuk menambahkan',
          data: (tasks) => ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: tasks.length,
            separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final task = tasks[index];
              final overdue = !task.isDone && task.deadline.isBefore(DateTime.now());
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
                ),
                onDismissed: (_) async {
                  await ref.read(academicRepositoryProvider).deleteTask(task.id);
                  ref.invalidate(tasksProvider);
                },
                child: Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: priorityColor(task.priority).withValues(alpha: 0.15),
                      child: Icon(Icons.flag, color: priorityColor(task.priority), size: 18),
                    ),
                    title: Text(
                      task.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        decoration: task.isDone ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    subtitle: Text(
                      '${task.courseName ?? "Umum"} - DL ${_dateFormat.format(task.deadline)}'
                      '${overdue ? " - Terlambat" : ""}',
                      style: overdue ? const TextStyle(color: Colors.red) : null,
                    ),
                    trailing: PopupMenuButton<TaskStatus>(
                      initialValue: task.status,
                      onSelected: (status) async {
                        await ref.read(academicRepositoryProvider).updateTaskStatus(task.id, status);
                        ref.invalidate(tasksProvider);
                      },
                      itemBuilder: (context) => TaskStatus.values
                          .map((status) => PopupMenuItem(value: status, child: Text(status.label)))
                          .toList(),
                      child: Chip(label: Text(task.status.label)),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
