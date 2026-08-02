import 'package:flutter_test/flutter_test.dart';
import 'package:tracking/features/finance/domain/transaction.dart';
import 'package:tracking/features/wishlist/domain/wishlist.dart';

/// Rabu, 5 Agustus 2026.
final _now = DateTime(2026, 8, 5, 10);

WishlistItem _barang({
  String id = 'w1',
  String nama = 'Keyboard',
  double? harga = 1000000,
  double saved = 0,
  WishPriority priority = WishPriority.sedang,
  DateTime? target,
  DateTime? dibeli,
}) =>
    WishlistItem(
      id: id,
      name: nama,
      price: harga,
      saved: saved,
      priority: priority,
      targetDate: target,
      boughtOn: dibeli,
    );

Transaction _tx(DateTime tanggal, double jumlah, TxKind kind) => Transaction(
      id: '$tanggal-$jumlah-$kind',
      occurredOn: tanggal,
      kind: kind,
      category: TxCategory.lainnya,
      amount: jumlah,
    );

/// Sebulan penuh: masuk [masuk], keluar [keluar].
List<Transaction> _bulan(int tahun, int bulan, {double masuk = 0, double keluar = 0}) => [
      if (masuk > 0) _tx(DateTime(tahun, bulan, 5), masuk, TxKind.pemasukan),
      if (keluar > 0) _tx(DateTime(tahun, bulan, 15), keluar, TxKind.pengeluaran),
    ];

void main() {
  group('WishlistItem', () {
    test('kurang dan persen dihitung dari harga', () {
      final item = _barang(harga: 1000000, saved: 250000);
      expect(item.kurang, 750000);
      expect(item.persen, closeTo(0.25, 0.001));
      expect(item.lunas, isFalse);
    });

    test('tabungan melebihi harga tidak jadi kurang negatif', () {
      final item = _barang(harga: 1000000, saved: 1200000);
      expect(item.kurang, 0);
      expect(item.persen, 1.0);
      expect(item.lunas, isTrue);
    });

    test('tanpa harga tidak punya kurang maupun persen', () {
      // Beda dari nol: barang tanpa harga sengaja tidak ikut hitungan apa pun.
      final item = _barang(harga: null, saved: 50000);
      expect(item.kurang, isNull);
      expect(item.persen, isNull);
      expect(item.adaHarga, isFalse);
      expect(item.lunas, isFalse);
    });

    test('harga nol tidak bikin pembagian nol', () {
      expect(_barang(harga: 0).persen, isNull);
    });
  });

  group('surplusBulanan', () {
    test('rata-rata dari bulan yang punya catatan', () {
      final transaksi = [
        ..._bulan(2026, 5, masuk: 2000000, keluar: 1500000), // +500rb
        ..._bulan(2026, 6, masuk: 2000000, keluar: 1700000), // +300rb
        ..._bulan(2026, 7, masuk: 2000000, keluar: 1600000), // +400rb
      ];
      expect(surplusBulanan(transaksi, now: _now), closeTo(400000, 0.01));
    });

    test('bulan berjalan tidak ikut karena belum selesai', () {
      // Agustus baru tanggal 5: pengeluarannya belum lengkap, dan
      // menghitungnya akan membuat surplus terlihat jauh lebih besar.
      final transaksi = [
        ..._bulan(2026, 7, masuk: 2000000, keluar: 1600000),
        _tx(DateTime(2026, 8, 1), 5000000, TxKind.pemasukan),
      ];
      expect(surplusBulanan(transaksi, now: _now), closeTo(400000, 0.01));
    });

    test('dibagi bulan yang tercatat, bukan selalu tiga', () {
      // Cuma satu bulan yang punya catatan.
      final transaksi = _bulan(2026, 7, masuk: 2000000, keluar: 1400000);
      expect(surplusBulanan(transaksi, now: _now), closeTo(600000, 0.01));
    });

    test('lebih tua dari jendela tidak ikut', () {
      final transaksi = _bulan(2026, 1, masuk: 9000000);
      expect(surplusBulanan(transaksi, now: _now), 0);
    });

    test('boros lebih besar dari pemasukan menghasilkan angka negatif', () {
      final transaksi = _bulan(2026, 7, masuk: 1000000, keluar: 1500000);
      expect(surplusBulanan(transaksi, now: _now), closeTo(-500000, 0.01));
    });

    test('tanpa transaksi menghasilkan nol, bukan NaN', () {
      expect(surplusBulanan(const [], now: _now), 0);
    });
  });

  group('planFor', () {
    test('perkiraan bulan dibulatkan ke atas', () {
      // Kurang 1 juta, surplus 400rb per bulan → 2,5 bulan → 3 bulan.
      final plan = planFor(_barang(harga: 1000000), surplus: 400000, now: _now);
      expect(plan.bulanDibutuhkan, closeTo(2.5, 0.001));
      expect(plan.perkiraan, DateTime(2026, 11, 5));
    });

    test('sudah lunas tidak punya perkiraan', () {
      final plan = planFor(
        _barang(harga: 1000000, saved: 1000000),
        surplus: 400000,
        now: _now,
      );
      expect(plan.perkiraan, isNull);
      expect(plan.tidakAkanTerkumpul, isFalse);
    });

    test('tanpa harga tidak bisa diperkirakan', () {
      final plan = planFor(_barang(harga: null), surplus: 400000, now: _now);
      expect(plan.bulanDibutuhkan, isNull);
      expect(plan.tidakAkanTerkumpul, isFalse);
    });

    test('surplus nol atau negatif dijawab, bukan didiamkan', () {
      // Ini jawaban, bukan ketiadaan data.
      final plan = planFor(_barang(), surplus: -100000, now: _now);
      expect(plan.tidakAkanTerkumpul, isTrue);
      expect(plan.perkiraan, isNull);
    });

    test('lebih dari batas tidak menampilkan tanggal karangan', () {
      // 100 juta dengan surplus 100rb = 1000 bulan. "83 tahun lagi" bukan
      // informasi, cuma angka yang membuat orang berhenti percaya.
      final plan = planFor(_barang(harga: 100000000), surplus: 100000, now: _now);
      expect(plan.bulanDibutuhkan, greaterThan(kMaxBulanPerkiraan.toDouble()));
      expect(plan.perkiraan, isNull);
      expect(plan.tidakAkanTerkumpul, isFalse);
    });

    test('perkiraan lewat dari target ditandai telat', () {
      final plan = planFor(
        _barang(harga: 1000000, target: DateTime(2026, 9, 1)),
        surplus: 400000,
        now: _now,
      );
      expect(plan.telat, isTrue);
    });

    test('perkiraan sebelum target tidak ditandai telat', () {
      final plan = planFor(
        _barang(harga: 1000000, target: DateTime(2027, 6, 1)),
        surplus: 400000,
        now: _now,
      );
      expect(plan.telat, isFalse);
    });

    test('tanpa target tidak pernah telat', () {
      final plan = planFor(_barang(harga: 1000000), surplus: 400000, now: _now);
      expect(plan.telat, isFalse);
    });
  });

  group('summarizeWishlist', () {
    test('barang dibeli tidak ikut total yang aktif', () {
      final ringkasan = summarizeWishlist([
        _barang(id: 'a', harga: 1000000, saved: 200000),
        _barang(id: 'b', harga: 500000, dibeli: DateTime(2026, 7, 1)),
      ]);

      expect(ringkasan.jumlahAktif, 1);
      expect(ringkasan.jumlahDibeli, 1);
      expect(ringkasan.totalHarga, 1000000);
      expect(ringkasan.totalKurang, 800000);
    });

    test('barang tanpa harga dihitung jumlahnya, bukan dianggap gratis', () {
      final ringkasan = summarizeWishlist([
        _barang(id: 'a', harga: 1000000),
        _barang(id: 'b', harga: null, saved: 50000),
      ]);

      expect(ringkasan.totalHarga, 1000000);
      expect(ringkasan.tanpaHarga, 1);
      // Tabungannya tetap dihitung meski harganya belum diisi.
      expect(ringkasan.totalTersisih, 50000);
    });

    test('daftar kosong tidak error', () {
      final ringkasan = summarizeWishlist(const []);
      expect(ringkasan.kosong, isTrue);
      expect(ringkasan.totalHarga, 0);
    });
  });

  group('sortWishlist', () {
    test('yang sudah dibeli turun ke bawah', () {
      final hasil = sortWishlist([
        _barang(id: 'dibeli', dibeli: DateTime(2026, 7, 1)),
        _barang(id: 'aktif'),
      ]);
      expect(hasil.map((i) => i.id), ['aktif', 'dibeli']);
    });

    test('yang dananya sudah cukup naik paling atas', () {
      final hasil = sortWishlist([
        _barang(id: 'jauh', harga: 1000000, priority: WishPriority.tinggi),
        _barang(id: 'lunas', harga: 500000, saved: 500000, priority: WishPriority.rendah),
      ]);
      expect(hasil.first.id, 'lunas');
    });

    test('punya tanggal target didahulukan', () {
      final hasil = sortWishlist([
        _barang(id: 'tanpa', priority: WishPriority.tinggi),
        _barang(id: 'target', priority: WishPriority.rendah, target: DateTime(2026, 12, 1)),
      ]);
      expect(hasil.first.id, 'target');
    });

    test('target lebih dekat lebih dulu', () {
      final hasil = sortWishlist([
        _barang(id: 'jauh', target: DateTime(2027, 1, 1)),
        _barang(id: 'dekat', target: DateTime(2026, 9, 1)),
      ]);
      expect(hasil.first.id, 'dekat');
    });

    test('prioritas menentukan kalau tidak ada target', () {
      final hasil = sortWishlist([
        _barang(id: 'rendah', priority: WishPriority.rendah),
        _barang(id: 'tinggi', priority: WishPriority.tinggi),
      ]);
      expect(hasil.first.id, 'tinggi');
    });

    test('prioritas sama: yang paling dekat selesai lebih dulu', () {
      final hasil = sortWishlist([
        _barang(id: 'jauh', harga: 1000000, saved: 0),
        _barang(id: 'dekat', harga: 1000000, saved: 900000),
      ]);
      expect(hasil.first.id, 'dekat');
    });

    test('barang tanpa harga turun di bawah yang punya harga', () {
      final hasil = sortWishlist([
        _barang(id: 'tanpa', harga: null),
        _barang(id: 'ada', harga: 1000000),
      ]);
      expect(hasil.map((i) => i.id), ['ada', 'tanpa']);
    });

    test('daftar aslinya tidak ikut berubah', () {
      final asli = [_barang(id: 'b'), _barang(id: 'a', harga: 1, saved: 1)];
      sortWishlist(asli);
      expect(asli.first.id, 'b');
    });
  });

  group('WishlistItem.fromMap', () {
    test('kolom opsional yang kosong tetap null', () {
      final item = WishlistItem.fromMap({
        'id': 'w',
        'name': 'Keyboard',
        'price': null,
        'category': 'belanja',
        'priority': 'tinggi',
        'saved': 0,
        'url': null,
        'note': null,
        'target_date': null,
        'bought_on': null,
      });

      expect(item.price, isNull);
      expect(item.priority, WishPriority.tinggi);
      expect(item.dibeli, isFalse);
    });

    test('prioritas yang tidak dikenal jatuh ke sedang', () {
      final item = WishlistItem.fromMap({
        'id': 'w',
        'name': 'Keyboard',
        'category': 'belanja',
        'priority': 'entah',
      });
      expect(item.priority, WishPriority.sedang);
      expect(item.saved, 0);
    });
  });
}
