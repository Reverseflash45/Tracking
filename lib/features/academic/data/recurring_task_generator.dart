import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../domain/recurring_task.dart';
import '../presentation/academic_providers.dart';
import 'academic_repository.dart';

/// Membuat tugas dari template berulang.
///
/// Dijalankan saat app dibuka dan saat kembali dari latar belakang — bukan
/// lewat cron di server. Alasannya sederhana: tugas yang dibuat diam-diam
/// selagi app tidak pernah dibuka tidak menolong siapa pun, dan pemicu di sisi
/// klien tidak memerlukan satu pun infrastruktur tambahan.
///
/// Aman dipanggil berkali-kali. Kejadian yang sudah ada dilewati di sini, dan
/// yang lolos tetap dijaga indeks unik `(recurring_id, recurring_on)` di
/// database — jadi dua HP yang membuka app bersamaan tidak bisa menghasilkan
/// tugas kembar.
class RecurringTaskGenerator {
  RecurringTaskGenerator(this._ref);

  final Ref _ref;

  bool _sedangJalan = false;

  /// Jumlah tugas yang dibuat. 0 berarti semuanya memang sudah ada — atau tidak
  /// ada sinyal, yang di sini sengaja tidak dibedakan: pembuatan tugas bukan
  /// hal yang perlu dilaporkan gagal, dia akan jalan lagi saat app dibuka lagi.
  Future<int> jalankan() async {
    if (_sedangJalan) return 0;
    _sedangJalan = true;

    try {
      final userId = _ref.read(currentUserProvider)?.id;
      if (userId == null) return 0;

      final templates = await _ref.read(recurringTasksProvider.future);
      if (templates.isEmpty) return 0;

      final tasks = await _ref.read(tasksProvider.future);

      final perlu = occurrencesToCreate(
        templates: templates,
        sudahAda: existingOccurrenceKeys(tasks),
        now: DateTime.now(),
      );
      if (perlu.isEmpty) return 0;

      final dibuat =
          await _ref.read(academicRepositoryProvider).createOccurrences(userId, perlu);

      _ref.invalidate(tasksProvider);
      return dibuat;
    } catch (_) {
      return 0;
    } finally {
      _sedangJalan = false;
    }
  }
}

final recurringTaskGeneratorProvider = Provider<RecurringTaskGenerator>(
  RecurringTaskGenerator.new,
);
