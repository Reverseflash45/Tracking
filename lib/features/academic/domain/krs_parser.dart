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
const String _roomLabels = 'laboratorium|ruangan|ruang|kelas|lab';

/// "R" sendirian baru berarti ruangan kalau diikuti angka: R.301, R 12.
///
/// Sebelumnya `r` ikut jadi salah satu label bebas, dan akibatnya setiap kata
/// berawalan R dianggap penanda ruangan. Pada KRS ini "Rabu Kuliah jam" terbaca
/// sebagai ruangan bernama "abu Kuliah jam". Cacatnya tidak pernah terlihat
/// selama tidak ada satu baris pun yang berhasil dibaca.
final RegExp _roomSingkat = RegExp(r'\br\.?\s*:?\s*(\d[a-z0-9.\-]{0,8})', caseSensitive: false);

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

  final singkat = _roomSingkat.firstMatch(line);
  if (singkat != null) return singkat.group(1)!.trim();

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
  sisa = sisa.replaceAll(_roomSingkat, ' ');

  // Kode mata kuliah seperti "TIF3204" atau "MKU-101" bukan nama.
  sisa = sisa.replaceAll(RegExp(r'\b[A-Z]{2,4}[-\s]?\d{3,5}\b'), ' ');

  // Kode kelas seperti "TI-C2" atau "T-C1". Bentuknya cukup khas — huruf,
  // tanda hubung, huruf, angka — sehingga jarang bertabrakan dengan nama mata
  // kuliah. Kalau ada nama yang ikut terpangkas, itu bagian yang memang
  // diserahkan untuk kamu koreksi sebelum menyimpan.
  sisa = sisa.replaceAll(RegExp(r'\b[A-Za-z]{1,3}-[A-Za-z]?\d{1,3}\b'), ' ');

  // Kata sambungan yang selalu ada di kolom jadwal dan tidak pernah jadi nama.
  // "Praktikum" sengaja tidak ikut: itu memang bagian dari nama mata kuliahnya.
  sisa = sisa.replaceAll(RegExp(r'\b(?:kuliah|kliah|jam)\b', caseSensitive: false), ' ');

  // SKS dan sisa angka berdiri sendiri.
  sisa = sisa.replaceAll(RegExp(r'\b\d+\s*sks\b', caseSensitive: false), ' ');
  sisa = sisa.replaceAll(RegExp(r'(^|\s)\d{1,2}(\s|$)'), ' ');

  return sisa.replaceAll(RegExp(r'[|\t]+'), ' ').replaceAll(RegExp(r'\s{2,}'), ' ').trim();
}

/// Bersihkan sisa tanda baca di ujung nama.
String _cleanName(String raw) {
  return raw.replaceAll(RegExp(r'^[\s.,:;\-–—/]+|[\s.,:;\-–—/]+$'), '').trim();
}

/// Berapa banyak baris OCR yang boleh disatukan jadi satu baris jadwal.
///
/// Tiga sudah cukup untuk kasus terburuk yang pernah ditemui — nama, hari, dan
/// jam terpecah bertiga — dan empat memberi satu baris cadangan. Lebih dari itu
/// justru berbahaya: makin lebar jendelanya, makin besar peluang jam milik
/// baris berikutnya ikut tertarik ke baris ini.
const int kMaksBarisGabung = 4;

/// Apakah baris ini jelas-jelas awal baris jadwal yang baru.
///
/// Bentuknya nomor urut lalu kode mata kuliah: "1  AGI401", "12 SIP375".
/// Penjagaan ini yang mencegah jendela penggabungan menyeberang ke baris
/// berikutnya dan mencuri jamnya.
///
/// Sengaja menuntut kode mata kuliah, bukan cuma angka di depan. Baris sambungan
/// sering juga dimulai angka — "07 2 sks | 13:00" — dan kalau itu dianggap awal
/// baris baru, justru penggabungannya yang tidak pernah terjadi.
bool _awalBarisBaru(String line) =>
    RegExp(r'^\d{1,2}[\s.)]+[A-Za-z]{2,4}\s?\d{3,5}\b').hasMatch(line);

/// Baca satu baris utuh jadi satu jadwal. Null kalau harinya atau jamnya tidak
/// lengkap.
KrsEntry? _bacaBaris(String line) {
  final day = _findDay(line.toLowerCase());
  final time = _findTimeRange(line);
  if (day == null || time == null) return null;

  // Jam selesai sebelum jam mulai berarti salah baca.
  if (time.end.compareTo(time.start) <= 0) return null;

  final name = _cleanName(_stripKnownParts(line));
  if (name.length < 3) return null;

  return KrsEntry(
    courseName: name,
    dayOfWeek: day,
    startTime: time.start,
    endTime: time.end,
    room: _findRoom(line),
  );
}

/// Baca teks OCR jadi daftar jadwal.
///
/// Baris yang tidak punya hari DAN jam sekaligus dilewati. Menebak dari salah
/// satunya saja menghasilkan jadwal karangan yang lebih merepotkan untuk
/// dibersihkan daripada diketik ulang.
///
/// Satu baris tabel tidak selalu jadi satu baris teks. Kolom JADWAL biasanya
/// yang paling panjang, dan OCR memecahnya menurut apa yang terlihat di foto,
/// bukan menurut struktur tabelnya:
///
///     1  AGI401  Agama Islam II  2  TI-C1  Rabu Kuliah jam
///     07 2 sks | 13:00
///     s/d 15:00
///
/// Hari ada di potongan pertama, jam mulai di kedua, jam selesai di ketiga.
/// Dibaca per baris, tidak ada satu pun yang punya hari dan rentang jam
/// sekaligus, jadi hasilnya nol — bukan karena OCR-nya gagal, tapi karena
/// pembacanya menuntut keduanya berada di baris yang sama.
///
/// Karena itu baris digabung dulu. Jendelanya dimulai dari satu baris dan baru
/// melebar kalau belum terbaca, jadi format yang memang sudah rapi tidak ikut
/// terpengaruh.
List<KrsEntry> parseKrs(String rawText) {
  final lines = rawText
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();

  final entries = <KrsEntry>[];
  var i = 0;

  while (i < lines.length) {
    KrsEntry? hasil;
    var terpakai = 1;

    for (var lebar = 1; lebar <= kMaksBarisGabung && i + lebar <= lines.length; lebar++) {
      // Berhenti sebelum menelan baris yang jelas milik jadwal berikutnya.
      if (lebar > 1 && _awalBarisBaru(lines[i + lebar - 1])) break;

      final entry = _bacaBaris(lines.sublist(i, i + lebar).join(' '));
      if (entry != null) {
        hasil = entry;
        terpakai = lebar;
        break;
      }
    }

    if (hasil != null) entries.add(hasil);
    i += terpakai;
  }

  return entries;
}
