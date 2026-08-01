/// Antrean catatan yang belum sempat terkirim ke server.
///
/// Kasus yang paling nyata: selesai lari 10 km di jalur tanpa sinyal. Tanpa
/// antrean, tombol simpan gagal dan begitu kamu keluar halaman, satu jam
/// larimu hilang.
///
/// **Hanya untuk catatan baru (insert).** Mengubah dan menghapus tetap butuh
/// sinyal, dan itu disengaja: menunda perubahan berarti harus menebak mana
/// yang menang kalau baris yang sama juga berubah di tempat lain. Menebak
/// salah di situ artinya diam-diam menimpa data — harga yang tidak sebanding
/// dengan kenyamanan mengedit tanpa sinyal.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase/supabase_client_provider.dart';

class PendingWrite {
  const PendingWrite({
    required this.id,
    required this.table,
    required this.payload,
    required this.queuedAt,
    required this.label,
  });

  final String id;
  final String table;
  final Map<String, dynamic> payload;
  final DateTime queuedAt;

  /// Keterangan singkat untuk ditampilkan, misal "Lari 5,2 km".
  final String label;

  factory PendingWrite.fromJson(Map<String, dynamic> json) => PendingWrite(
        id: json['id'] as String,
        table: json['table'] as String,
        payload: Map<String, dynamic>.from(json['payload'] as Map),
        queuedAt: DateTime.parse(json['queued_at'] as String),
        label: json['label'] as String? ?? 'Catatan',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'table': table,
        'payload': payload,
        'queued_at': queuedAt.toIso8601String(),
        'label': label,
      };
}

/// Hasil satu kali pengiriman ulang.
class FlushResult {
  const FlushResult({required this.terkirim, required this.tersisa});

  final int terkirim;
  final int tersisa;
}

class PendingWriteQueue {
  PendingWriteQueue(this._client);

  final SupabaseClient _client;

  File? _file;
  bool _flushing = false;

  bool get supported => !kIsWeb;

  Future<File> _antreanFile() async {
    final ready = _file;
    if (ready != null) return ready;
    final base = await getApplicationDocumentsDirectory();
    return _file = File('${base.path}/pending_writes.json');
  }

  Future<List<PendingWrite>> pending() async {
    if (!supported) return const [];
    try {
      final file = await _antreanFile();
      if (!await file.exists()) return const [];

      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! List) return const [];
      return [
        for (final item in decoded)
          PendingWrite.fromJson(Map<String, dynamic>.from(item as Map)),
      ];
    } catch (e) {
      debugPrint('PendingWriteQueue.pending gagal: $e');
      return const [];
    }
  }

  Future<void> _tulis(List<PendingWrite> items) async {
    final file = await _antreanFile();
    await file.writeAsString(jsonEncode([for (final i in items) i.toJson()]));
  }

  /// Coba kirim sekarang; kalau gagal, masuk antrean.
  ///
  /// Mengembalikan true kalau berhasil langsung terkirim, false kalau ditunda.
  /// Melempar kalau gagal DAN antrean tidak tersedia — kegagalan yang tidak
  /// bisa ditunda tidak boleh terlihat seperti berhasil.
  Future<bool> submit({
    required String table,
    required Map<String, dynamic> payload,
    required String label,
  }) async {
    try {
      await _client.from(table).insert(payload);
      return true;
    } catch (error) {
      if (!supported) rethrow;

      final items = await pending();
      items.add(PendingWrite(
        id: '${DateTime.now().microsecondsSinceEpoch}',
        table: table,
        payload: payload,
        queuedAt: DateTime.now(),
        label: label,
      ));
      try {
        await _tulis(items);
      } catch (e) {
        debugPrint('Gagal menulis antrean: $e');
        // Antreannya sendiri gagal ditulis, jadi catatan ini benar-benar
        // hilang kalau kita diam. Lempar kegagalan aslinya.
        rethrow;
      }
      return false;
    }
  }

  /// Kirim ulang seluruh antrean. Aman dipanggil berkali-kali.
  Future<FlushResult> flush() async {
    if (!supported || _flushing) {
      return FlushResult(terkirim: 0, tersisa: (await pending()).length);
    }

    _flushing = true;
    try {
      final items = await pending();
      if (items.isEmpty) return const FlushResult(terkirim: 0, tersisa: 0);

      final sisa = <PendingWrite>[];
      var terkirim = 0;

      for (var i = 0; i < items.length; i++) {
        try {
          await _client.from(items[i].table).insert(items[i].payload);
          terkirim++;
        } catch (e) {
          // Berhenti di kegagalan pertama: kalau sinyalnya memang mati,
          // mencoba sisanya cuma menghabiskan waktu. Yang belum sempat dicoba
          // ikut disimpan utuh, urutannya tidak berubah.
          debugPrint('Antrean ${items[i].table} belum terkirim: $e');
          sisa.addAll(items.sublist(i));
          break;
        }
      }

      await _tulis(sisa);
      return FlushResult(terkirim: terkirim, tersisa: sisa.length);
    } finally {
      _flushing = false;
    }
  }

  /// Buang satu catatan dari antrean, dipakai kalau kamu memilih membatalkan.
  Future<void> hapus(String id) async {
    final items = await pending();
    await _tulis(items.where((item) => item.id != id).toList());
  }
}

final pendingWriteQueueProvider = Provider<PendingWriteQueue>((ref) {
  return PendingWriteQueue(ref.watch(supabaseClientProvider));
});

/// Isi antrean saat ini. Di-invalidate setiap kali ada yang masuk atau keluar.
final pendingWritesProvider = FutureProvider<List<PendingWrite>>((ref) async {
  return ref.watch(pendingWriteQueueProvider).pending();
});
