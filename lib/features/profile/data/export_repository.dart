import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client_provider.dart';

/// Versi format berkas ekspor. Dinaikkan kalau strukturnya berubah, supaya
/// pembaca berkas lama tahu apa yang dihadapinya.
const int kExportFormatVersion = 1;

/// Tabel yang ikut dicadangkan, beserta kolom pengurut supaya isi berkas
/// stabil dari satu ekspor ke ekspor berikutnya.
///
/// Semua tabel di sini dilindungi RLS, jadi query tanpa filter user pun hanya
/// mengembalikan baris milik akun yang sedang login.
const Map<String, String> _tables = {
  'profiles': 'id',
  'courses': 'created_at',
  'class_schedules': 'day_of_week',
  'tasks': 'deadline',
  'workout_sessions': 'session_date',
  // Tabel ini tidak punya created_at (lihat 0001_init.sql), jadi diurutkan
  // menurut id. Yang penting urutannya stabil, bukan bermakna.
  'workout_exercises': 'id',
  'workout_templates': 'created_at',
  'workout_template_exercises': 'position',
  'body_profiles': 'user_id',
  'weight_logs': 'logged_on',
  'food_logs': 'logged_at',
  'water_logs': 'logged_at',
  'media_items': 'created_at',
};

class ExportResult {
  const ExportResult({required this.json, required this.rowCounts});

  final String json;

  /// Jumlah baris per tabel, dipakai untuk memberi tahu isi berkasnya apa saja.
  final Map<String, int> rowCounts;

  int get totalRows => rowCounts.values.fold(0, (sum, count) => sum + count);
}

class ExportRepository {
  ExportRepository(this._client);

  final SupabaseClient _client;

  /// Mengambil baris mentah dari database, bukan hasil konversi ke model.
  ///
  /// Disengaja: cadangan harus merekam apa yang benar-benar tersimpan. Kalau
  /// lewat model, kolom yang belum dipakai app akan hilang diam-diam dari
  /// cadangan, dan perubahan model di masa depan bisa mengubah isi berkas lama.
  Future<ExportResult> buildExport({String? email}) async {
    final data = <String, List<dynamic>>{};
    final counts = <String, int>{};

    for (final entry in _tables.entries) {
      final rows = await _client.from(entry.key).select().order(entry.value);
      final list = (rows as List).toList();
      data[entry.key] = list;
      counts[entry.key] = list.length;
    }

    final payload = {
      'format_version': kExportFormatVersion,
      'exported_at': DateTime.now().toIso8601String(),
      'app': 'tracking',
      'account_email': ?email,
      'row_counts': counts,
      'data': data,
    };

    return ExportResult(
      json: const JsonEncoder.withIndent('  ').convert(payload),
      rowCounts: counts,
    );
  }
}

final exportRepositoryProvider = Provider<ExportRepository>((ref) {
  return ExportRepository(ref.watch(supabaseClientProvider));
});
