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
];

class ReceiptGuess {
  const ReceiptGuess({this.total, this.date, this.merchant, this.rawLines = const []});

  /// Nominal total. Null kalau tidak ada yang meyakinkan.
  final double? total;

  final DateTime? date;

  /// Nama tempat, biasanya baris pertama struk.
  final String? merchant;

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

/// Ambil nominal terbesar dari sebuah baris. Baris total sering berbentuk
/// "TOTAL 3 15.000" — jumlah item ikut tercetak, dan yang kita mau yang besar.
double? _largestAmountIn(String line) {
  final matches = RegExp(r'\d[\d.,]*').allMatches(line);
  double? best;
  for (final match in matches) {
    final value = parseRupiah(match.group(0)!);
    if (value == null) continue;
    // Angka satu-dua digit hampir selalu kuantitas, bukan harga.
    if (value < 100) continue;
    if (best == null || value > best) best = value;
  }
  return best;
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

/// Nama tempat: baris pertama yang terlihat seperti nama, bukan angka atau
/// alamat.
String? _findMerchant(List<String> lines) {
  for (final line in lines.take(5)) {
    final trimmed = line.trim();
    if (trimmed.length < 3) continue;

    // Baris yang didominasi angka itu nomor struk, telepon, atau alamat.
    final digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '').length;
    if (digits > trimmed.length / 3) continue;

    final lower = trimmed.toLowerCase();
    if (lower.startsWith('jl') || lower.startsWith('jalan')) continue;
    if (lower.contains('telp') || lower.contains('npwp')) continue;

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

  return ReceiptGuess(
    total: _findTotal(lines),
    date: _findDate(lines, now: now),
    merchant: _findMerchant(lines),
    rawLines: lines,
  );
}
