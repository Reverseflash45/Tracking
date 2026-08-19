/// Catatan bebas.
///
/// Ini tempat untuk hal yang tidak berbentuk tugas, transaksi, atau jadwal.
/// Tanpa tempat seperti ini, satu-satunya cara mencatat sesuatu di app ini
/// adalah memaksanya jadi tugas berdeadline — dan "password wifi kos" bukan
/// tugas, apalagi tugas yang jatuh tempo minggu depan.
class Note {
  const Note({
    required this.id,
    required this.userId,
    this.title,
    this.body = '',
    this.pinned = false,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;

  /// Boleh kosong. Catatan cepat sering langsung isinya, dan memaksa judul
  /// membuat orang berhenti sebelum sempat mencatat apa pun.
  final String? title;

  final String body;

  /// Disematkan ke atas daftar. Yang sering dibuka biasanya cuma dua-tiga
  /// catatan, dan tanpa ini mereka tenggelam tiap kali ada catatan baru.
  final bool pinned;

  final DateTime createdAt;
  final DateTime updatedAt;

  /// Judul yang ditampilkan di daftar.
  ///
  /// Kalau judulnya kosong, baris pertama isinya yang dipakai — itu memang
  /// yang orang tulis lebih dulu, dan menampilkan "Tanpa judul" untuk catatan
  /// yang isinya jelas cuma menyembunyikan isinya sendiri.
  String get judul {
    if (title case final t? when t.trim().isNotEmpty) return t.trim();
    final baris = _barisIsi;
    return baris.isEmpty ? 'Tanpa judul' : baris.first;
  }

  /// Isi yang ditampilkan di bawah judul.
  ///
  /// Baris pertama dibuang kalau dia sedang dipakai jadi judul, supaya tidak
  /// tertulis dua kali di satu kartu.
  String get cuplikan {
    final baris = _barisIsi;
    final mulai = (title == null || title!.trim().isEmpty) ? 1 : 0;
    if (baris.length <= mulai) return '';
    return baris.sublist(mulai).join(' ');
  }

  bool get kosong => (title?.trim().isEmpty ?? true) && body.trim().isEmpty;

  List<String> get _barisIsi => [
        for (final baris in body.split('\n'))
          if (baris.trim().isNotEmpty) baris.trim(),
      ];

  factory Note.fromMap(Map<String, dynamic> map) => Note(
        id: map['id'] as String,
        userId: map['user_id'] as String,
        title: map['title'] as String?,
        body: map['body'] as String? ?? '',
        pinned: map['pinned'] as bool? ?? false,
        createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
        updatedAt: DateTime.parse(map['updated_at'] as String).toLocal(),
      );
}

/// Yang disematkan di atas, sisanya yang terakhir diubah lebih dulu.
///
/// Diurutkan di HP, bukan di query: catatan yang baru disematkan harus langsung
/// naik tanpa menunggu daftarnya diambil ulang dari server.
List<Note> urutkanCatatan(List<Note> catatan) {
  return [...catatan]..sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });
}

/// Saring [catatan] menurut [query].
///
/// Judul dan isi dicari dua-duanya. Untuk catatan bebas, yang diingat orang
/// justru sering ada di tengah isinya — bukan di judul yang mungkin memang
/// tidak pernah diisi.
List<Note> cariCatatan(List<Note> catatan, String query) {
  final cari = query.trim().toLowerCase();
  if (cari.isEmpty) return catatan;
  return [
    for (final note in catatan)
      if ((note.title ?? '').toLowerCase().contains(cari) ||
          note.body.toLowerCase().contains(cari))
        note,
  ];
}
