import 'package:flutter/material.dart';

enum TxKind {
  pemasukan('pemasukan', 'Pemasukan'),
  pengeluaran('pengeluaran', 'Pengeluaran');

  const TxKind(this.dbValue, this.label);

  final String dbValue;
  final String label;

  static TxKind fromDb(String? value) => TxKind.values.firstWhere(
        (kind) => kind.dbValue == value,
        orElse: () => TxKind.pengeluaran,
      );
}

/// Kategori dibuat tetap, bukan bisa dikarang sendiri.
///
/// Kategori bebas terdengar fleksibel, tapi ujungnya jadi "Makan", "makan",
/// dan "Mkn" sebagai tiga kategori berbeda, dan ringkasannya jadi tidak ada
/// gunanya. Daftar ini menutup kebutuhan mahasiswa; "Lainnya" menampung sisanya.
enum TxCategory {
  makan('makan', 'Makan', Icons.restaurant, TxKind.pengeluaran),
  transport('transport', 'Transport', Icons.directions_bus, TxKind.pengeluaran),
  kuliah('kuliah', 'Kuliah', Icons.school, TxKind.pengeluaran),
  belanja('belanja', 'Belanja', Icons.shopping_bag, TxKind.pengeluaran),
  hiburan('hiburan', 'Hiburan', Icons.movie, TxKind.pengeluaran),
  kesehatan('kesehatan', 'Kesehatan', Icons.medical_services, TxKind.pengeluaran),
  pulsa('pulsa', 'Pulsa & Internet', Icons.wifi, TxKind.pengeluaran),
  lainnya('lainnya', 'Lainnya', Icons.more_horiz, TxKind.pengeluaran),

  kiriman('kiriman', 'Kiriman', Icons.account_balance_wallet, TxKind.pemasukan),
  beasiswa('beasiswa', 'Beasiswa', Icons.workspace_premium, TxKind.pemasukan),
  kerja('kerja', 'Kerja & Freelance', Icons.work, TxKind.pemasukan),
  lainnyaMasuk('lainnya_masuk', 'Lainnya', Icons.more_horiz, TxKind.pemasukan);

  const TxCategory(this.dbValue, this.label, this.icon, this.kind);

  final String dbValue;
  final String label;
  final IconData icon;

  /// Kategori pengeluaran tidak muncul saat mencatat pemasukan, dan sebaliknya.
  final TxKind kind;

  static TxCategory fromDb(String? value) => TxCategory.values.firstWhere(
        (category) => category.dbValue == value,
        orElse: () => TxCategory.lainnya,
      );

  static List<TxCategory> forKind(TxKind kind) =>
      TxCategory.values.where((category) => category.kind == kind).toList();
}

/// Jenis tempat: dua sumbu, toko/resto dan offline/online.
///
/// "Resto Online" bukan bagian dari daftar yang kamu sebut, tapi itu justru
/// jenis strukmu sendiri — martabak lewat ShopeeFood bukan toko online dan
/// bukan resto offline. Tanpa pilihan ini, pesan-antar makanan tidak punya
/// tempat yang benar.
enum PlaceKind {
  tokoOffline('toko_offline', 'Toko Offline', Icons.storefront_outlined),
  tokoOnline('toko_online', 'Toko Online', Icons.shopping_cart_outlined),
  restoOffline('resto_offline', 'Resto Offline', Icons.restaurant_menu),
  restoOnline('resto_online', 'Resto Online', Icons.delivery_dining_outlined);

  const PlaceKind(this.dbValue, this.label, this.icon);

  final String dbValue;
  final String label;
  final IconData icon;

  /// Null berarti tidak diisi — tidak semua pengeluaran punya tempat
  /// (transfer, iuran, parkir).
  static PlaceKind? fromDb(String? value) {
    if (value == null) return null;
    for (final kind in PlaceKind.values) {
      if (kind.dbValue == value) return kind;
    }
    return null;
  }
}

class Transaction {
  const Transaction({
    required this.id,
    required this.occurredOn,
    required this.kind,
    required this.category,
    required this.amount,
    this.placeKind,
    this.merchant,
    this.product,
    this.note,
    this.fromReceipt = false,
  });

  final String id;
  final DateTime occurredOn;
  final TxKind kind;
  final TxCategory category;
  final double amount;

  final PlaceKind? placeKind;

  /// Nama toko atau warungnya. Kolom database-nya masih bernama `merchant`.
  final String? merchant;

  /// Barang atau menu yang dibeli.
  final String? product;

  final String? note;

  /// Angkanya berasal dari pembacaan foto struk, jadi lebih mungkin meleset
  /// daripada ketikan tangan. Ditandai di daftar supaya kamu bisa mengeceknya.
  final bool fromReceipt;

  /// Bertanda: pemasukan positif, pengeluaran negatif.
  double get signed => kind == TxKind.pemasukan ? amount : -amount;

  factory Transaction.fromMap(Map<String, dynamic> map) => Transaction(
        id: map['id'] as String,
        occurredOn: DateTime.parse(map['occurred_on'] as String),
        kind: TxKind.fromDb(map['kind'] as String?),
        category: TxCategory.fromDb(map['category'] as String?),
        amount: (map['amount'] as num).toDouble(),
        placeKind: PlaceKind.fromDb(map['place_type'] as String?),
        merchant: map['merchant'] as String?,
        product: map['product_name'] as String?,
        note: map['note'] as String?,
        fromReceipt: map['source'] == 'struk',
      );

  Map<String, dynamic> toMap(String userId) => {
        'user_id': userId,
        'occurred_on': occurredOn.toIso8601String().substring(0, 10),
        'kind': kind.dbValue,
        'category': category.dbValue,
        'amount': amount,
        'place_type': placeKind?.dbValue,
        'merchant': merchant,
        'product_name': product,
        'note': note,
        'source': fromReceipt ? 'struk' : 'manual',
      };
}

class FinanceSettings {
  const FinanceSettings({this.monthlyBudget, this.paydayDay});

  final double? monthlyBudget;

  /// Tanggal uang bulanan biasanya datang, 1-28.
  final int? paydayDay;

  factory FinanceSettings.fromMap(Map<String, dynamic> map) => FinanceSettings(
        monthlyBudget: (map['monthly_budget'] as num?)?.toDouble(),
        paydayDay: map['payday_day'] as int?,
      );

  Map<String, dynamic> toMap(String userId) => {
        'user_id': userId,
        'monthly_budget': monthlyBudget,
        'payday_day': paydayDay,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
}
