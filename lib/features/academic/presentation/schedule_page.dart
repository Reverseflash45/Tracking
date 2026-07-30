import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_value_view.dart';
import '../data/academic_repository.dart';
import '../data/models/class_schedule.dart';
import 'academic_providers.dart';

class SchedulePage extends ConsumerWidget {
  const SchedulePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schedules = ref.watch(classSchedulesProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Jadwal Kuliah')),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await context.push('/academic/schedule/new');
          ref.invalidate(classSchedulesProvider);
        },
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(classSchedulesProvider),
        child: AsyncValueView<ClassSchedule>(
          value: schedules,
          emptyIcon: Icons.event_note_outlined,
          emptyTitle: 'Belum ada jadwal kuliah',
          emptySubtitle: 'Tekan tombol + untuk menambahkan',
          data: (items) => ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: items.length,
            separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final schedule = items[index];
              return Dismissible(
                key: ValueKey(schedule.id),
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
                    title: const Text('Hapus jadwal?'),
                    content: Text('Jadwal ${schedule.courseName} akan dihapus.'),
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
                  await ref.read(academicRepositoryProvider).deleteSchedule(schedule.id);
                  ref.invalidate(classSchedulesProvider);
                },
                child: Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: colorScheme.primaryContainer,
                      foregroundColor: colorScheme.onPrimaryContainer,
                      child: Icon(schedule.isPhl ? Icons.event_repeat : Icons.school),
                    ),
                    title: Text(schedule.courseName, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(
                      '${schedule.isPhl ? "PHL - " : ""}${weekDayName(schedule.dayOfWeek)}, '
                      '${schedule.timeRangeLabel}'
                      '${schedule.room != null ? " - ${schedule.room}" : ""}',
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
