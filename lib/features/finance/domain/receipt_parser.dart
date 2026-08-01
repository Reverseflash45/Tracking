/// Menebak isi struk dari teks hasil OCR.
///
/// Ini penebak, bukan pembaca. Struk warung, minimarket, dan kafe formatnya
/// berbeda total — tidak ada aturan yang benar untuk semuanya. Karena itu
/// hasilnya SELALU ditampilkan di form untuk kamu koreksi sebelum tersimpan,
/// tidak pernah langsung masuk catatan.
library;

/// Kata kunci yang mendahului angka total, diurutkan dari yang paling
/// meyakinkan. Struk sering memuat beberapa sekaligus ("SUBTOTAL", "TOTAL",
/// "TUNAI", "KEMBALI") jadi urutan ini yang menentukan mana yang menang.
const List<String> _totalKeywords = [
  'grand total',
  // Struk digital (ShopeeFood, GoFood, m-banking) memakai frasa yang lebih
  // panjang. Ditaruh sebelum 'total' polos supaya yang lebih spesifik menang.
  'total pembayaran',
  'total tagihan',
  'total pesanan',
  'total bayar',
  'total belanja',
  'total harga',
  'jumlah bayar',
  'total',
  'jumlah',
];

/// Kata yang menandakan angka di barisnya BUKAN yang kita cari, meski
/// mengandung kata kunci di atas. "Kembali" adalah uang kembalian, dan
/// "subtotal" belum termasuk pajak.
const List<String> _rejectKeywords = [
  'kembali',
  'kembalian',
  'sub total',
  'subtotal',
  'total item',
  'total qty',
  'total diskon',
  'diskon',
  'ppn',
  'pajak',
  'npwp',
  // Struk digital memajang angka lain yang bukan uang keluar: koin/poin hadiah
  // dan "total hemat" dari promo.
  'koin',
  'poin',
  'hemat',
  'cashback',
];

/// Kata yang menandakan sebuah baris adalah judul layar atau tombol aplikasi,
/// bukan nama tempat.
///
/// Struk digital tidak dimulai dengan nama toko seperti struk kertas — bagian
/// atasnya penuh judul halaman ("Rincian Pesananmu") dan ajakan ("Tambah
/// ShopeeFood ke Layar Utama"). Tanpa saringan ini, judul halaman itulah yang
/// tercatat sebagai nama tempat.
const List<String> _notMerchant = [
  'rincian',
  'detail',
  'ringkasan',
  'pesananmu',
  'pesanan saya',
  'riwayat',
  'layar utama',
  'struk',
  'nota',
  'invoice',
  'receipt',
  'faktur',
  'berhasil',
  'selesai',
  'terima kasih',
  'pembayaran',
  'metode',
  'total',
  'subtotal',
  'pesan lagi',
  'beli lagi',
  'bantuan',
  'tambah',
  'lihat',
  'kembali',
];

/// Berapa banyak baris teratas yang dianggap bagian kepala struk.
///
/// Lebih longgar daripada struk kertas karena tangkapan layar menyisipkan
/// beberapa baris hiasan (jam, sinyal, judul halaman) sebelum isi sebenarnya.
const int _merchantSearchLines = 8;

/// Batas kandidat nominal yang ditawarkan. Lebih dari ini bukan membantu
/// memilih, tapi memindahkan pekerjaan mencari dari struk ke layar.
const int _maxCandidates = 6;

final RegExp _numberPattern = RegExp(r'\d[\d.,]*');

class ReceiptGuess {
  const ReceiptGuess({
    this.total,
    this.date,
    this.merchant,
    this.candidates = const [],
    this.rawLines = const [],
  });

  /// Nominal total. Null kalau tidak ada yang meyakinkan.
  final double? total;

  final DateTime? date;

  /// Nama tempat, biasanya baris pertama struk.
  final String? merchant;

  /// Semua nominal yang benar-benar tertulis di struk, dari yang terbesar.
  ///
  /// Dipakai kalau [total] tidak ketemu. Menawarkan angka yang memang ada di
  /// struk untuk dipilih itu jujur; memilihkan salah satunya sendiri tanpa
  /// petunjuk kata kunci itu menebak.
  final List<double> candidates;

  /// Seluruh baris hasil OCR, ditampilkan supaya kamu bisa mengecek sendiri
  /// kalau tebakannya meleset.
  final List<String> rawLines;

  bool get kosong => total == null && date == null && merchant == null;
}

/// Ubah teks angka gaya Indonesia jadi double.
///
/// Rp15.000 dan Rp15,000 sama-sama lima belas ribu. Yang membedakan pemisah
/// ribuan dari desimal adalah jumlah digit setelahnya: tepat dua digit di
/// akhir berarti desimal, selain itu pemisah ribuan.
double? parseRupiah(String raw) {
  var text = raw.toLowerCase().replaceAll(RegExp(r'(rp|idr)\.?'), '');
  text = text.replaceAll(RegExp(r'[^0-9.,-]'), '').trim();
  if (text.isEmpty) return null;

  // Nominal negatif tidak masuk akal di struk.
  if (text.startsWith('-')) return null;

  final lastDot = text.lastIndexOf('.');
  final lastComma = text.lastIndexOf(',');
  final lastSep = lastDot > lastComma ? lastDot : lastComma;

  if (lastSep == -1) return double.tryParse(text);

  final digitsAfter = text.length - lastSep - 1;
  if (digitsAfter == 2) {
    // Dua digit di belakang: perlakukan sebagai desimal.
    final whole = text.substring(0, lastSep).replaceAll(RegExp(r'[.,]'), '');
    final frac = text.substring(lastSep + 1);
    return double.tryParse('$whole.$frac');
  }

  return double.tryParse(text.replaceAll(RegExp(r'[.,]'), ''));
}

/// Angka yang menempel pada '/', ':', atau '-' hampir pasti potongan tanggal
/// atau jam, bukan nominal. Tanpa ini "01/08/2026" menyumbang 2026 sebagai
/// harga, dan itu angka yang cukup masuk akal untuk lolos tanpa dicurigai.
bool _partOfDateOrTime(String line, RegExpMatch match) {
  const separators = {'/', ':', '-'};
  final before = match.start > 0 ? line[match.start - 1] : '';
  final after = match.end < line.length ? line[match.end] : '';
  return separators.contains(before) || separators.contains(after);
}

/// Nominal yang masuk akal sebagai harga di sebuah baris.
Iterable<double> _amountsIn(String line) sync* {
  for (final match in _numberPattern.allMatches(line)) {
    if (_partOfDateOrTime(line, match)) continue;
    final value = parseRupiah(match.group(0)!);
    if (value == null) continue;
    // Angka satu-dua digit hampir selalu kuantitas, bukan harga.
    if (value < 100) continue;
    yield value;
  }
}

/// Ambil nominal terbesar dari sebuah baris. Baris total sering berbentuk
/// "TOTAL 3 15.000" — jumlah item ikut tercetak, dan yang kita mau yang besar.
double? _largestAmountIn(String line) {
  double? best;
  for (final value in _amountsIn(line)) {
    if (best == null || value > best) best = value;
  }
  return best;
}

/// Kumpulkan semua nominal di struk sebagai bahan pilihan manual.
List<double> _collectCandidates(List<String> lines) {
  final seen = <double>{};
  for (final line in lines) {
    seen.addAll(_amountsIn(line));
  }
  final sorted = seen.toList()..sort((a, b) => b.compareTo(a));
  return sorted.take(_maxCandidates).toList();
}

double? _findTotal(List<String> lines) {
  for (final keyword in _totalKeywords) {
    for (var i = 0; i < lines.length; i++) {
      final lower = lines[i].toLowerCase();
      if (!lower.contains(keyword)) continue;
      if (_rejectKeywords.any(lower.contains)) continue;

      final sameLine = _largestAmountIn(lines[i]);
      if (sameLine != null) return sameLine;

      // Sebagian struk menaruh nominalnya di baris berikutnya.
      if (i + 1 < lines.length) {
        final nextLine = _largestAmountIn(lines[i + 1]);
        if (nextLine != null) return nextLine;
      }
    }
  }
  return null;
}

/// Tanggal dalam format yang lazim di struk Indonesia.
DateTime? _findDate(List<String> lines, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final pattern = RegExp(r'(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{2,4})');

  for (final line in lines) {
    final match = pattern.firstMatch(line);
    if (match == null) continue;

    final day = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    var year = int.parse(match.group(3)!);
    if (year < 100) year += 2000;

    if (month < 1 || month > 12 || day < 1 || day > 31) continue;

    final parsed = DateTime(year, month, day);
    // Tanggal hasil OCR gampang salah baca. Yang mustahil dibuang: struk dari
    // masa depan atau dari lebih dari dua tahun lalu hampir pasti salah baca.
    if (parsed.isAfter(today)) continue;
    if (today.difference(parsed).inDays > 730) continue;
    // Pastikan tanggalnya benar-benar ada (31 Februari akan bergeser).
    if (parsed.month != month || parsed.day != day) continue;

    return parsed;
  }
  return null;
}

/// Nama tempat: baris pertama yang terlihat seperti nama, bukan angka, alamat,
/// atau judul halaman aplikasi.
///
/// Kalau tidak ada yang lolos, hasilnya null. Mengisi kolom ini dengan baris
/// mana pun yang kebetulan ada di atas cuma memindahkan pekerjaan menghapus ke
/// kamu, dan lebih buruk lagi kalau kamu tidak sempat memeriksanya.
String? _findMerchant(List<String> lines) {
  for (final line in lines.take(_merchantSearchLines)) {
    final trimmed = line.trim();
    if (trimmed.length < 3) continue;

    // Baris yang didominasi angka itu nomor struk, telepon, alamat, atau
    // baris status HP di tangkapan layar ("19.00  22:04  62").
    final digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '').length;
    if (digits > trimmed.length / 3) continue;

    // Nama tempat tidak memuat harga. Baris yang mengandung nominal itu baris
    // barang atau baris total, bukan kepala struk. Ini yang menyaring baris
    // seperti "Ongkos Kirim  Rp10.000" di struk aplikasi.
    if (_amountsIn(trimmed).isNotEmpty) continue;

    final lower = trimmed.toLowerCase();
    if (lower.startsWith('jl') || lower.startsWith('jalan')) continue;
    if (lower.contains('telp') || lower.contains('npwp')) continue;
    if (_notMerchant.any(lower.contains)) continue;

    return trimmed;
  }
  return null;
}

/// Baca teks OCR mentah jadi tebakan terstruktur.
ReceiptGuess parseReceipt(String rawText, {DateTime? now}) {
  final lines = rawText
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();

  if (lines.isEmpty) return const ReceiptGuess();

  final total = _findTotal(lines);

  return ReceiptGuess(
    total: total,
    date: _findDate(lines, now: now),
    merchant: _findMerchant(lines),
    // Kandidat hanya berguna waktu totalnya tidak ketemu. Kalau sudah ketemu,
    // menawarkan angka lain justru membuat ragu pada jawaban yang benar.
    candidates: total == null ? _collectCandidates(lines) : const [],
    rawLines: lines,
  );
}
