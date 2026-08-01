/// Menebak baris jadwal kuliah dari teks hasil OCR foto KRS.
///
/// Sama seperti pembaca struk: ini penebak, bukan pembaca. Format KRS berbeda
/// tiap kampus, tiap fakultas, bahkan tiap semester. Yang dikerjakan di sini
/// hanya menemukan potongan yang bentuknya jelas — hari dan jam — lalu
/// menyerahkan sisanya untuk kamu koreksi.
library;

/// Nama hari beserta ejaan yang sering muncul di KRS.
const Map<int, List<String>> _dayAliases = {
  1: ['senin', 'monday', 'sen'],
  2: ['selasa', 'tuesday', 'sel'],
  3: ['rabu', 'wednesday', 'rab'],
  4: ['kamis', 'thursday', 'kam'],
  5: ['jumat', "jum'at", 'jum at', 'friday', 'jum'],
  6: ['sabtu', 'saturday', 'sab'],
  7: ['minggu', 'ahad', 'sunday', 'min'],
};

/// Satu baris jadwal yang berhasil ditebak.
class KrsEntry {
  const KrsEntry({
    required this.courseName,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    this.room,
    this.lecturer,
  });

  final String courseName;

  /// 1 = Senin ... 7 = Minggu.
  final int dayOfWeek;

  /// Format 'HH:mm'.
  final String startTime;
  final String endTime;

  final String? room;
  final String? lecturer;

  KrsEntry copyWith({
    String? courseName,
    int? dayOfWeek,
    String? startTime,
    String? endTime,
    String? room,
    String? lecturer,
  }) {
    return KrsEntry(
      courseName: courseName ?? this.courseName,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      room: room ?? this.room,
      lecturer: lecturer ?? this.lecturer,
    );
  }
}

int? _findDay(String lower) {
  for (final entry in _dayAliases.entries) {
    for (final alias in entry.value) {
      // Dicocokkan sebagai kata utuh supaya "sen" tidak ikut tertangkap di
      // dalam kata seperti "sensor" atau "presentasi".
      final pattern = RegExp(r'(^|[^a-z])' + RegExp.escape(alias) + r'([^a-z]|$)');
      if (pattern.hasMatch(lower)) return entry.key;
    }
  }
  return null;
}

String _normalizeTime(String hour, String minute) {
  final h = int.parse(hour).clamp(0, 23);
  return '${h.toString().padLeft(2, '0')}:$minute';
}

/// Cari rentang jam, mis. "07:30 - 09:10" atau "0730-0910".
({String start, String end})? _findTimeRange(String line) {
  final berpemisah = RegExp(
    r'(\d{1,2})[.:](\d{2})\s*(?:-|s/d|s\.d\.?|sd|hingga|—|–)\s*(\d{1,2})[.:](\d{2})',
  ).firstMatch(line);

  if (berpemisah != null) {
    return (
      start: _normalizeTime(berpemisah.group(1)!, berpemisah.group(2)!),
      end: _normalizeTime(berpemisah.group(3)!, berpemisah.group(4)!),
    );
  }

  // Bentuk tanpa titik dua: 0730-0910.
  final rapat = RegExp(r'\b(\d{2})(\d{2})\s*[-–—]\s*(\d{2})(\d{2})\b').firstMatch(line);
  if (rapat != null) {
    final h1 = int.parse(rapat.group(1)!);
    final h2 = int.parse(rapat.group(3)!);
    final m1 = int.parse(rapat.group(2)!);
    final m2 = int.parse(rapat.group(4)!);
    if (h1 <= 23 && h2 <= 23 && m1 <= 59 && m2 <= 59) {
      return (
        start: _normalizeTime(rapat.group(1)!, rapat.group(2)!),
        end: _normalizeTime(rapat.group(3)!, rapat.group(4)!),
      );
    }
  }

  return null;
}

/// Label ruangan, diurutkan dari yang terpanjang.
///
/// Alternasi regex memilih yang pertama cocok, bukan yang terpanjang. Kalau
/// `r` didahulukan, "Ruang A1" akan cocok di huruf R lalu menangkap
/// "uang A1" sebagai nama ruangannya.
const String _roomLabels = 'laboratorium|ruangan|ruang|kelas|lab|r';

/// Cari kode ruangan, mis. "R.301", "Ruang A1", "Lab Komputer".
String? _findRoom(String line) {
  final berlabel = RegExp(
    '\\b(?:$_roomLabels)\\.?\\s*:?\\s*([a-z0-9][a-z0-9.\\- ]{0,14})',
    caseSensitive: false,
  ).firstMatch(line);

  if (berlabel != null) {
    final hasil = berlabel.group(1)!.trim();
    if (hasil.isNotEmpty) return hasil;
  }
  return null;
}

/// Buang potongan yang sudah dikenali supaya sisanya bisa dipakai sebagai
/// nama mata kuliah.
String _stripKnownParts(String line) {
  var sisa = line;

  sisa = sisa.replaceAll(
    RegExp(
      r'(\d{1,2})[.:](\d{2})\s*(?:-|s/d|s\.d\.?|sd|hingga|—|–)\s*(\d{1,2})[.:](\d{2})',
    ),
    ' ',
  );
  sisa = sisa.replaceAll(RegExp(r'\b\d{2}\d{2}\s*[-–—]\s*\d{2}\d{2}\b'), ' ');

  for (final aliases in _dayAliases.values) {
    for (final alias in aliases) {
      sisa = sisa.replaceAll(
        RegExp(r'(^|[^a-zA-Z])' + RegExp.escape(alias) + r'([^a-zA-Z]|$)',
            caseSensitive: false),
        ' ',
      );
    }
  }

  sisa = sisa.replaceAll(
    RegExp(
      '\\b(?:$_roomLabels)\\.?\\s*:?\\s*[a-z0-9][a-z0-9.\\-]{0,14}',
      caseSensitive: false,
    ),
    ' ',
  );

  // Kode mata kuliah seperti "TIF3204" atau "MKU-101" bukan nama.
  sisa = sisa.replaceAll(RegExp(r'\b[A-Z]{2,4}[-\s]?\d{3,5}\b'), ' ');

  // SKS dan sisa angka berdiri sendiri.
  sisa = sisa.replaceAll(RegExp(r'\b\d+\s*sks\b', caseSensitive: false), ' ');
  sisa = sisa.replaceAll(RegExp(r'(^|\s)\d{1,2}(\s|$)'), ' ');

  return sisa.replaceAll(RegExp(r'[|\t]+'), ' ').replaceAll(RegExp(r'\s{2,}'), ' ').trim();
}

/// Bersihkan sisa tanda baca di ujung nama.
String _cleanName(String raw) {
  return raw.replaceAll(RegExp(r'^[\s.,:;\-–—/]+|[\s.,:;\-–—/]+$'), '').trim();
}

/// Baca teks OCR jadi daftar jadwal.
///
/// Baris yang tidak punya hari DAN jam sekaligus dilewati. Menebak dari salah
/// satunya saja menghasilkan jadwal karangan yang lebih merepotkan untuk
/// dibersihkan daripada diketik ulang.
List<KrsEntry> parseKrs(String rawText) {
  final lines = rawText
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();

  final entries = <KrsEntry>[];

  for (final line in lines) {
    final lower = line.toLowerCase();

    final day = _findDay(lower);
    final time = _findTimeRange(line);
    if (day == null || time == null) continue;

    // Jam selesai sebelum jam mulai berarti salah baca.
    if (time.end.compareTo(time.start) <= 0) continue;

    final name = _cleanName(_stripKnownParts(line));
    if (name.length < 3) continue;

    entries.add(KrsEntry(
      courseName: name,
      dayOfWeek: day,
      startTime: time.start,
      endTime: time.end,
      room: _findRoom(line),
    ));
  }

  return entries;
}
