import 'krs_parser.dart';

/// Hasil pembacaan KRS oleh AI (Edge Function "baca-krs").
class HasilBacaKrs {
  const HasilBacaKrs({required this.entries, this.catatan = ''});

  /// Baca jawaban server. Baris yang tidak lengkap dibuang di sini juga,
  /// bukan hanya di server: app yang lebih baru bisa saja bicara dengan
  /// fungsi versi lama, dan yang disimpan ke database harus tetap sah.
  factory HasilBacaKrs.fromJson(Map<String, dynamic> json) {
    final mentah = json['jadwal'];
    final entries = <KrsEntry>[
      if (mentah is List)
        for (final item in mentah)
          if (item is Map) ?krsEntryDariJson(Map<String, dynamic>.from(item)),
    ];
    final catatan = json['catatan'];
    return HasilBacaKrs(
      entries: entries,
      catatan: catatan is String ? catatan.trim() : '',
    );
  }

  final List<KrsEntry> entries;

  /// Bagian yang tidak terbaca atau perlu diperiksa, dari AI.
  final String catatan;
}

/// Satu baris jadwal dari AI; null kalau hari atau jamnya tidak sah.
KrsEntry? krsEntryDariJson(Map<String, dynamic> json) {
  final nama = _teks(json['nama']);
  final hari = (json['hari'] as num?)?.toInt();
  final mulai = _jam(json['mulai']);
  final selesai = _jam(json['selesai']);

  if (nama == null || nama.length < 2) return null;
  if (hari == null || hari < 1 || hari > 7) return null;
  if (mulai == null || selesai == null || selesai.compareTo(mulai) <= 0) return null;

  final sks = (json['sks'] as num?)?.toInt();
  return KrsEntry(
    courseName: nama,
    dayOfWeek: hari,
    startTime: mulai,
    endTime: selesai,
    room: _teks(json['ruang']),
    lecturer: _teks(json['dosen']),
    courseCode: _teks(json['kode'])?.toUpperCase(),
    classCode: _teks(json['kelas']),
    // Kolom courses.sks dibatasi 0–12 di database.
    sks: sks != null && sks > 0 && sks <= 12 ? sks : null,
  );
}

/// String yang sudah dirapikan, atau null kalau kosong. Server mengirim ""
/// untuk kolom yang tidak ada di KRS.
String? _teks(Object? value) {
  if (value is! String) return null;
  final rapi = value.replaceAll(RegExp(r'\s+'), ' ').trim();
  return rapi.isEmpty ? null : rapi;
}

/// "7.30", "07:30", "07:30:00" → "07:30"; null kalau bukan jam yang sah.
String? _jam(Object? value) {
  if (value is! String) return null;
  final cocok = RegExp(r'^(\d{1,2})[.:](\d{2})(?::\d{2})?$').firstMatch(value.trim());
  if (cocok == null) return null;
  final h = int.parse(cocok.group(1)!);
  final m = int.parse(cocok.group(2)!);
  if (h > 23 || m > 59) return null;
  return '${h.toString().padLeft(2, '0')}:${cocok.group(2)}';
}
