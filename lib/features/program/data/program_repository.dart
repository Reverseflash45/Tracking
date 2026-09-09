import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../../workout/data/models/workout_template.dart';
import '../../workout/data/workout_repository.dart';
import '../domain/bulk_program.dart';

/// Program yang sedang dijalani, apa adanya dari database.
class ProgramAktif {
  const ProgramAktif({required this.variasi, required this.mulai});

  final VariasiAlat variasi;
  final DateTime mulai;
}

class ProgramRepository {
  ProgramRepository(this._client);

  final SupabaseClient _client;

  /// Null berarti belum memilih program — dan itu keadaan yang sah, bukan
  /// kekosongan yang perlu diisi nilai bawaan. Menebak "pasti tanpa kursi"
  /// berarti halamannya menampilkan program yang tidak pernah kamu pilih.
  Future<ProgramAktif?> fetch(String userId) async {
    final baris = await _client
        .from('workout_programs')
        .select()
        .eq('user_id', userId)
        .maybeSingle();

    if (baris == null) return null;
    return ProgramAktif(
      variasi: VariasiAlat.fromDb(baris['equipment'] as String?),
      mulai: DateTime.parse(baris['started_on'] as String),
    );
  }

  /// Menyimpan pilihan variasi.
  ///
  /// `started_on` cuma diisi saat baris pertama dibuat. Berganti dari versi
  /// kursi ke tanpa kursi bukan memulai program baru — gerakannya menyesuaikan
  /// alat, dan hitungan minggunya tidak seharusnya kembali ke nol.
  Future<void> pilih({
    required String userId,
    required VariasiAlat variasi,
    required bool pertamaKali,
  }) {
    return _client.from('workout_programs').upsert({
      'user_id': userId,
      'program': 'naik_berat',
      'equipment': variasi.dbValue,
      if (pertamaKali) 'started_on': DateTime.now().toIso8601String().substring(0, 10),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'user_id');
  }

  Future<void> berhenti(String userId) {
    return _client.from('workout_programs').delete().eq('user_id', userId);
  }
}

final programRepositoryProvider = Provider<ProgramRepository>((ref) {
  return ProgramRepository(ref.watch(supabaseClientProvider));
});

final programAktifProvider = FutureProvider<ProgramAktif?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  return ref.watch(programRepositoryProvider).fetch(user.id);
});

/// Nama template untuk satu sesi program.
///
/// Variasinya ikut ke dalam nama supaya versi kursi dan versi tanpa kursi tidak
/// saling menimpa kalau kamu pernah memakai keduanya.
String namaTemplate(ProgramNaikBerat program, SesiProgram sesi) =>
    'Naik Berat ${sesi.kode} — ${program.variasi.label}';

/// Ubah [program] jadi template workout supaya bisa dijalankan lewat mesin yang
/// sudah ada: Riwayat, Ulangi Sesi, dan Latihan Terpandu.
///
/// Template yang namanya sudah ada dilewati, bukan dibuat ulang. Menekan
/// tombolnya dua kali adalah hal yang wajar terjadi, dan hasilnya tidak
/// seharusnya dua salinan yang mulai berbeda begitu salah satunya kamu ubah.
///
/// Mengembalikan jumlah template yang benar-benar dibuat.
Future<int> pasangTemplate({
  required WorkoutRepository repo,
  required String userId,
  required ProgramNaikBerat program,
  required List<WorkoutTemplate> sudahAda,
}) async {
  final nama = {for (final t in sudahAda) t.name};
  var dibuat = 0;

  for (final sesi in program.sesi) {
    final judul = namaTemplate(program, sesi);
    if (nama.contains(judul)) continue;

    await repo.addTemplate(
      userId: userId,
      name: judul,
      exercises: [
        for (final g in sesi.gerakan)
          TemplateExercise(
            exerciseName: g.nama,
            type: g.tipe,
            sets: g.set,
            reps: g.rep,
            durationSeconds: g.detik,
            restSeconds: g.istirahatDetik,
            // Bebannya sengaja tidak diisi. Angka yang tepat cuma kamu yang
            // tahu, dan menaruh tebakan di sana berarti kamu mengangkat angka
            // yang dikarang app, bukan angka yang kamu pilih sendiri.
            notes: g.cue,
          ),
      ],
    );
    dibuat++;
  }

  return dibuat;
}
