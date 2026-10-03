import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../domain/cadangan.dart';

export '../domain/cadangan.dart' show kExportFormatVersion;

class ExportResult {
  const ExportResult({required this.json, required this.rowCounts});

  final String json;

  /// Jumlah baris per tabel, dipakai untuk memberi tahu isi berkasnya apa saja.
  final Map<String, int> rowCounts;

  int get totalRows => rowCounts.values.fold(0, (sum, count) => sum + count);
}

/// Hasil memulihkan satu cadangan.
class HasilPulihkan {
  const HasilPulihkan({required this.dipulihkan, required this.gagal});

  /// Baris yang berhasil ditulis, per tabel.
  final Map<String, int> dipulihkan;

  /// Baris yang ditolak database, per tabel — biasanya karena bentrok dengan
  /// data yang sudah ada (misalnya dua catatan tidur di tanggal yang sama).
  final Map<String, int> gagal;

  int get totalDipulihkan => dipulihkan.values.fold(0, (n, x) => n + x);
  int get totalGagal => gagal.values.fold(0, (n, x) => n + x);
}

/// Berapa baris dikirim dalam satu upsert.
const int _ukuranKelompok = 200;

class ExportRepository {
  ExportRepository(this._client);

  final SupabaseClient _client;

  /// Mengambil baris mentah dari database, bukan hasil konversi ke model.
  ///
  /// Disengaja: cadangan harus merekam apa yang benar-benar tersimpan. Kalau
  /// lewat model, kolom yang belum dipakai app akan hilang diam-diam dari
  /// cadangan, dan perubahan model di masa depan bisa mengubah isi berkas lama.
  ///
  /// [rapi] false menghasilkan JSON tanpa spasi — untuk cadangan otomatis yang
  /// disimpan di HP dan tidak perlu dibaca manusia.
  Future<ExportResult> buildExport({String? email, bool rapi = true}) async {
    final data = <String, List<dynamic>>{};
    final counts = <String, int>{};

    for (final entry in kTabelCadangan.entries) {
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
      json: rapi ? const JsonEncoder.withIndent('  ').convert(payload) : jsonEncode(payload),
      rowCounts: counts,
    );
  }

  /// Tulis isi cadangan ke database.
  ///
  /// Sifatnya MENGGABUNG, bukan mengganti: baris di cadangan ditulis ulang
  /// (yang sudah ada ditimpa versi cadangan), dan data yang dibuat setelah
  /// cadangan dibuat tidak disentuh. Tidak ada yang dihapus.
  ///
  /// Satu baris yang ditolak tidak boleh menggagalkan semuanya. Kalau satu
  /// kelompok gagal, kelompok itu diulang baris per baris supaya hanya baris
  /// yang bermasalah yang terlewat.
  Future<HasilPulihkan> pulihkan(
    RencanaPulihkan rencana, {
    void Function(String tabel, int selesai, int total)? onProgress,
  }) async {
    final dipulihkan = <String, int>{};
    final gagal = <String, int>{};
    final total = rencana.totalBaris;
    var selesai = 0;

    for (final entry in rencana.perTabel.entries) {
      final tabel = entry.key;
      final rows = entry.value;

      for (var i = 0; i < rows.length; i += _ukuranKelompok) {
        final kelompok = rows.sublist(i, (i + _ukuranKelompok).clamp(0, rows.length));
        try {
          await _client.from(tabel).upsert(kelompok);
          dipulihkan[tabel] = (dipulihkan[tabel] ?? 0) + kelompok.length;
        } on PostgrestException {
          for (final row in kelompok) {
            try {
              await _client.from(tabel).upsert(row);
              dipulihkan[tabel] = (dipulihkan[tabel] ?? 0) + 1;
            } on PostgrestException {
              gagal[tabel] = (gagal[tabel] ?? 0) + 1;
            }
          }
        }
        selesai += kelompok.length;
        onProgress?.call(tabel, selesai, total);
      }
    }

    return HasilPulihkan(dipulihkan: dipulihkan, gagal: gagal);
  }
}

final exportRepositoryProvider = Provider<ExportRepository>((ref) {
  return ExportRepository(ref.watch(supabaseClientProvider));
});
