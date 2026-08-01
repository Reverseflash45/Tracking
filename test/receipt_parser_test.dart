import 'package:flutter_test/flutter_test.dart';
import 'package:tracking/features/finance/domain/receipt_parser.dart';

final _now = DateTime(2026, 8, 3);

void main() {
  group('parseRupiah', () {
    test('titik sebagai pemisah ribuan', () {
      expect(parseRupiah('15.000'), 15000);
      expect(parseRupiah('1.250.000'), 1250000);
    });

    test('koma sebagai pemisah ribuan', () {
      expect(parseRupiah('15,000'), 15000);
    });

    test('dua digit di belakang dibaca sebagai desimal', () {
      expect(parseRupiah('15.000,50'), 15000.5);
      expect(parseRupiah('12,75'), 12.75);
    });

    test('awalan Rp dibuang', () {
      expect(parseRupiah('Rp15.000'), 15000);
      expect(parseRupiah('RP 15.000'), 15000);
      expect(parseRupiah('Rp. 15.000'), 15000);
      expect(parseRupiah('IDR 15.000'), 15000);
    });

    test('angka polos tanpa pemisah', () {
      expect(parseRupiah('15000'), 15000);
    });

    test('teks tanpa angka menghasilkan null', () {
      expect(parseRupiah('TOTAL'), isNull);
      expect(parseRupiah(''), isNull);
      expect(parseRupiah('Rp'), isNull);
    });

    test('nominal negatif ditolak', () {
      expect(parseRupiah('-15.000'), isNull);
    });
  });

  group('parseReceipt — total', () {
    test('struk minimarket sederhana', () {
      const teks = '''
INDOMARET
JL MERDEKA NO 12
03/08/2026 14:22

INDOMIE GORENG      3.500
TEH BOTOL           5.000
ROTI TAWAR         12.000

TOTAL              20.500
TUNAI              50.000
KEMBALI            29.500
''';

      final hasil = parseReceipt(teks, now: _now);
      expect(hasil.total, 20500);
    });

    test('kembalian tidak pernah dianggap total', () {
      const teks = '''
WARUNG BU SRI
TOTAL     25.000
KEMBALI  975.000
''';

      // Kembalian jauh lebih besar, tapi jelas bukan yang dibayar.
      expect(parseReceipt(teks, now: _now).total, 25000);
    });

    test('grand total menang atas subtotal', () {
      const teks = '''
KAFE KOPI
SUBTOTAL       50.000
PPN 11%         5.500
GRAND TOTAL    55.500
''';

      expect(parseReceipt(teks, now: _now).total, 55500);
    });

    test('total bayar dikenali', () {
      const teks = '''
ALFAMART
TOTAL BAYAR   37.900
''';
      expect(parseReceipt(teks, now: _now).total, 37900);
    });

    test('nominal di baris berikutnya tetap terbaca', () {
      const teks = '''
TOKO SERBA ADA
TOTAL
45.000
''';
      expect(parseReceipt(teks, now: _now).total, 45000);
    });

    test('jumlah item di baris total tidak tertukar dengan harga', () {
      const teks = '''
MINIMARKET
TOTAL ITEM 3
TOTAL      67.500
''';

      // "TOTAL ITEM" ditolak, dan angka 3 terlalu kecil untuk dianggap harga.
      expect(parseReceipt(teks, now: _now).total, 67500);
    });

    test('struk tanpa kata total menghasilkan null, bukan tebakan asal', () {
      const teks = '''
WARUNG PECEL
NASI PECEL   12.000
ES TEH        3.000
''';

      // Lebih baik mengaku tidak tahu daripada memilih angka acak.
      expect(parseReceipt(teks, now: _now).total, isNull);
    });

    test('diskon tidak dianggap total', () {
      const teks = '''
TOKO BAJU
TOTAL DISKON   10.000
TOTAL         140.000
''';
      expect(parseReceipt(teks, now: _now).total, 140000);
    });
  });

  group('parseReceipt — tanggal', () {
    test('format dd/mm/yyyy', () {
      expect(
        parseReceipt('TOKO\n25/07/2026\nTOTAL 10.000', now: _now).date,
        DateTime(2026, 7, 25),
      );
    });

    test('format dd-mm-yy', () {
      expect(
        parseReceipt('TOKO\n25-07-26\nTOTAL 10.000', now: _now).date,
        DateTime(2026, 7, 25),
      );
    });

    test('tanggal dari masa depan ditolak', () {
      // Struk tidak mungkin dari besok; itu pasti salah baca.
      expect(
        parseReceipt('TOKO\n25/12/2026\nTOTAL 10.000', now: _now).date,
        isNull,
      );
    });

    test('tanggal terlalu lampau ditolak', () {
      expect(
        parseReceipt('TOKO\n25/07/2020\nTOTAL 10.000', now: _now).date,
        isNull,
      );
    });

    test('tanggal mustahil ditolak', () {
      expect(parseReceipt('TOKO\n31/02/2026', now: _now).date, isNull);
      expect(parseReceipt('TOKO\n45/13/2026', now: _now).date, isNull);
    });

    test('tanpa tanggal menghasilkan null', () {
      expect(parseReceipt('TOKO\nTOTAL 10.000', now: _now).date, isNull);
    });
  });

  group('parseReceipt — nama tempat', () {
    test('baris pertama diambil sebagai nama', () {
      expect(
        parseReceipt('SUPERINDO\nJL SUDIRMAN 1\nTOTAL 10.000', now: _now).merchant,
        'SUPERINDO',
      );
    });

    test('baris alamat dilewati', () {
      final hasil = parseReceipt(
        'JL MERDEKA NO 12\nWARUNG BU SRI\nTOTAL 10.000',
        now: _now,
      );
      expect(hasil.merchant, 'WARUNG BU SRI');
    });

    test('baris yang isinya kebanyakan angka dilewati', () {
      final hasil = parseReceipt(
        '0812 3456 7890\nKEDAI KOPI\nTOTAL 10.000',
        now: _now,
      );
      expect(hasil.merchant, 'KEDAI KOPI');
    });

    test('baris telepon dan npwp dilewati', () {
      final hasil = parseReceipt(
        'TELP 021-555\nNPWP 12.345\nTOKO BUKU GRAMEDIA\nTOTAL 10.000',
        now: _now,
      );
      expect(hasil.merchant, 'TOKO BUKU GRAMEDIA');
    });
  });

  group('parseReceipt — ketahanan', () {
    test('teks kosong tidak error', () {
      final hasil = parseReceipt('', now: _now);
      expect(hasil.kosong, isTrue);
      expect(hasil.rawLines, isEmpty);
    });

    test('teks acak tidak menghasilkan tebakan palsu', () {
      final hasil = parseReceipt('asdf\nqwerty\n???', now: _now);
      expect(hasil.total, isNull);
      expect(hasil.date, isNull);
    });

    test('baris mentah disimpan untuk diperiksa sendiri', () {
      final hasil = parseReceipt('TOKO A\n\n  \nTOTAL 10.000', now: _now);
      // Baris kosong dibuang, sisanya utuh.
      expect(hasil.rawLines, ['TOKO A', 'TOTAL 10.000']);
    });

    test('struk lengkap terbaca ketiganya sekaligus', () {
      const teks = '''
ALFAMIDI
JL KALIURANG KM 5
TELP 0274-555123
02/08/2026 19:41

SUSU UHT 1L        18.500
SEREAL             25.000

TOTAL              43.500
DEBIT BCA          43.500
''';

      final hasil = parseReceipt(teks, now: _now);
      expect(hasil.merchant, 'ALFAMIDI');
      expect(hasil.date, DateTime(2026, 8, 2));
      expect(hasil.total, 43500);
      expect(hasil.kosong, isFalse);
    });
  });
}
