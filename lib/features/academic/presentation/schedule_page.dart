import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/hero_header.dart';
import '../data/academic_repository.dart';
import '../data/models/class_schedule.dart';
import 'academic_providers.dart';

final _phlDateFormat = DateFormat('d MMM', 'id_ID');

class SchedulePage extends ConsumerWidget {
  const SchedulePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schedulesAsync = ref.watch(classSchedulesProvider);
    final todayCount = ref.watch(todaySchedulesProvider).value?.length ?? 0;
    final courseCount = ref.watch(coursesProvider).value?.length ?? 0;
    final totalCount = schedulesAsync.value?.length ?? 0;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/academic/schedule/new');
          ref.invalidate(classSchedulesProvider);
        },
        backgroundColor: AppColors.academic,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Jadwal'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(classSchedulesProvider);
          ref.invalidate(coursesProvider);
        },
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            HeroHeader(
              title: 'Jadwal Kuliah',
              subtitle: 'Semua jadwal perkuliahanmu dalam seminggu',
              color: AppColors.academic,
              trailing: HeroIconButton(
                icon: Icons.calendar_month,
                tooltip: 'Kalender',
                onPressed: () => context.push('/academic/schedule/calendar'),
              ),
              stats: [
                HeroStatData(icon: Icons.today_outlined, value: '$todayCount', label: 'Hari Ini'),
                HeroStatData(
                  icon: Icons.event_note_outlined,
                  value: '$totalCount',
                  label: 'Total Jadwal',
                ),
                HeroStatData(
                  icon: Icons.menu_book_outlined,
                  value: '$courseCount',
                  label: 'Mata Kuliah',
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.lg, AppSpacing.md, 96),
              child: schedulesAsync.when(
                data: (items) => items.isEmpty
                    ? const EmptyState(
                        icon: Icons.event_note_outlined,
                        title: 'Belum ada jadwal kuliah',
                        subtitle: 'Tekan tombol + untuk menambahkan',
                        color: AppColors.academic,
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _buildDayGroups(context, ref, items),
                      ),
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, stackTrace) => EmptyState(
                  icon: Icons.error_outline,
                  title: 'Gagal memuat jadwal',
                  subtitle: '$error',
                  color: AppColors.academic,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildDayGroups(BuildContext context, WidgetRef ref, List<ClassSchedule> items) {
    final byDay = <int, List<ClassSchedule>>{};
    for (final schedule in items) {
      byDay.putIfAbsent(schedule.dayOfWeek, () => []).add(schedule);
    }
    final days = byDay.keys.toList()..sort();
    final today = DateTime.now().weekday;

    final widgets = <Widget>[];
    for (final day in days) {
      widgets.add(_DayHeader(day: day, count: byDay[day]!.length, isToday: day == today));
      for (final schedule in byDay[day]!) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _ScheduleTile(schedule: schedule),
          ),
        );
      }
      widgets.add(const SizedBox(height: AppSpacing.md));
    }
    return widgets;
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.day, required this.count, required this.isToday});

  final int day;
  final int count;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Text(
            weekDayName(day),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: isToday ? AppColors.academic : null,
            ),
          ),
          if (isToday) ...[
            const SizedBox(width: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.academic,
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                'Hari ini',
                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
              ),
            ),
          ],
          const Spacer(),
          Text(
            '$count kelas',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _ScheduleTile extends ConsumerWidget {
  const _ScheduleTile({required this.schedule});

  final ClassSchedule schedule;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

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
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hapus')),
          ],
        ),
      ),
      onDismissed: (_) async {
        await ref.read(academicRepositoryProvider).deleteSchedule(schedule.id);
        ref.invalidate(classSchedulesProvider);
      },
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/academic/schedule/${schedule.id}/edit'),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 48,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        schedule.startTime.substring(0, 5),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: AppColors.academic,
                          height: 1.2,
                        ),
                      ),
                      Text(
                        schedule.endTime.substring(0, 5),
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 3,
                  height: 40,
                  margin: const EdgeInsets.only(right: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.academic.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        schedule.courseName,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                      const SizedBox(height: 4),
                      _MetaLine(
                        icon: Icons.place_outlined,
                        text: schedule.room ?? 'Ruangan belum diatur',
                      ),
                      if (schedule.lecturer != null && schedule.lecturer!.trim().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        _MetaLine(icon: Icons.person_outline, text: schedule.lecturer!),
                      ],
                    ],
                  ),
                ),
                if (schedule.isPhl)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.academic.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      schedule.specificDate != null
                          ? 'PHL ${_phlDateFormat.format(schedule.specificDate!)}'
                          : 'PHL',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.academic,
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

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 3),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: color),
          ),
        ),
      ],
    );
  }
}
