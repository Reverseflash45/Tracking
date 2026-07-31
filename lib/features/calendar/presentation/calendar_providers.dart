import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../academic/data/models/class_schedule.dart';
import '../../academic/data/models/task.dart';
import '../../academic/presentation/academic_providers.dart';
import '../../workout/data/models/workout_session.dart';
import '../../workout/presentation/workout_providers.dart';
import '../domain/calendar_event.dart';

final _timeFormat = DateFormat('HH:mm', 'id_ID');

DateTime _dayKey(DateTime date) => DateTime(date.year, date.month, date.day);

/// Gabungan jadwal kuliah, tugas, dan workout yang bisa ditanya per hari.
///
/// Jadwal kuliah biasa berulang tiap minggu, jadi tidak bisa dimuat ke map
/// statis untuk rentang tak terbatas — jadwal dihitung saat [forDay] dipanggil,
/// sementara tugas dan workout (jumlahnya terbatas) diindeks di awal.
class CalendarEventIndex {
  CalendarEventIndex({
    required List<ClassSchedule> schedules,
    required List<AcademicTask> tasks,
    required List<WorkoutSession> sessions,
  })  : _schedules = schedules,
        _tasksByDay = _groupTasks(tasks),
        _sessionsByDay = _groupSessions(sessions);

  final List<ClassSchedule> _schedules;
  final Map<DateTime, List<AcademicTask>> _tasksByDay;
  final Map<DateTime, List<WorkoutSession>> _sessionsByDay;

  static Map<DateTime, List<AcademicTask>> _groupTasks(List<AcademicTask> tasks) {
    final map = <DateTime, List<AcademicTask>>{};
    for (final task in tasks) {
      map.putIfAbsent(_dayKey(task.deadline), () => []).add(task);
    }
    return map;
  }

  static Map<DateTime, List<WorkoutSession>> _groupSessions(List<WorkoutSession> sessions) {
    final map = <DateTime, List<WorkoutSession>>{};
    for (final session in sessions) {
      map.putIfAbsent(_dayKey(session.sessionDate), () => []).add(session);
    }
    return map;
  }

  List<CalendarEvent> forDay(DateTime day) {
    final key = _dayKey(day);
    final events = <CalendarEvent>[];

    for (final schedule in _schedules) {
      final cocok = schedule.isPhl
          ? (schedule.specificDate != null && _dayKey(schedule.specificDate!) == key)
          : schedule.dayOfWeek == key.weekday;
      if (!cocok) continue;

      events.add(CalendarEvent(
        type: CalendarEventType.jadwal,
        title: schedule.courseName,
        subtitle: [
          schedule.timeRangeLabel,
          if (schedule.room != null && schedule.room!.isNotEmpty) schedule.room!,
          if (schedule.isPhl) 'PHL',
        ].join(' - '),
        sortKey: _minutesOf(schedule.startTime),
        route: '/academic/schedule',
      ));
    }

    for (final task in _tasksByDay[key] ?? const <AcademicTask>[]) {
      events.add(CalendarEvent(
        type: CalendarEventType.tugas,
        title: task.title,
        subtitle: [
          'Deadline ${_timeFormat.format(task.deadline)}',
          if (task.courseName != null) task.courseName!,
          if (task.isDone) 'Selesai',
        ].join(' - '),
        sortKey: task.deadline.hour * 60 + task.deadline.minute,
        route: '/academic/tasks/${task.id}',
      ));
    }

    for (final session in _sessionsByDay[key] ?? const <WorkoutSession>[]) {
      events.add(CalendarEvent(
        type: CalendarEventType.workout,
        title: 'Sesi workout',
        subtitle: [
          '${session.exercises.length} latihan',
          if (session.notes != null && session.notes!.isNotEmpty) session.notes!,
        ].join(' - '),
        // Tanpa jam, jadi selalu di urutan paling bawah.
        sortKey: 24 * 60,
        route: '/workout',
      ));
    }

    events.sort((a, b) => a.sortKey.compareTo(b.sortKey));
    return events;
  }

  /// 'HH:mm:ss' dari kolom `time` Postgres -> menit dari tengah malam.
  static int _minutesOf(String time) {
    final parts = time.split(':');
    final hour = int.tryParse(parts.first) ?? 0;
    final minute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    return hour * 60 + minute;
  }
}

final calendarEventIndexProvider =
    Provider.autoDispose<AsyncValue<CalendarEventIndex>>((ref) {
  final schedules = ref.watch(classSchedulesProvider);
  final tasks = ref.watch(tasksProvider);
  final sessions = ref.watch(workoutSessionsProvider);

  // Tampilkan loading/error kalau salah satu sumber belum siap, supaya kalender
  // tidak sempat menampilkan hari yang kelihatan kosong padahal masih memuat.
  final error = schedules.error ?? tasks.error ?? sessions.error;
  if (error != null) {
    return AsyncValue.error(
      error,
      schedules.stackTrace ?? tasks.stackTrace ?? sessions.stackTrace ?? StackTrace.current,
    );
  }

  final scheduleList = schedules.value;
  final taskList = tasks.value;
  final sessionList = sessions.value;
  if (scheduleList == null || taskList == null || sessionList == null) {
    return const AsyncValue.loading();
  }

  return AsyncValue.data(CalendarEventIndex(
    schedules: scheduleList,
    tasks: taskList,
    sessions: sessionList,
  ));
});
