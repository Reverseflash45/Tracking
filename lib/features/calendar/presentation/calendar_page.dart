import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/hero_header.dart';
import '../../../core/widgets/section_header.dart';
import '../domain/calendar_event.dart';
import 'calendar_providers.dart';

const _color = AppColors.academic;
final _selectedDayFormat = DateFormat('EEEE, d MMMM y', 'id_ID');

class CalendarPage extends ConsumerStatefulWidget {
  const CalendarPage({super.key});

  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends ConsumerState<CalendarPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  CalendarFormat _format = CalendarFormat.month;

  @override
  Widget build(BuildContext context) {
    final indexAsync = ref.watch(calendarEventIndexProvider);
    final index = indexAsync.value;
    final events = index?.forDay(_selectedDay) ?? const <CalendarEvent>[];
    final now = DateTime.now();

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          HeroHeader.sub(
            title: 'Kalender',
            subtitle: 'Jadwal, deadline, dan workout dalam satu tampilan',
            color: _color,
            leading: HeroIconButton(
              icon: Icons.arrow_back,
              tooltip: 'Kembali',
              onPressed: () => context.pop(),
            ),
            trailing: HeroIconButton(
              icon: Icons.today,
              tooltip: 'Ke hari ini',
              onPressed: () => setState(() {
                _focusedDay = DateTime.now();
                _selectedDay = DateTime.now();
              }),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    child: TableCalendar<CalendarEvent>(
                      locale: 'id_ID',
                      firstDay: DateTime(now.year - 2, now.month),
                      lastDay: DateTime(now.year + 2, now.month),
                      focusedDay: _focusedDay,
                      calendarFormat: _format,
                      startingDayOfWeek: StartingDayOfWeek.monday,
                      availableCalendarFormats: const {
                        CalendarFormat.month: 'Bulan',
                        CalendarFormat.twoWeeks: '2 Minggu',
                        CalendarFormat.week: 'Minggu',
                      },
                      selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
                      eventLoader: (day) => index?.forDay(day) ?? const [],
                      onDaySelected: (selected, focused) => setState(() {
                        _selectedDay = selected;
                        _focusedDay = focused;
                      }),
                      onFormatChanged: (format) => setState(() => _format = format),
                      onPageChanged: (focused) => _focusedDay = focused,
                      headerStyle: const HeaderStyle(
                        formatButtonShowsNext: false,
                        titleCentered: true,
                        titleTextStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                      calendarStyle: CalendarStyle(
                        markersMaxCount: 3,
                        todayDecoration: BoxDecoration(
                          color: _color.withValues(alpha: 0.25),
                          shape: BoxShape.circle,
                        ),
                        todayTextStyle: const TextStyle(fontWeight: FontWeight.w700),
                        selectedDecoration: const BoxDecoration(
                          color: _color,
                          shape: BoxShape.circle,
                        ),
                        selectedTextStyle: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      calendarBuilders: CalendarBuilders<CalendarEvent>(
                        markerBuilder: (context, day, dayEvents) {
                          if (dayEvents.isEmpty) return null;
                          // Satu titik per jenis, bukan per event, supaya
                          // hari yang padat tidak penuh titik.
                          final types = {for (final e in dayEvents) e.type}.toList()
                            ..sort((a, b) => a.index.compareTo(b.index));
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                for (final type in types)
                                  Container(
                                    width: 5,
                                    height: 5,
                                    margin: const EdgeInsets.symmetric(horizontal: 1),
                                    decoration: BoxDecoration(
                                      color: type.color,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                const _Legend(),
                const SizedBox(height: AppSpacing.md),
                SectionHeader(
                  title: _selectedDayFormat.format(_selectedDay),
                  icon: Icons.event_note_outlined,
                  color: _color,
                ),
                if (indexAsync.isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                    child: LinearProgressIndicator(),
                  )
                else if (indexAsync.hasError)
                  Text('Gagal memuat: ${indexAsync.error}')
                else if (events.isEmpty)
                  const EmptyState(
                    icon: Icons.free_breakfast_outlined,
                    title: 'Tidak ada agenda',
                    subtitle: 'Hari ini kosong, nikmati waktu luangmu',
                    color: _color,
                    compact: true,
                  )
                else
                  for (final event in events) _EventTile(event: event),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.sm,
      children: [
        for (final type in CalendarEventType.values)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: type.color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 4),
              Text(
                type.label,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({required this.event});

  final CalendarEvent event;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        onTap: event.route == null ? null : () => context.push(event.route!),
        leading: Icon(event.type.icon, size: 20, color: event.type.color),
        title: Text(
          event.title,
          style: const TextStyle(fontWeight: FontWeight.w700),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: event.subtitle == null
            ? null
            : Text(event.subtitle!, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: event.route == null ? null : const Icon(Icons.chevron_right),
      ),
    );
  }
}
