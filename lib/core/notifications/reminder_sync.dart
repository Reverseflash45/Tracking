import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/academic/data/models/class_schedule.dart';
import '../../features/academic/data/models/task.dart';
import '../../features/academic/presentation/academic_providers.dart';
import '../../features/document/data/document_repository.dart';
import '../../features/document/domain/document.dart';
import '../../features/finance/data/finance_repository.dart';
import '../../features/finance/domain/finance_stats.dart';
import '../../features/finance/domain/transaction.dart';
import '../../features/vehicle/data/vehicle_repository.dart';
import '../../features/vehicle/domain/vehicle.dart';
import '../../features/nutrition/data/nutrition_repository.dart';
import '../../features/routine/data/berkala_repository.dart';
import '../../features/run/data/run_repository.dart';
import '../../features/sleep/data/sleep_repository.dart';
import '../../features/routine/domain/berkala.dart';
import '../../features/nutrition/domain/food_log.dart';
import '../../features/workout/data/models/workout_session.dart';
import '../../features/workout/data/rest_day_repository.dart';
import '../../features/workout/presentation/workout_providers.dart';
import 'notification_service.dart';
import 'notification_settings_controller.dart';
import 'smart_reminders.dart';

/// Berapa hari ke belakang dipakai untuk menilai "orang ini memang mencatat
/// makanannya". Dua minggu cukup untuk membedakan kebiasaan dari sekali coba.
const int kJendelaKebiasaanHari = 14;

bool _tanggalSama(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Menjadwalkan ulang seluruh pengingat setiap kali datanya atau setelannya
/// berubah.
///
/// Dibuat sebagai provider (bukan `ref.listen` di widget) supaya efeknya ikut
/// berjalan ulang saat dependensinya berubah — mis. user menggeser jam
/// pengingat, menandai sebuah tugas selesai, atau mencatat sesi latihan yang
/// membuat teguran streak malam ini tidak jadi perlu.
///
/// Di web fungsi ini berhenti sebelum menyentuh provider mana pun, jadi
/// perilaku caching di Chrome sama sekali tidak berubah.
final reminderSyncProvider = Provider<void>((ref) {
  final service = ref.watch(notificationServiceProvider);
  if (!service.supported) return;

  final settings = ref.watch(notificationSettingsProvider);

  // Tugas jadi syarat minimal: kalau daftar tugas belum termuat, kemungkinan
  // besar sesi baru dimulai dan menjadwalkan sekarang hanya akan memasang
  // rencana setengah jadi yang sebentar lagi ditimpa.
  final tasks = ref.watch(tasksProvider).value;
  if (tasks == null) return;

  final now = DateTime.now();

  final schedules = ref.watch(classSchedulesProvider).value ?? const <ClassSchedule>[];
  final recurring = ref.watch(recurringExpensesProvider).value ?? const <RecurringExpense>[];
  final foods = ref.watch(foodLogsProvider).value ?? const <FoodLog>[];
  final restDays = ref.watch(restDaysProvider).value ?? const <RestDay>[];
  final activeDates = ref.watch(activeDatesProvider);
  final streak = ref.watch(workoutStreakProvider).value;

  final batasKebiasaan = now.subtract(const Duration(days: kJendelaKebiasaanHari));

  // Dokumen dan kendaraan tidak dijadikan syarat seperti tugas: keduanya boleh
  // kosong selamanya kalau kamu memang tidak memakainya, dan menunggu keduanya
  // termuat akan menahan seluruh penjadwalan.
  final documents = ref.watch(documentsProvider).value ?? const <Document>[];
  final vehicles = ref.watch(vehiclesProvider).value ?? const <Vehicle>[];
  final services = ref.watch(vehicleServicesProvider).value ?? const <ServiceLog>[];
  final berkala = ref.watch(berkalaProvider).value ?? const <RutinitasBerkala>[];

  final input = ReminderInput(
    mingguIni: ringkasMinggu(
      now: now,
      sessions: ref.watch(workoutSessionsProvider).value ?? const [],
      runs: ref.watch(runsProvider).value ?? const [],
      sleeps: ref.watch(sleepLogsProvider).value ?? const [],
      transactions: ref.watch(transactionsProvider).value ?? const [],
      tasks: tasks,
      berkala: berkala,
    ),
    tasks: tasks,
    schedules: schedules,
    recurring: recurring,
    documents: documents,
    vehicles: vehicles,
    services: services,
    berkala: berkala,
    streakHari: streak?.current ?? 0,
    bergerakHariIni: activeDates.any((date) => _tanggalSama(date, now)),
    istirahatHariIni: restDays.any((day) => _tanggalSama(day.restOn, now)),
    pernahCatatMakan: foods.any((food) => food.loggedOn.isAfter(batasKebiasaan)),
    sudahCatatMakanHariIni: foods.any((food) => _tanggalSama(food.loggedOn, now)),
  );

  unawaited(
    service.syncReminders(
      planReminders(data: input, settings: settings, now: now),
      tepatWaktu: settings.tepatWaktu,
    ),
  );
});

/// Angka minggu berjalan (Senin sampai [now]) untuk notifikasi rekap.
RingkasanMinggu ringkasMinggu({
  required DateTime now,
  List<WorkoutSession> sessions = const [],
  List<RunLog> runs = const [],
  List<SleepLog> sleeps = const [],
  List<Transaction> transactions = const [],
  List<AcademicTask> tasks = const [],
  List<RutinitasBerkala> berkala = const [],
}) {
  final senin = awalMinggu(now);
  bool mingguIni(DateTime t) => !t.isBefore(senin) && !t.isAfter(now);

  final tidur = sleeps.where((s) => mingguIni(s.loggedOn)).toList();
  final hariIni = DateTime(now.year, now.month, now.day);

  return RingkasanMinggu(
    sesiLatihan: sessions.where((s) => mingguIni(s.sessionDate)).length,
    lari: runs.where((r) => mingguIni(r.startedAt)).length,
    rataTidurJam: tidur.isEmpty
        ? null
        : tidur.fold<double>(0, (n, s) => n + s.hours) / tidur.length,
    pengeluaran: transactions
        .where((t) => t.kind == TxKind.pengeluaran && mingguIni(t.occurredOn))
        .fold<double>(0, (n, t) => n + t.amount),
    tugasSelesai: tasks.where((t) => t.completedAt != null && mingguIni(t.completedAt!)).length,
    berkalaTerlewat: berkala.where((b) => b.jatuhTempo.isBefore(hariIni)).length,
  );
}
