import 'transaction.dart';

/// Ringkasan satu periode anggaran.
class FinanceSummary {
  const FinanceSummary({
    required this.start,
    required this.end,
    required this.pemasukan,
    required this.pengeluaran,
    required this.perKategori,
    required this.budget,
    required this.sisaHari,
    this.rutinBelumJatuhTempo = 0,
  });

  final DateTime start;

  /// Hari terakhir periode, inklusif.
  final DateTime end;

  final double pemasukan;
  final double pengeluaran;

  /// Total pengeluaran per kategori, urut dari terbesar.
  final List<CategoryTotal> perKategori;

  /// Anggaran yang kamu tetapkan. Null kalau belum diisi.
  final double? budget;

  /// Sisa hari sampai periode berakhir, termasuk hari ini.
  final int sisaHari;

  /// Total pengeluaran rutin yang jatuh temponya masih di depan dalam periode
  /// ini — uang yang sudah dipesan tapi belum keluar.
  final double rutinBelumJatuhTempo;

  double get selisih => pemasukan - pengeluaran;

  /// Sisa anggaran mentah, belum memperhitungkan tagihan yang akan datang.
  double? get sisaBudget => budget == null ? null : budget! - pengeluaran;

  /// Sisa anggaran setelah tagihan rutin yang belum jatuh tempo dipotong.
  ///
  /// Ini angka yang benar-benar boleh kamu pakai. Bisa negatif, dan kalau
  /// negatif memang itu keadaannya — menyembunyikannya di nol malah
  /// menghilangkan peringatan yang paling perlu kamu lihat.
  double? get sisaBebas {
    final sisa = sisaBudget;
    return sisa == null ? null : sisa - rutinBelumJatuhTempo;
  }

  /// Berapa yang boleh dipakai per hari supaya anggaran cukup sampai akhir
  /// periode. Null kalau anggaran belum diisi; 0 kalau sudah kebobolan.
  ///
  /// Dihitung dari [sisaBebas], bukan [sisaBudget]. Membagi rata uang yang
  /// sudah dipesan untuk kos membuat angka ini selalu terlihat lebih longgar
  /// daripada kenyataan.
  double? get jatahHarian {
    final sisa = sisaBebas;
    if (sisa == null) return null;
    if (sisa <= 0) return 0;
    if (sisaHari <= 0) return sisa;
    return sisa / sisaHari;
  }

  /// Berapa persen anggaran sudah terpakai. Null kalau anggaran belum diisi.
  double? get persenTerpakai {
    final b = budget;
    if (b == null || b <= 0) return null;
    return (pengeluaran / b * 100).clamp(0, 999);
  }

  bool get kosong => pemasukan == 0 && pengeluaran == 0;
}

class CategoryTotal {
  const CategoryTotal(this.category, this.total);

  final TxCategory category;
  final double total;
}

/// Awal periode anggaran yang sedang berjalan.
///
/// Kalau [paydayDay] diisi, periodenya mengikuti tanggal kiriman uang — bukan
/// tanggal 1. Uang saku yang datang tanggal 5 berarti "bulan"-mu berjalan dari
/// tanggal 5 ke tanggal 4, dan menghitungnya per kalender akan membuat sisa
/// anggaran terlihat salah tiap awal bulan.
DateTime periodStart(DateTime now, int? paydayDay) {
  if (paydayDay == null) return DateTime(now.year, now.month, 1);

  if (now.day >= paydayDay) return DateTime(now.year, now.month, paydayDay);
  // Belum sampai tanggal kiriman: periodenya dimulai bulan lalu.
  return DateTime(now.year, now.month - 1, paydayDay);
}

/// Hari terakhir periode, inklusif.
DateTime periodEnd(DateTime start, int? paydayDay) {
  if (paydayDay == null) {
    // Hari terakhir bulan tersebut: hari ke-0 bulan berikutnya.
    return DateTime(start.year, start.month + 1, 0);
  }
  return DateTime(start.year, start.month + 1, start.day)
      .subtract(const Duration(days: 1));
}

/// Pengeluaran yang datang tiap bulan di tanggal yang sama.
class RecurringExpense {
  const RecurringExpense({
    required this.id,
    required this.name,
    required this.amount,
    required this.category,
    required this.dueDay,
    this.active = true,
  });

  final String id;
  final String name;
  final double amount;
  final TxCategory category;

  /// Tanggal jatuh tempo tiap bulan, 1–28.
  final int dueDay;

  final bool active;

  factory RecurringExpense.fromMap(Map<String, dynamic> map) => RecurringExpense(
        id: map['id'] as String,
        name: map['name'] as String,
        amount: (map['amount'] as num).toDouble(),
        category: TxCategory.fromDb(map['category'] as String?),
        dueDay: (map['due_day'] as num).toInt(),
        active: map['active'] as bool? ?? true,
      );

  Map<String, dynamic> toMap(String userId) => {
        'user_id': userId,
        'name': name,
        'amount': amount,
        'category': category.dbValue,
        'due_day': dueDay,
        'active': active,
      };
}

/// Kapan [expense] jatuh tempo di dalam periode yang dimulai [start].
///
/// Periode anggaran tidak selalu mulai tanggal 1 — kalau uang sakumu datang
/// tanggal 5, periode berjalan dari tanggal 5 ke tanggal 4 bulan berikutnya.
/// Yang dicari: kemunculan pertama tanggal jatuh tempo sejak periode dimulai.
///
/// [end] tidak dipakai untuk memilih tanggal, hanya penanda batas bagi
/// pemanggil — hasilnya bisa saja jatuh di luar periode.
DateTime dueDateIn(RecurringExpense expense, DateTime start) {
  final due = DateTime(start.year, start.month, expense.dueDay);
  if (!due.isBefore(start)) return due;
  return DateTime(start.year, start.month + 1, expense.dueDay);
}

/// Total tagihan rutin yang jatuh temponya belum lewat dalam periode ini.
///
/// Yang sudah lewat tanggalnya tidak dihitung: entah sudah kamu bayar (dan
/// sudah masuk pengeluaran), entah telat. Menghitungnya dua kali akan membuat
/// sisa uangmu terlihat lebih sedikit daripada kenyataan.
double upcomingRecurring({
  required List<RecurringExpense> expenses,
  required DateTime now,
  required DateTime start,
  required DateTime end,
}) {
  final today = DateTime(now.year, now.month, now.day);
  var total = 0.0;

  for (final expense in expenses) {
    if (!expense.active) continue;
    final due = dueDateIn(expense, start);
    if (due.isAfter(end)) continue;
    if (due.isBefore(today)) continue;
    total += expense.amount;
  }

  return total;
}

FinanceSummary summarize({
  required List<Transaction> transactions,
  required DateTime now,
  double? budget,
  int? paydayDay,
  List<RecurringExpense> recurring = const [],
}) {
  final start = periodStart(now, paydayDay);
  final end = periodEnd(start, paydayDay);
  final today = DateTime(now.year, now.month, now.day);

  var pemasukan = 0.0;
  var pengeluaran = 0.0;
  final perKategori = <TxCategory, double>{};

  for (final tx in transactions) {
    final tanggal = DateTime(
      tx.occurredOn.year,
      tx.occurredOn.month,
      tx.occurredOn.day,
    );
    if (tanggal.isBefore(start) || tanggal.isAfter(end)) continue;

    if (tx.kind == TxKind.pemasukan) {
      pemasukan += tx.amount;
    } else {
      pengeluaran += tx.amount;
      perKategori[tx.category] = (perKategori[tx.category] ?? 0) + tx.amount;
    }
  }

  final urut = perKategori.entries
      .map((e) => CategoryTotal(e.key, e.value))
      .toList()
    ..sort((a, b) => b.total.compareTo(a.total));

  // Hari ini ikut dihitung: uang hari ini belum tentu habis.
  final sisaHari = today.isAfter(end) ? 0 : end.difference(today).inDays + 1;

  return FinanceSummary(
    start: start,
    end: end,
    pemasukan: pemasukan,
    pengeluaran: pengeluaran,
    perKategori: urut,
    budget: budget,
    sisaHari: sisaHari,
    rutinBelumJatuhTempo: upcomingRecurring(
      expenses: recurring,
      now: now,
      start: start,
      end: end,
    ),
  );
}

/// Format rupiah tanpa desimal, dengan titik sebagai pemisah ribuan.
String formatRupiah(double amount) {
  final bulat = amount.round().abs();
  final digits = bulat.toString();
  final buffer = StringBuffer();

  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digits[i]);
  }

  final tanda = amount < 0 ? '-' : '';
  return '${tanda}Rp$buffer';
}

/// Versi ringkas untuk ruang sempit: 1,2jt / 45rb.
String formatRupiahRingkas(double amount) {
  final abs = amount.abs();
  final tanda = amount < 0 ? '-' : '';

  if (abs >= 1000000) {
    final juta = abs / 1000000;
    final teks = juta >= 10 ? juta.round().toString() : juta.toStringAsFixed(1);
    return '${tanda}Rp${teks.replaceAll('.', ',')}jt';
  }
  if (abs >= 1000) {
    return '${tanda}Rp${(abs / 1000).round()}rb';
  }
  return formatRupiah(amount);
}
