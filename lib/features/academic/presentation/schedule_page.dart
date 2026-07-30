import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/async_value_view.dart';
import '../data/academic_repository.dart';
import '../data/models/class_schedule.dart';
import 'academic_providers.dart';

class SchedulePage extends ConsumerWidget {
  const SchedulePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schedules = ref.watch(classSchedulesProvider);

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
          emptyMessage: 'Belum ada jadwal kuliah.\nTekan + untuk menambahkan.',
          data: (items) => ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final schedule = items[index];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(schedule.courseName.isNotEmpty
                        ? schedule.courseName[0].toUpperCase()
                        : '?'),
                  ),
                  title: Text(schedule.courseName),
                  subtitle: Text(
                    '${schedule.isPhl ? "PHL - " : ""}${weekDayName(schedule.dayOfWeek)}, '
                    '${schedule.timeRangeLabel}'
                    '${schedule.room != null ? " · ${schedule.room}" : ""}',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      await ref.read(academicRepositoryProvider).deleteSchedule(schedule.id);
                      ref.invalidate(classSchedulesProvider);
                    },
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
