import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../../../core/theme/warna_matkul.dart';
import '../data/academic_repository.dart';
import '../data/models/class_schedule.dart';
import '../data/models/course.dart';
import '../data/models/task.dart';
import '../domain/deadline_streak.dart';
import '../domain/recurring_task.dart';
import '../domain/schedule_conflict.dart';

final coursesProvider = FutureProvider.autoDispose<List<Course>>((ref) async {
  final userId = ref.watch(currentUserProvider)?.id;
  if (userId == null) return const [];
  final daftar = await ref.watch(academicRepositoryProvider).fetchCourses(userId);
  bagikanWarnaMatkul(daftar.map((c) => c.id));
  return daftar;
});

final classSchedulesProvider = FutureProvider.autoDispose<List<ClassSchedule>>((ref) async {
  final userId = ref.watch(currentUserProvider)?.id;
  if (userId == null) return const [];
  final list = await ref.watch(academicRepositoryProvider).fetchSchedules(userId);
  // Jadwal bisa dimuat sebelum daftar mata kuliah; warnanya dibagikan dari
  // sini juga supaya blok jadwal tidak sempat memakai warna hash.
  bagikanWarnaMatkul(list.map((s) => s.courseId));
  // Urutan dari server tidak selalu sampai utuh (salinan luring bisa
  // tersimpan dalam urutan lain), jadi diurutkan ulang di sini: per hari,
  // lalu per jam mulai.
  return [...list]..sort((a, b) {
      final hari = a.dayOfWeek.compareTo(b.dayOfWeek);
      if (hari != 0) return hari;
      return (menitDariJam(a.startTime) ?? 0).compareTo(menitDariJam(b.startTime) ?? 0);
    });
});

/// Mata kuliah beserta jadwalnya, dipakai bersama [pilihanMatkul] untuk
/// menyaring daftar pilihan ke mata kuliah yang sedang dijalani.
typedef DaftarMatkul = ({List<Course> semua, List<ClassSchedule> jadwal});

final daftarMatkulProvider = FutureProvider.autoDispose<DaftarMatkul>((ref) async {
  final semua = await ref.watch(coursesProvider.future);
  final jadwal = await ref.watch(classSchedulesProvider.future);
  return (semua: semua, jadwal: jadwal);
});

final tasksProvider = FutureProvider.autoDispose<List<AcademicTask>>((ref) async {
  final userId = ref.watch(currentUserProvider)?.id;
  if (userId == null) return const [];
  return ref.watch(academicRepositoryProvider).fetchTasks(userId);
});

/// Status yang sudah dikirim ke server tapi belum terlihat di daftar.
///
/// Tanpa ini, menandai tugas selesai terasa seperti tidak terjadi apa-apa:
/// perubahannya baru muncul setelah seluruh daftar diambil ulang dari server,
/// dan kalau pengambilan itu gagal, daftar jatuh ke cache lama yang statusnya
/// masih yang dulu — persis seperti tombolnya rusak.
///
/// Sengaja bukan autoDispose: bayangannya harus bertahan saat berpindah antara
/// daftar tugas kuliah dan pribadi.
class StatusSementara extends Notifier<Map<String, TaskStatus>> {
  @override
  Map<String, TaskStatus> build() => const {};

  void tandai(String taskId, TaskStatus status) => state = {...state, taskId: status};

  void lupakan(String taskId) => state = {...state}..remove(taskId);
}

final statusSementaraProvider =
    NotifierProvider<StatusSementara, Map<String, TaskStatus>>(StatusSementara.new);

/// Daftar tugas seperti yang ditampilkan: isi dari server, ditimpa status yang
/// baru saja diubah dari layar.
final tasksTampilProvider = Provider.autoDispose<AsyncValue<List<AcademicTask>>>((ref) {
  final sementara = ref.watch(statusSementaraProvider);
  return ref.watch(tasksProvider).whenData((list) {
    if (sementara.isEmpty) return list;
    return [
      for (final task in list)
        if (sementara[task.id] case final status?) task.denganStatus(status) else task,
    ];
  });
});

/// Jadwal kuliah pada hari ini (hari biasa maupun PHL tanggal spesifik).
final todaySchedulesProvider = Provider.autoDispose<AsyncValue<List<ClassSchedule>>>((ref) {
  final schedules = ref.watch(classSchedulesProvider);
  final today = DateTime.now();
  return schedules.whenData((list) => list.where((schedule) {
        if (schedule.isPhl) {
          final date = schedule.specificDate;
          return date != null &&
              date.year == today.year &&
              date.month == today.month &&
              date.day == today.day;
        }
        return schedule.dayOfWeek == today.weekday;
      }).toList());
});

final upcomingDeadlinesProvider = Provider.autoDispose<AsyncValue<List<AcademicTask>>>((ref) {
  final tasks = ref.watch(tasksProvider);
  return tasks.whenData(
    (list) => list.where((task) => !task.isDone).take(5).toList(),
  );
});

final deadlineStreakProvider = Provider.autoDispose<AsyncValue<DeadlineStreak>>((ref) {
  final tasks = ref.watch(tasksProvider);
  return tasks.whenData(calculateDeadlineStreak);
});

final recurringTasksProvider = FutureProvider.autoDispose<List<RecurringTask>>((ref) async {
  final userId = ref.watch(currentUserProvider)?.id;
  if (userId == null) return const [];
  return ref.watch(academicRepositoryProvider).fetchRecurringTasks(userId);
});

/// Jadwal yang bertabrakan, dipetakan per id jadwal.
final scheduleConflictsProvider =
    Provider.autoDispose<Map<String, List<ScheduleConflict>>>((ref) {
  final schedules = ref.watch(classSchedulesProvider).value ?? const <ClassSchedule>[];
  return conflictMap(schedules);
});
