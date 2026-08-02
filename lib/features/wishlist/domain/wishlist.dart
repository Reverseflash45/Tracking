/// Wishlist: barang yang ingin dibeli, beserta perkiraan kapan terjangkau.
///
/// Yang membedakan ini dari catatan di aplikasi notes: app sudah tahu berapa
/// yang masuk dan keluar tiap bulan. Jadi pertanyaan yang dijawab bukan "apa
/// saja yang aku mau", tapi **"kapan aku bisa beli ini"** — dan kalau jawabannya
/// "tidak akan terkumpul dengan pola sekarang", itu juga dikatakan.
library;

import 'package:flutter/material.dart';

import '../../finance/domain/transaction.dart';

enum WishPriority {
  tinggi('Tinggi', 3),
  sedang('Sedang', 2),
  rendah('Rendah', 1);

  const WishPriority(this.label, this.bobot);

  final String label;

  /// Makin besar makin didahulukan saat pengurutan.
  final int bobot;

  static WishPriority fromDb(String? value) => WishPriority.values.firstWhere(
        (p) => p.name == value,
        orElse: () => WishPriority.sedang,
      );
}

class WishlistItem {
  const WishlistItem({
    required this.id,
    required this.name,
    this.price,
    this.category = TxCategory.belanja,
    this.priority = WishPriority.sedang,
    this.saved = 0,
    this.url,
    this.note,
    this.targetDate,
    this.boughtOn,
  });

  final String id;
  final String name;

  /// Null berarti belum tahu harganya — beda dari nol.
  final double? price;

  final TxCategory category;
  final WishPriority priority;

  /// Uang yang sudah disisihkan khusus untuk barang ini.
  final double saved;

  final String? url;
  final String? note;
  final DateTime? targetDate;
  final DateTime? boughtOn;

  bool get dibeli => boughtOn != null;
  bool get adaHarga => price != null;

  /// Berapa lagi yang kurang. Null kalau harganya belum diisi.
  double? get kurang {
    final harga = price;
    if (harga == null) return null;
    final sisa = harga - saved;
    return sisa < 0 ? 0 : sisa;
  }

  /// 0–1 untuk bilah progres. Barang tanpa harga tidak punya progres.
  double? get persen {
    final harga = price;
    if (harga == null || harga <= 0) return null;
    return (saved / harga).clamp(0.0, 1.0);
  }

  bool get lunas => kurang != null && kurang == 0;

  factory WishlistItem.fromMap(Map<String, dynamic> map) => WishlistItem(
        id: map['id'] as String,
        name: map['name'] as String,
        price: (map['price'] as num?)?.toDouble(),
        category: TxCategory.fromDb(map['category'] as String?),
        priority: WishPriority.fromDb(map['priority'] as String?),
        saved: (map['saved'] as num?)?.toDouble() ?? 0,
        url: map['url'] as String?,
        note: map['note'] as String?,
        targetDate:
            map['target_date'] == null ? null : DateTime.parse(map['target_date'] as String),
        boughtOn:
            map['bought_on'] == null ? null : DateTime.parse(map['bought_on'] as String),
      );
}

/// Berapa bulan ke belakang dipakai menghitung laju menabung.
///
/// Tiga bulan: cukup panjang untuk meredam bulan yang tidak biasa, cukup pendek
/// untuk masih menggambarkan keadaanmu sekarang.
const int kBulanRiwayatSurplus = 3;

/// Batas waktu yang masih masuk akal untuk ditampilkan sebagai perkiraan.
///
/// Lebih dari lima tahun, angkanya berhenti berarti apa pun — pemasukanmu akan
/// berubah jauh sebelum itu.
const int kMaxBulanPerkiraan = 60;

DateTime _hari(DateTime date) => DateTime(date.year, date.month, date.day);

/// Rata-rata sisa uang per bulan dari riwayat transaksi.
///
/// Bulan berjalan sengaja **tidak** ikut: dia belum selesai, jadi pengeluarannya
/// belum lengkap dan surplusnya akan selalu terlihat lebih besar daripada
/// kenyataan — persis kesalahan yang membuat perkiraan jadi terlalu optimis.
///
/// Bisa negatif, dan kalau negatif memang itu keadaannya.
double surplusBulanan(
  List<Transaction> transactions, {
  required DateTime now,
  int bulan = kBulanRiwayatSurplus,
}) {
  if (bulan <= 0) return 0;

  final awal = DateTime(now.year, now.month - bulan, 1);
  final akhirEksklusif = DateTime(now.year, now.month, 1);

  var total = 0.0;
  final bulanTerpakai = <String>{};

  for (final tx in transactions) {
    final tanggal = _hari(tx.occurredOn);
    if (tanggal.isBefore(awal) || !tanggal.isBefore(akhirEksklusif)) continue;
    total += tx.signed;
    bulanTerpakai.add('${tanggal.year}-${tanggal.month}');
  }

  // Dibagi bulan yang benar-benar punya catatan, bukan selalu 3. Bulan yang
  // belum kamu pakai app-nya bukan bulan tanpa pemasukan.
  if (bulanTerpakai.isEmpty) return 0;
  return total / bulanTerpakai.length;
}

/// Perkiraan kapan sebuah barang terjangkau.
class WishlistPlan {
  const WishlistPlan({
    required this.item,
    required this.bulanDibutuhkan,
    required this.perkiraan,
    required this.tidakAkanTerkumpul,
  });

  final WishlistItem item;

  /// Null kalau tidak bisa dihitung — harga belum diisi, sudah lunas, atau
  /// surplusnya tidak positif.
  final double? bulanDibutuhkan;

  /// Tanggal perkiraan terjangkau. Null dengan alasan yang sama.
  final DateTime? perkiraan;

  /// Surplus bulananmu nol atau negatif, jadi menabung tidak akan menutupinya.
  /// Ini berbeda dari "belum bisa dihitung" — ini jawaban, bukan ketiadaan.
  final bool tidakAkanTerkumpul;

  /// Perkiraannya lewat dari tanggal yang kamu targetkan.
  bool get telat {
    final target = item.targetDate;
    final tiba = perkiraan;
    if (target == null || tiba == null) return false;
    return tiba.isAfter(_hari(target));
  }
}

/// Perkiraan untuk satu barang.
///
/// [surplus] adalah sisa uang per bulan; lihat [surplusBulanan].
WishlistPlan planFor(
  WishlistItem item, {
  required double surplus,
  required DateTime now,
}) {
  final kurang = item.kurang;

  if (kurang == null || kurang <= 0) {
    return WishlistPlan(
      item: item,
      bulanDibutuhkan: null,
      perkiraan: null,
      tidakAkanTerkumpul: false,
    );
  }

  if (surplus <= 0) {
    return WishlistPlan(
      item: item,
      bulanDibutuhkan: null,
      perkiraan: null,
      tidakAkanTerkumpul: true,
    );
  }

  final bulan = kurang / surplus;
  if (bulan > kMaxBulanPerkiraan) {
    // Menampilkan "212 bulan lagi" bukan informasi, cuma angka yang membuat
    // orang berhenti percaya pada perkiraannya.
    return WishlistPlan(
      item: item,
      bulanDibutuhkan: bulan,
      perkiraan: null,
      tidakAkanTerkumpul: false,
    );
  }

  final hariIni = _hari(now);
  final penuh = bulan.ceil();
  return WishlistPlan(
    item: item,
    bulanDibutuhkan: bulan,
    perkiraan: DateTime(hariIni.year, hariIni.month + penuh, hariIni.day),
    tidakAkanTerkumpul: false,
  );
}

/// Ringkasan seluruh wishlist yang belum dibeli.
class WishlistSummary {
  const WishlistSummary({
    required this.totalHarga,
    required this.totalTersisih,
    required this.totalKurang,
    required this.jumlahAktif,
    required this.jumlahDibeli,
    required this.tanpaHarga,
  });

  /// Hanya menjumlah barang yang harganya sudah diisi.
  final double totalHarga;
  final double totalTersisih;
  final double totalKurang;

  final int jumlahAktif;
  final int jumlahDibeli;

  /// Barang aktif yang harganya belum diisi — totalnya belum lengkap sebanyak
  /// ini, dan itu perlu terlihat daripada diam-diam dianggap gratis.
  final int tanpaHarga;

  bool get kosong => jumlahAktif == 0 && jumlahDibeli == 0;
}

WishlistSummary summarizeWishlist(List<WishlistItem> items) {
  var harga = 0.0;
  var tersisih = 0.0;
  var kurang = 0.0;
  var aktif = 0;
  var dibeli = 0;
  var tanpaHarga = 0;

  for (final item in items) {
    if (item.dibeli) {
      dibeli++;
      continue;
    }

    aktif++;
    tersisih += item.saved;
    if (item.adaHarga) {
      harga += item.price!;
      kurang += item.kurang!;
    } else {
      tanpaHarga++;
    }
  }

  return WishlistSummary(
    totalHarga: harga,
    totalTersisih: tersisih,
    totalKurang: kurang,
    jumlahAktif: aktif,
    jumlahDibeli: dibeli,
    tanpaHarga: tanpaHarga,
  );
}

/// Urutkan wishlist: yang belum dibeli dulu, lalu yang paling mendesak.
///
/// Urutannya sengaja bukan sekadar prioritas: barang prioritas tinggi yang
/// tinggal kurang sedikit lebih pantas didahulukan daripada barang prioritas
/// tinggi yang masih jauh — yang pertama bisa kamu selesaikan, yang kedua cuma
/// jadi pengingat bahwa kamu belum mampu.
List<WishlistItem> sortWishlist(List<WishlistItem> items) {
  final hasil = [...items];

  hasil.sort((a, b) {
    if (a.dibeli != b.dibeli) return a.dibeli ? 1 : -1;

    // Yang sudah dibeli: terbaru di atas.
    if (a.dibeli && b.dibeli) return b.boughtOn!.compareTo(a.boughtOn!);

    // Yang dananya sudah cukup naik ke paling atas: tinggal dibeli.
    if (a.lunas != b.lunas) return a.lunas ? -1 : 1;

    // Punya tanggal target mengalahkan yang tidak — itu janji dengan tenggat.
    final targetA = a.targetDate;
    final targetB = b.targetDate;
    if ((targetA == null) != (targetB == null)) return targetA == null ? 1 : -1;
    if (targetA != null && targetB != null && targetA != targetB) {
      return targetA.compareTo(targetB);
    }

    if (a.priority != b.priority) return b.priority.bobot.compareTo(a.priority.bobot);

    // Terakhir: yang paling dekat selesai.
    final sisaA = a.kurang;
    final sisaB = b.kurang;
    if (sisaA == null && sisaB == null) return a.name.compareTo(b.name);
    if (sisaA == null) return 1;
    if (sisaB == null) return -1;
    return sisaA.compareTo(sisaB);
  });

  return hasil;
}

/// Warna status untuk sebuah rencana, dipakai kartu di halaman Wishlist.
IconData iconUntuk(WishlistItem item) {
  if (item.dibeli) return Icons.check_circle_outline;
  if (item.lunas) return Icons.savings_outlined;
  return item.category.icon;
}
