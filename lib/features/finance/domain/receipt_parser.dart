/// Menebak isi struk dari teks hasil OCR.
///
/// Ini penebak, bukan pembaca. Struk warung, minimarket, dan kafe formatnya
/// berbeda total — tidak ada aturan yang benar untuk semuanya. Karena itu
/// hasilnya SELALU ditampilkan di form untuk kamu koreksi sebelum tersimpan,
/// tidak pernah langsung masuk catatan.
library;

/// Kata kunci yang mendahului angka total, **diurutkan dari yang paling
/// meyakinkan ke yang paling longgar**.
///
/// Urutannya yang bekerja, bukan sekadar isinya. Satu struk lazim memuat
/// beberapa sekaligus ("SUBTOTAL", "TOTAL", "TUNAI", "KEMBALI", "PAID") dan
/// yang menang adalah kata kunci yang lebih dulu ketemu di daftar ini. Karena
/// itu frasa spesifik ditaruh di atas, dan kata longgar seperti 'paid' atau
/// 'bayar' ditaruh paling bawah — supaya cuma dipakai kalau tidak ada
/// petunjuk yang lebih baik.
const List<String> _totalKeywords = [
  // --- Paling meyakinkan: frasa lengkap ---
  'grand total',
  'total keseluruhan',
  'total pembayaran',
  'total yang dibayar',
  'total yang harus dibayar',
  'total dibayar',
  'total tagihan',
  'total transaksi',
  'total belanja',
  'total bayar',
  'total harga',
  'total biaya',
  'total akhir',
  'total pesanan',
  'jumlah pembayaran',
  'jumlah tagihan',
  'jumlah bayar',
  'jumlah harga',
  'nominal pembayaran',
  'nominal transaksi',
  'harus dibayar',
  'wajib dibayar',
  'sisa tagihan',

  // --- Struk berbahasa Inggris (banyak POS memakai ini apa adanya) ---
  'amount due',
  'amount paid',
  'total amount',
  'net total',
  'nett total',
  'balance due',

  // --- Umum ---
  'total',
  'jumlah',

  // --- Longgar: cuma dipakai kalau semua di atas gagal ---
  // ShopeeFood menulis totalnya cukup dengan "Paid". Tidak ada kata "total"
  // di seluruh strukmu selain "Subtotal Pesanan", yang justru harus ditolak.
  'paid',
  'lunas',
  'terbayar',
  'dibayarkan',
  'dibayar',
  'nominal',
  'tagihan',
  'bayar',
];

/// Kata yang menandakan angka di barisnya BUKAN yang kita cari, meski
/// mengandung kata kunci di atas.
///
/// Ini pasangan wajib dari daftar longgar di atas: makin longgar kata
/// kuncinya, makin daftar ini yang menahan salah tangkap. "Kembali" adalah
/// uang kembalian, "subtotal" belum termasuk ongkir, dan "Waktu Pembayaran"
/// isinya tanggal.
const List<String> _rejectKeywords = [
  // Bukan uang yang keluar
  'kembali',
  'kembalian',
  'sub total',
  'subtotal',
  'total item',
  'total qty',
  'total menu',
  'total diskon',
  'diskon',
  'voucher',
  'promo',
  'potongan',
  'ppn',
  'pajak',
  'npwp',
  'refund',
  'dikembalikan',
  'saldo',
  'sisa saldo',
  'belum dibayar',
  'belum bayar',
  'unpaid',

  // Angka hadiah, bukan pengeluaran
  'koin',
  'poin',
  'point',
  'hemat',
  'cashback',
  'reward',

  // Baris yang isinya tanggal, nomor, atau keterangan — bukan nominal
  'waktu',
  'tanggal',
  'jam ',
  'metode',
  'status',
  'informasi',
  'catatan',
  'no. pesanan',
  'nomor pesanan',
  'id pesanan',
  'id transaksi',
  'no. transaksi',
  'kode',
  'estimasi',
  'minimal',
  'min.',
];

/// Batas atas nominal yang masih masuk akal (Rp 100 juta).
///
/// Bukan untuk membatasi belanjaanmu, tapi untuk membuang nomor yang kebetulan
/// terbaca sebagai angka. Nomor pesanan "3198462280678912001" di strukmu
/// terbaca sebagai tiga triliun rupiah dan langsung nangkring di urutan
/// pertama daftar pilihan.
const double _maxReasonableAmount = 100000000;

/// Nama bulan beserta nomornya.
///
/// Dipakai untuk dua hal: membaca tanggal bergaya "1 Agt 2026", dan mengenali
/// tahun yang berdiri tepat sesudah nama bulan supaya tidak terbaca sebagai
/// nominal.
const Map<String, int> _monthWords = {
  'jan': 1, 'januari': 1,
  'feb': 2, 'februari': 2,
  'mar': 3, 'maret': 3,
  'apr': 4, 'april': 4,
  'mei': 5,
  'jun': 6, 'juni': 6,
  'jul': 7, 'juli': 7,
  'agt': 8, 'ags': 8, 'agu': 8, 'agustus': 8,
  'sep': 9, 'sept': 9, 'september': 9,
  'okt': 10, 'oktober': 10,
  'nov': 11, 'november': 11,
  'des': 12, 'desember': 12,
};

/// Kata yang menandakan sebuah baris adalah judul layar atau tombol aplikasi,
/// bukan nama tempat.
///
/// Struk digital tidak dimulai dengan nama toko seperti struk kertas — bagian
/// atasnya penuh judul halaman ("Rincian Pesananmu") dan ajakan ("Tambah
/// ShopeeFood ke Layar Utama"). Tanpa saringan ini, judul halaman itulah yang
/// tercatat sebagai nama tempat.
const List<String> _notMerchant = [
  // Judul halaman
  'rincian',
  'detail',
  'ringkasan',
  'informasi',
  'pesananmu',
  'pesanan saya',
  'riwayat',
  'struk',
  'nota',
  'invoice',
  'receipt',
  'faktur',

  // Tombol dan ajakan
  'layar utama',
  'pesan lagi',
  'beli lagi',
  'pesan makan',
  'beri nilai',
  'bantuan',
  'tambah',
  'lihat',
  'salin',
  'kembali',
  'lanjut',
  'unduh',
  'bagikan',

  // Baris nilai, bukan nama
  'berhasil',
  'selesai',
  'terima kasih',
  'pembayaran',
  'metode',
  'total',
  'subtotal',
  'catatan',
  'waktu',
  'tanggal',
  'status',
];

/// Nama layanan atau gerai yang bisa dikenali langsung dari teksnya.
///
/// Dipakai sebagai cadangan terakhir untuk nama tempat. Di tangkapan layar
/// aplikasi, bagian atas layar cuma berisi judul halaman — tapi nama
/// layanannya hampir selalu tercetak di suatu tempat. "ShopeeFood" memang
/// bukan nama warungnya, tapi jauh lebih berguna daripada kolom kosong, dan
/// dia tidak mengaku jadi sesuatu yang bukan dirinya.
///
/// Urutannya penting: yang lebih panjang harus di atas, supaya "ShopeeFood"
/// tidak keburu tertangkap sebagai "Shopee".
const List<String> _knownPlaces = [
  'ShopeeFood',
  'GrabFood',
  'GoFood',
  'Shopee',
  'Tokopedia',
  'Bukalapak',
  'Lazada',
  'Blibli',
  'Traveloka',
  'Gojek',
  'Grab',
  'Alfamidi',
  'Alfamart',
  'Indomaret',
  'Superindo',
  'Hypermart',
  'Transmart',
  'Lotte Mart',
  'Ranch Market',
  'Kopi Kenangan',
  'Janji Jiwa',
  'Point Coffee',
  'Fore Coffee',
  'Starbucks',
  'Chatime',
  'Mixue',
  'Dunkin',
  'Pizza Hut',
  'Burger King',
  'Richeese',
  'HokBen',
  'Yoshinoya',
  'Solaria',
  'McDonald',
  'KFC',
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

/// Angka empat digit yang berdiri tepat setelah nama bulan itu tahun.
///
/// "Waktu Pembayaran  1 Agt 2026 18:24" tidak boleh menyumbang Rp2.026 —
/// dan baris itu ikut terbaca begitu kata kunci 'bayar' dipakai.
bool _looksLikeYear(String line, RegExpMatch match) {
  final token = match.group(0)!;
  if (token.length != 4 || int.tryParse(token) == null) return false;

  final year = int.parse(token);
  if (year < 1900 || year > 2100) return false;

  final words = line
      .substring(0, match.start)
      .toLowerCase()
      .split(RegExp(r'[^a-z]+'))
      .where((word) => word.isNotEmpty)
      .toList();

  // Harus kata persis di depannya. Tanpa syarat ini "Martabak 2000" ikut
  // terbuang karena "Martabak" diawali "mar".
  return words.isNotEmpty && _monthWords.containsKey(words.last);
}

/// Nominal yang masuk akal sebagai harga di sebuah baris.
Iterable<double> _amountsIn(String line) sync* {
  for (final match in _numberPattern.allMatches(line)) {
    if (_partOfDateOrTime(line, match)) continue;
    if (_looksLikeYear(line, match)) continue;

    final value = parseRupiah(match.group(0)!);
    if (value == null) continue;
    // Angka satu-dua digit hampir selalu kuantitas, bukan harga.
    if (value < 100) continue;
    // Angka raksasa itu nomor pesanan atau nomor telepon, bukan uang.
    if (value > _maxReasonableAmount) continue;
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

/// Tanggal berangka: 03/08/2026, 25-07-26, 2.8.2026.
final RegExp _numericDatePattern = RegExp(r'(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{2,4})');

/// Tanggal bertulis: "1 Agt 2026", "25 Juli 2026". Bentuk ini yang dipakai
/// struk digital, dan sebelumnya tidak pernah terbaca sama sekali.
final RegExp _textDatePattern = RegExp(r'(\d{1,2})\s+([a-zA-Z]+)\s+(\d{4})');

/// Rakit tanggal sambil memastikan tanggalnya benar-benar ada — DateTime
/// menggeser 31 Februari jadi 3 Maret tanpa mengeluh.
DateTime? _buildDate(int day, int month, int year) {
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  final parsed = DateTime(year, month, day);
  if (parsed.month != month || parsed.day != day) return null;
  return parsed;
}

DateTime? _parseNumericDate(String line) {
  final match = _numericDatePattern.firstMatch(line);
  if (match == null) return null;

  var year = int.parse(match.group(3)!);
  if (year < 100) year += 2000;

  return _buildDate(int.parse(match.group(1)!), int.parse(match.group(2)!), year);
}

DateTime? _parseTextDate(String line) {
  final match = _textDatePattern.firstMatch(line);
  if (match == null) return null;

  final month = _monthWords[match.group(2)!.toLowerCase()];
  if (month == null) return null;

  return _buildDate(int.parse(match.group(1)!), month, int.parse(match.group(3)!));
}

/// Tanggal dalam format yang lazim di struk Indonesia.
DateTime? _findDate(List<String> lines, {DateTime? now}) {
  final today = now ?? DateTime.now();

  for (final line in lines) {
    final parsed = _parseNumericDate(line) ?? _parseTextDate(line);
    if (parsed == null) continue;

    // Tanggal hasil OCR gampang salah baca. Yang mustahil dibuang: struk dari
    // masa depan atau dari lebih dari dua tahun lalu hampir pasti salah baca.
    if (parsed.isAfter(today)) continue;
    if (today.difference(parsed).inDays > 730) continue;

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

    // Garis miring menandai satuan, bukan nama: "KB/S" dan "MB/S" di baris
    // status HP ikut terbaca dan bentuknya persis seperti singkatan toko.
    if (trimmed.contains('/') || trimmed.contains(r'\')) continue;

    // Nama tempat di struk selalu punya huruf besar — ALL CAPS atau Title
    // Case. Kalimat yang seluruhnya huruf kecil itu teks iklan, seperti
    // "jadi lebih cepat dan mudah".
    if (trimmed == trimmed.toLowerCase()) continue;

    final lower = trimmed.toLowerCase();
    if (lower.startsWith('jl') || lower.startsWith('jalan')) continue;
    if (lower.contains('telp') || lower.contains('npwp')) continue;
    if (_notMerchant.any(lower.contains)) continue;

    return trimmed;
  }
  return null;
}

/// Cadangan terakhir: nama layanan yang dikenali dari mana pun di teks.
String? _findKnownPlace(String rawText) {
  final lower = rawText.toLowerCase();
  for (final place in _knownPlaces) {
    if (lower.contains(place.toLowerCase())) return place;
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
    // Kepala struk dulu; nama layanan cuma dipakai kalau di sana tidak ada
    // yang layak, karena nama warungnya selalu lebih berguna daripada nama
    // aplikasi pengantarnya.
    merchant: _findMerchant(lines) ?? _findKnownPlace(rawText),
    // Kandidat hanya berguna waktu totalnya tidak ketemu. Kalau sudah ketemu,
    // menawarkan angka lain justru membuat ragu pada jawaban yang benar.
    candidates: total == null ? _collectCandidates(lines) : const [],
    rawLines: lines,
  );
}
