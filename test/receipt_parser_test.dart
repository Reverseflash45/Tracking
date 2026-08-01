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

    test('total pembayaran struk digital dikenali', () {
      // Bentuk ini muncul setelah baris hasil OCR disusun ulang dari posisinya
      // di layar — sebelum itu label dan nominalnya ada di blok terpisah.
      const teks = '''
Rincian Pesananmu
Subtotal  Rp45.000
Ongkos Kirim  Rp10.000
Total Pembayaran  Rp55.000
''';
      expect(parseReceipt(teks, now: _now).total, 55000);
    });

    test('total koin dan total hemat bukan uang yang keluar', () {
      const teks = '''
Total Hemat  Rp12.000
Total Koin  Rp500
Total Pembayaran  Rp38.000
''';
      expect(parseReceipt(teks, now: _now).total, 38000);
    });

    test('tahun pada tanggal tidak tertukar jadi nominal', () {
      const teks = '''
TOKO
TOTAL
01/08/2026
''';
      // 2026 angkanya cukup besar untuk lolos sebagai harga kalau tidak
      // dikenali sebagai potongan tanggal.
      expect(parseReceipt(teks, now: _now).total, isNull);
    });
  });

  group('parseReceipt — kandidat nominal', () {
    test('ditawarkan saat total tidak ketemu, terbesar dulu', () {
      const teks = '''
WARUNG PECEL
NASI PECEL   12.000
ES TEH        3.000
GORENGAN      5.000
''';

      final hasil = parseReceipt(teks, now: _now);
      expect(hasil.total, isNull);
      expect(hasil.candidates, [12000, 5000, 3000]);
    });

    test('tidak ditawarkan saat totalnya sudah ketemu', () {
      final hasil = parseReceipt('TOKO\nNASI 12.000\nTOTAL 12.000', now: _now);
      expect(hasil.total, 12000);
      expect(hasil.candidates, isEmpty);
    });

    test('angka yang sama tidak ditawarkan dua kali', () {
      const teks = '''
KEDAI
KOPI    18.000
KOPI    18.000
''';
      expect(parseReceipt(teks, now: _now).candidates, [18000]);
    });

    test('jam dan tanggal tidak ikut jadi kandidat', () {
      const teks = '''
KEDAI
03/08/2026 14:22
KOPI 18.000
''';
      expect(parseReceipt(teks, now: _now).candidates, [18000]);
    });

    test('jumlahnya dibatasi supaya tidak jadi daftar belanja', () {
      final baris = [
        for (var i = 1; i <= 12; i++) 'ITEM $i  ${i * 1000}',
      ].join('\n');

      final hasil = parseReceipt('TOKO\n$baris', now: _now);
      expect(hasil.candidates, hasLength(6));
      expect(hasil.candidates.first, 12000);
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

    test('judul halaman aplikasi tidak dianggap nama tempat', () {
      // Ini yang sebelumnya tercatat sebagai "tempat": judul halaman.
      const teks = '''
19.00  22:04
Rincian Pesananmu
Tambah Layar Utama
Total Pembayaran  Rp55.000
''';

      final hasil = parseReceipt(teks, now: _now);
      expect(hasil.merchant, isNull);
      // Yang penting tetap kebaca.
      expect(hasil.total, 55000);
    });

    test('kalimat iklan huruf kecil semua bukan nama tempat', () {
      final hasil = parseReceipt(
        'jadi lebih cepat dan mudah\nWARUNG MBAK YUS\nTOTAL 15.000',
        now: _now,
      );
      expect(hasil.merchant, 'WARUNG MBAK YUS');
    });

    test('satuan di baris status HP bukan nama tempat', () {
      final hasil = parseReceipt('KB/S\nKEDAI SUSU\nTOTAL 9.000', now: _now);
      expect(hasil.merchant, 'KEDAI SUSU');
    });

    test('nama layanan dipakai kalau kepala struknya tidak ada yang layak', () {
      final hasil = parseReceipt(
        'Rincian Pesananmu\nTambah ShopeeFood ke Layar Utama\nPaid Rp20.000',
        now: _now,
      );
      expect(hasil.merchant, 'ShopeeFood');
    });

    test('nama warung tetap menang atas nama layanan', () {
      final hasil = parseReceipt(
        'WARUNG SATE PAK NO\nDipesan lewat GoFood\nTOTAL 30.000',
        now: _now,
      );
      expect(hasil.merchant, 'WARUNG SATE PAK NO');
    });

    test('baris berisi harga tidak dianggap nama tempat', () {
      final hasil = parseReceipt(
        'Ongkos Kirim  Rp10.000\nWARUNG SATE PAK NO\nTOTAL 35.000',
        now: _now,
      );
      expect(hasil.merchant, 'WARUNG SATE PAK NO');
    });

    test('tidak ada yang layak berarti dikosongkan, bukan diisi asal', () {
      final hasil = parseReceipt('12345\nJL MERDEKA 1\nTOTAL 10.000', now: _now);
      expect(hasil.merchant, isNull);
    });
  });

  group('parseReceipt — struk ShopeeFood sungguhan', () {
    // Disalin apa adanya dari hasil OCR di HP, termasuk salah bacanya
    // ("Rp&.500", "Biaya Pengiriman O"). Ini kasus yang gagal total sebelumnya:
    // nominal kosong, tempat terisi "KB/S", dan nomor pesanan tampil sebagai
    // pilihan Rp3.198.462.280.678.912.000.
    const teks = '''
21:45  803
18.59  i 62
KB/S
Rincian Pesananmu
Tambah ShopeeFood ke Layar Utama
Pesan makan di ShopeeFood   Tambah
jadi lebih cepat dan mudah
Rincian Pesanan
MN3RASN 1x Martabak telor istimewa  Rp60.000
mix 3 rasa  Rp6.100
Subtotal Pesanan (1 menu)  Rp60.000
Voucher Diskon  -Rp10.000
Biaya Pengiriman O  Rp&.500 Rp3.500
Biaya Layanan  Rp1.000
Paid  Rp54.500
Sudah termasuk pajak
Informasi Pesanan
Catatan Tambahan  Tidak ada
No. Pesanan  3198462280678912001 SALIN
Waktu Pemesanan  1 Agt 2026 18:24
Waktu Pembayaran  1 Agt 2026 18:24
Pembayaran  SeaBank Bayar Instan
Beri Nilai & Tip  Pesan lagi
''';

    test('"Paid" dikenali sebagai total, bukan subtotal', () {
      // Tidak ada kata "total" di struk ini selain "Subtotal Pesanan", yang
      // justru harus ditolak. Yang dibayar Rp54.500, bukan Rp60.000.
      expect(parseReceipt(teks, now: _now).total, 54500);
    });

    test('nama layanan terbaca, bukan "KB/S"', () {
      expect(parseReceipt(teks, now: _now).merchant, 'ShopeeFood');
    });

    test('tanggal bertulis "1 Agt 2026" terbaca', () {
      expect(parseReceipt(teks, now: _now).date, DateTime(2026, 8, 1));
    });

    test('nomor pesanan tidak ikut jadi angka pilihan', () {
      // Totalnya ketemu jadi kandidat kosong, tapi kalaupun ditawarkan,
      // nomor pesanan tidak boleh ada di dalamnya.
      final semua = parseReceipt(
        teks.replaceAll('Paid  Rp54.500', 'Rp54.500'),
        now: _now,
      );
      expect(semua.candidates, isNot(contains(3198462280678912001)));
      expect(semua.candidates, contains(54500));
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
