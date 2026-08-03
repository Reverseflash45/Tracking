import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/academic/data/models/class_schedule.dart';
import '../../features/academic/presentation/academic_providers.dart';
import '../../features/document/data/document_repository.dart';
import '../../features/document/domain/document.dart';
import '../../features/finance/data/finance_repository.dart';
import '../../features/finance/domain/finance_stats.dart';
import '../../features/vehicle/data/vehicle_repository.dart';
import '../../features/vehicle/domain/vehicle.dart';
import '../../features/nutrition/data/nutrition_repository.dart';
import '../../features/nutrition/domain/food_log.dart';
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

  final input = ReminderInput(
    tasks: tasks,
    schedules: schedules,
    recurring: recurring,
    documents: documents,
    vehicles: vehicles,
    services: services,
    streakHari: streak?.current ?? 0,
    bergerakHariIni: activeDates.any((date) => _tanggalSama(date, now)),
    istirahatHariIni: restDays.any((day) => _tanggalSama(day.restOn, now)),
    pernahCatatMakan: foods.any((food) => food.loggedOn.isAfter(batasKebiasaan)),
    sudahCatatMakanHariIni: foods.any((food) => _tanggalSama(food.loggedOn, now)),
  );

  unawaited(
    service.syncReminders(
      planReminders(data: input, settings: settings, now: now),
    ),
  );
});
