import 'package:flutter_test/flutter_test.dart';
import 'package:tracking/features/finance/domain/finance_stats.dart';
import 'package:tracking/features/finance/domain/transaction.dart';

Transaction _tx(
  DateTime date,
  double amount, {
  TxKind kind = TxKind.pengeluaran,
  TxCategory category = TxCategory.makan,
}) {
  return Transaction(
    id: '${date.toIso8601String()}-$amount',
    occurredOn: date,
    kind: kind,
    category: category,
    amount: amount,
  );
}

void main() {
  mainRutin();
  group('periodStart / periodEnd', () {
    test('tanpa tanggal kiriman, periodenya bulan kalender', () {
      final start = periodStart(DateTime(2026, 8, 15), null);
      expect(start, DateTime(2026, 8, 1));
      expect(periodEnd(start, null), DateTime(2026, 8, 31));
    });

    test('hari terakhir bulan pendek dihitung benar', () {
      final start = periodStart(DateTime(2026, 2, 10), null);
      expect(periodEnd(start, null), DateTime(2026, 2, 28));
    });

    test('sesudah tanggal kiriman, periodenya dimulai bulan ini', () {
      final start = periodStart(DateTime(2026, 8, 15), 5);
      expect(start, DateTime(2026, 8, 5));
      expect(periodEnd(start, 5), DateTime(2026, 9, 4));
    });

    test('sebelum tanggal kiriman, periodenya masih dari bulan lalu', () {
      // Tanggal 3, kiriman datang tanggal 5: uangmu masih uang bulan lalu.
      final start = periodStart(DateTime(2026, 8, 3), 5);
      expect(start, DateTime(2026, 7, 5));
      expect(periodEnd(start, 5), DateTime(2026, 8, 4));
    });

    test('tepat di tanggal kiriman, periode baru dimulai', () {
      expect(periodStart(DateTime(2026, 8, 5), 5), DateTime(2026, 8, 5));
    });

    test('kiriman di awal Januari mundur ke Desember tahun lalu', () {
      final start = periodStart(DateTime(2026, 1, 2), 10);
      expect(start, DateTime(2025, 12, 10));
    });
  });

  group('summarize', () {
    test('pemasukan dan pengeluaran dipisah', () {
      final s = summarize(
        transactions: [
          _tx(DateTime(2026, 8, 2), 1000000, kind: TxKind.pemasukan),
          _tx(DateTime(2026, 8, 3), 25000),
          _tx(DateTime(2026, 8, 4), 15000),
        ],
        now: DateTime(2026, 8, 10),
      );

      expect(s.pemasukan, 1000000);
      expect(s.pengeluaran, 40000);
      expect(s.selisih, 960000);
    });

    test('transaksi di luar periode diabaikan', () {
      final s = summarize(
        transactions: [
          _tx(DateTime(2026, 7, 31), 50000),
          _tx(DateTime(2026, 8, 1), 20000),
        ],
        now: DateTime(2026, 8, 10),
      );

      expect(s.pengeluaran, 20000);
    });

    test('pengeluaran dikelompokkan per kategori dan diurutkan', () {
      final s = summarize(
        transactions: [
          _tx(DateTime(2026, 8, 2), 20000, category: TxCategory.makan),
          _tx(DateTime(2026, 8, 3), 15000, category: TxCategory.makan),
          _tx(DateTime(2026, 8, 4), 50000, category: TxCategory.belanja),
        ],
        now: DateTime(2026, 8, 10),
      );

      expect(s.perKategori.first.category, TxCategory.belanja);
      expect(s.perKategori.first.total, 50000);
      expect(s.perKategori[1].category, TxCategory.makan);
      expect(s.perKategori[1].total, 35000);
    });

    test('pemasukan tidak masuk rincian kategori pengeluaran', () {
      final s = summarize(
        transactions: [
          _tx(DateTime(2026, 8, 2), 500000,
              kind: TxKind.pemasukan, category: TxCategory.kiriman),
        ],
        now: DateTime(2026, 8, 10),
      );

      expect(s.perKategori, isEmpty);
    });

    test('tanpa transaksi ditandai kosong', () {
      final s = summarize(transactions: const [], now: DateTime(2026, 8, 10));
      expect(s.kosong, isTrue);
      expect(s.perKategori, isEmpty);
    });
  });

  group('sisa anggaran', () {
    test('sisa hari termasuk hari ini', () {
      // 10 Agustus, periode berakhir 31 Agustus: 22 hari tersisa.
      final s = summarize(
        transactions: const [],
        now: DateTime(2026, 8, 10),
        budget: 2200000,
      );

      expect(s.sisaHari, 22);
      expect(s.jatahHarian, 100000);
    });

    test('jatah harian menyusut setelah belanja', () {
      final s = summarize(
        transactions: [_tx(DateTime(2026, 8, 5), 1100000)],
        now: DateTime(2026, 8, 10),
        budget: 2200000,
      );

      expect(s.sisaBudget, 1100000);
      expect(s.jatahHarian, 50000);
    });

    test('anggaran kebobolan memberi jatah nol, bukan angka negatif', () {
      final s = summarize(
        transactions: [_tx(DateTime(2026, 8, 5), 3000000)],
        now: DateTime(2026, 8, 10),
        budget: 2200000,
      );

      expect(s.sisaBudget, lessThan(0));
      expect(s.jatahHarian, 0);
    });

    test('tanpa anggaran, hitungannya null bukan nol', () {
      final s = summarize(
        transactions: [_tx(DateTime(2026, 8, 5), 50000)],
        now: DateTime(2026, 8, 10),
      );

      // Nol akan terbaca "jatahmu habis"; null berarti "belum diatur".
      expect(s.sisaBudget, isNull);
      expect(s.jatahHarian, isNull);
      expect(s.persenTerpakai, isNull);
    });

    test('persen terpakai dihitung dari anggaran', () {
      final s = summarize(
        transactions: [_tx(DateTime(2026, 8, 5), 550000)],
        now: DateTime(2026, 8, 10),
        budget: 2200000,
      );

      expect(s.persenTerpakai, 25);
    });

    test('anggaran nol tidak membagi dengan nol', () {
      final s = summarize(
        transactions: [_tx(DateTime(2026, 8, 5), 50000)],
        now: DateTime(2026, 8, 10),
        budget: 0,
      );

      expect(s.persenTerpakai, isNull);
    });
  });

  group('formatRupiah', () {
    test('pemisah ribuan disisipkan', () {
      expect(formatRupiah(15000), 'Rp15.000');
      expect(formatRupiah(1250000), 'Rp1.250.000');
      expect(formatRupiah(100), 'Rp100');
    });

    test('nol dan negatif', () {
      expect(formatRupiah(0), 'Rp0');
      expect(formatRupiah(-25000), '-Rp25.000');
    });

    test('desimal dibulatkan', () {
      expect(formatRupiah(15000.6), 'Rp15.001');
    });

    test('bentuk ringkas untuk ruang sempit', () {
      expect(formatRupiahRingkas(45000), 'Rp45rb');
      expect(formatRupiahRingkas(1200000), 'Rp1,2jt');
      expect(formatRupiahRingkas(15000000), 'Rp15jt');
      expect(formatRupiahRingkas(500), 'Rp500');
    });
  });
}

// --- Pengeluaran rutin ---

RecurringExpense _rutin(String nama, double jumlah, int tanggal,
        {bool aktif = true}) =>
    RecurringExpense(
      id: nama,
      name: nama,
      amount: jumlah,
      category: TxCategory.lainnya,
      dueDay: tanggal,
      active: aktif,
    );

void mainRutin() {
  group('upcomingRecurring', () {
    final start = DateTime(2026, 8, 1);
    final end = DateTime(2026, 8, 31);

    test('yang belum lewat tanggalnya dihitung', () {
      final total = upcomingRecurring(
        expenses: [_rutin('Kos', 800000, 25)],
        now: DateTime(2026, 8, 10),
        start: start,
        end: end,
      );
      expect(total, 800000);
    });

    test('yang sudah lewat tanggalnya tidak dihitung dua kali', () {
      // Sudah tanggal 26, kos tanggal 25 entah sudah dibayar (dan masuk
      // pengeluaran) entah telat. Menghitungnya lagi membuat sisa uang
      // terlihat lebih sedikit daripada kenyataan.
      final total = upcomingRecurring(
        expenses: [_rutin('Kos', 800000, 25)],
        now: DateTime(2026, 8, 26),
        start: start,
        end: end,
      );
      expect(total, 0);
    });

    test('jatuh tempo hari ini masih dihitung', () {
      final total = upcomingRecurring(
        expenses: [_rutin('Kos', 800000, 25)],
        now: DateTime(2026, 8, 25),
        start: start,
        end: end,
      );
      expect(total, 800000);
    });

    test('yang nonaktif dilewati', () {
      final total = upcomingRecurring(
        expenses: [_rutin('Spotify', 55000, 20, aktif: false)],
        now: DateTime(2026, 8, 1),
        start: start,
        end: end,
      );
      expect(total, 0);
    });

    test('periode yang tidak mulai tanggal 1 tetap benar', () {
      // Uang saku datang tanggal 5, jadi periodenya 5 Agu - 4 Sep. Kos
      // tanggal 2 jatuh temponya 2 September, masih di dalam periode.
      final mulai = DateTime(2026, 8, 5);
      final selesai = DateTime(2026, 9, 4);
      final total = upcomingRecurring(
        expenses: [_rutin('Kos', 800000, 2)],
        now: DateTime(2026, 8, 10),
        start: mulai,
        end: selesai,
      );
      expect(total, 800000);
    });

    test('yang jatuh di luar periode tidak dihitung', () {
      final mulai = DateTime(2026, 8, 5);
      final selesai = DateTime(2026, 9, 4);
      final total = upcomingRecurring(
        expenses: [_rutin('Kos', 800000, 20)],
        now: DateTime(2026, 8, 25),
        start: mulai,
        end: selesai,
      );
      // Tanggal 20 Agustus sudah lewat, dan 20 September di luar periode.
      expect(total, 0);
    });
  });

  group('jatah harian setelah tagihan rutin', () {
    test('uang yang sudah dipesan tidak ikut dibagi rata', () {
      final ringkasan = summarize(
        transactions: const [],
        now: DateTime(2026, 8, 1),
        budget: 3100000,
        recurring: [_rutin('Kos', 800000, 25)],
      );

      expect(ringkasan.sisaBudget, 3100000);
      expect(ringkasan.rutinBelumJatuhTempo, 800000);
      expect(ringkasan.sisaBebas, 2300000);
      // 31 hari di Agustus.
      expect(ringkasan.jatahHarian, closeTo(2300000 / 31, 0.01));
    });

    test('tanpa pengeluaran rutin angkanya tidak berubah', () {
      final ringkasan = summarize(
        transactions: const [],
        now: DateTime(2026, 8, 1),
        budget: 3100000,
      );
      expect(ringkasan.rutinBelumJatuhTempo, 0);
      expect(ringkasan.sisaBebas, ringkasan.sisaBudget);
    });

    test('tagihan melebihi sisa uang menghasilkan jatah nol, bukan negatif', () {
      final ringkasan = summarize(
        transactions: const [],
        now: DateTime(2026, 8, 1),
        budget: 500000,
        recurring: [_rutin('Kos', 800000, 25)],
      );
      expect(ringkasan.sisaBebas, -300000);
      expect(ringkasan.jatahHarian, 0);
    });
  });
}
