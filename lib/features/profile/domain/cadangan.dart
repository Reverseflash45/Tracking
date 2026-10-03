/// Format berkas cadangan dan persiapan memulihkannya.
///
/// Fungsi di sini murni — tidak menyentuh jaringan atau berkas — supaya
/// aturan yang menentukan apa yang ditulis ulang ke database bisa diuji.
library;

/// Versi format berkas. Dinaikkan kalau strukturnya berubah, supaya pembaca
/// berkas lama tahu apa yang dihadapinya.
///
/// Versi 2 menambah 13 tabel yang dulu terlewat (keuangan, lari, tidur,
/// rutinitas berkala, dan lainnya). Berkas versi 1 tetap bisa dipulihkan;
/// isinya saja yang lebih sedikit.
const int kExportFormatVersion = 2;

/// Tabel yang dicadangkan, DALAM URUTAN PEMULIHAN: induk sebelum anak, supaya
/// foreign key-nya sudah ada saat barisnya ditulis. Nilainya kolom pengurut
/// saat ekspor, supaya isi berkas stabil dari satu ekspor ke berikutnya.
///
/// Semua tabel dilindungi RLS, jadi query tanpa filter user pun hanya
/// mengembalikan baris milik akun yang sedang login.
///
/// Yang TIDAK ikut: berkas di Storage (foto progres, lampiran dokumen, foto
/// profil) — cadangan ini hanya data, bukan gambarnya — dan crash_reports.
const Map<String, String> kTabelCadangan = {
  'profiles': 'id',
  'body_profiles': 'user_id',
  'finance_settings': 'user_id',
  'workout_programs': 'user_id',
  'courses': 'created_at',
  'class_schedules': 'day_of_week',
  'recurring_tasks': 'id',
  'tasks': 'deadline',
  'attendance': 'meeting_date',
  'grade_components': 'id',
  'workout_templates': 'created_at',
  'workout_template_exercises': 'position',
  'workout_sessions': 'session_date',
  // Tabel ini tidak punya created_at (lihat 0001_init.sql), jadi diurutkan
  // menurut id. Yang penting urutannya stabil, bukan bermakna.
  'workout_exercises': 'id',
  'rest_days': 'id',
  'runs': 'id',
  'weight_logs': 'logged_on',
  'food_logs': 'logged_at',
  'water_logs': 'logged_at',
  'sleep_logs': 'id',
  'progress_photos': 'id',
  'transactions': 'id',
  'recurring_expenses': 'id',
  'goals': 'id',
  'wishlist_items': 'id',
  'media_items': 'created_at',
  'vehicles': 'created_at',
  'vehicle_services': 'done_on',
  'documents': 'created_at',
  'notes': 'created_at',
  'routines': 'day_of_week',
  'periodic_routines': 'id',
  'periodic_routine_logs': 'id',
};

/// Tabel yang barisnya diidentifikasi oleh `user_id` sendiri (satu baris per
/// akun), bukan oleh kolom `id`.
const Set<String> _tabelPerAkun = {'body_profiles', 'finance_settings', 'workout_programs'};

/// Isi berkas cadangan yang sudah diperiksa dan siap ditulis ke database.
class RencanaPulihkan {
  const RencanaPulihkan({
    required this.formatVersion,
    required this.perTabel,
    this.exportedAt,
    this.email,
    this.tabelTakDikenal = const [],
  });

  final int formatVersion;
  final DateTime? exportedAt;
  final String? email;

  /// Baris per tabel, sudah dalam urutan pemulihan dan sudah ditulis ulang
  /// ke akun yang sedang login.
  final Map<String, List<Map<String, dynamic>>> perTabel;

  /// Tabel di berkas yang tidak dikenal versi app ini; dilewati.
  final List<String> tabelTakDikenal;

  int get totalBaris => perTabel.values.fold(0, (n, rows) => n + rows.length);
}

/// Galat berkas cadangan, dengan pesan yang layak ditampilkan.
class CadanganTidakSah implements Exception {
  const CadanganTidakSah(this.pesan);
  final String pesan;

  @override
  String toString() => pesan;
}

/// Periksa isi berkas cadangan dan siapkan untuk dipulihkan ke [userId].
///
/// Kolom pemilik (`user_id`, dan `id` di profiles) ditulis ulang ke akun yang
/// sedang login. Itu yang membuat cadangan bisa dipulihkan ke akun atau
/// project Supabase baru — skenario yang paling butuh cadangan, misalnya
/// project lama terhapus. Tanpa penulisan ulang, RLS menolak semua barisnya.
RencanaPulihkan siapkanPulihkan(Object? json, {required String userId}) {
  if (json is! Map) {
    throw const CadanganTidakSah('Berkas ini bukan cadangan Tracking.');
  }
  if (json['app'] != 'tracking' || json['data'] is! Map) {
    throw const CadanganTidakSah('Berkas ini bukan cadangan Tracking.');
  }

  final versi = json['format_version'];
  if (versi is! int || versi < 1) {
    throw const CadanganTidakSah('Versi berkas cadangan tidak dikenali.');
  }
  if (versi > kExportFormatVersion) {
    throw const CadanganTidakSah(
      'Cadangan ini dibuat oleh versi app yang lebih baru. Perbarui app dulu.',
    );
  }

  final data = json['data'] as Map;
  final perTabel = <String, List<Map<String, dynamic>>>{};

  for (final tabel in kTabelCadangan.keys) {
    final mentah = data[tabel];
    if (mentah is! List || mentah.isEmpty) continue;

    final rows = <Map<String, dynamic>>[];
    for (final row in mentah) {
      if (row is! Map) continue;
      final baris = Map<String, dynamic>.from(row);
      if (tabel == 'profiles') {
        baris['id'] = userId;
      } else if (baris.containsKey('user_id') || _tabelPerAkun.contains(tabel)) {
        baris['user_id'] = userId;
      }
      rows.add(baris);
    }
    // profiles cuma boleh satu baris: milik akun ini.
    if (tabel == 'profiles' && rows.length > 1) rows.removeRange(1, rows.length);
    if (rows.isNotEmpty) perTabel[tabel] = rows;
  }

  final exportedAt = json['exported_at'];
  final email = json['account_email'];
  return RencanaPulihkan(
    formatVersion: versi,
    exportedAt: exportedAt is String ? DateTime.tryParse(exportedAt) : null,
    email: email is String ? email : null,
    perTabel: perTabel,
    tabelTakDikenal: [
      for (final key in data.keys)
        if (key is String && !kTabelCadangan.containsKey(key)) key,
    ],
  );
}

/// Nama tabel dalam bahasa sehari-hari, untuk ringkasan sebelum memulihkan.
String labelTabel(String tabel) => switch (tabel) {
      'profiles' => 'Profil',
      'body_profiles' => 'Data tubuh',
      'finance_settings' => 'Setelan keuangan',
      'workout_programs' => 'Program latihan',
      'courses' => 'Mata kuliah',
      'class_schedules' => 'Jadwal kuliah',
      'recurring_tasks' => 'Tugas berulang',
      'tasks' => 'Tugas',
      'attendance' => 'Absensi',
      'grade_components' => 'Komponen nilai',
      'workout_templates' => 'Template latihan',
      'workout_template_exercises' => 'Isi template latihan',
      'workout_sessions' => 'Sesi latihan',
      'workout_exercises' => 'Gerakan latihan',
      'rest_days' => 'Hari istirahat',
      'runs' => 'Lari',
      'weight_logs' => 'Berat badan',
      'food_logs' => 'Catatan makan',
      'water_logs' => 'Catatan minum',
      'sleep_logs' => 'Tidur',
      'progress_photos' => 'Foto progres (datanya)',
      'transactions' => 'Transaksi',
      'recurring_expenses' => 'Pengeluaran rutin',
      'goals' => 'Target',
      'wishlist_items' => 'Wishlist',
      'media_items' => 'Watchlist',
      'vehicles' => 'Kendaraan',
      'vehicle_services' => 'Servis kendaraan',
      'documents' => 'Dokumen',
      'notes' => 'Catatan',
      'routines' => 'Rutinitas',
      'periodic_routines' => 'Rutinitas berkala',
      'periodic_routine_logs' => 'Riwayat rutinitas berkala',
      _ => tabel,
    };
