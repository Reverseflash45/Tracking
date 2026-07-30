import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

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
          emptyMessage: 'Belum ada tugas.\nTekan + untuk menambahkan.',
          data: (tasks) => ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: tasks.length,
            itemBuilder: (context, index) {
              final task = tasks[index];
              final overdue = !task.isDone && task.deadline.isBefore(DateTime.now());
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: priorityColor(task.priority),
                    child: Text(
                      task.priority.label[0],
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text(
                    task.title,
                    style: task.isDone
                        ? const TextStyle(decoration: TextDecoration.lineThrough)
                        : null,
                  ),
                  subtitle: Text(
                    '${task.courseName ?? "Umum"} · DL ${_dateFormat.format(task.deadline)}'
                    '${overdue ? " · Terlambat" : ""}',
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
                  onLongPress: () async {
                    await ref.read(academicRepositoryProvider).deleteTask(task.id);
                    ref.invalidate(tasksProvider);
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
