import 'package:flutter_test/flutter_test.dart';
import 'package:tracking/features/note/domain/note.dart';

Note catatan({
  String id = 'n1',
  String? title,
  String body = '',
  bool pinned = false,
  DateTime? diubah,
}) =>
    Note(
      id: id,
      userId: 'u1',
      title: title,
      body: body,
      pinned: pinned,
      createdAt: DateTime(2026, 8, 1),
      updatedAt: diubah ?? DateTime(2026, 8, 1),
    );

void main() {
  group('judul dan cuplikan', () {
    test('judul yang diisi dipakai apa adanya', () {
      final note = catatan(title: 'Wifi kos', body: 'kosanpakdhe2024');

      expect(note.judul, 'Wifi kos');
      expect(note.cuplikan, 'kosanpakdhe2024');
    });

    test('tanpa judul, baris pertama isinya yang jadi judul', () {
      // Catatan cepat sering langsung isinya. Menampilkan "Tanpa judul" untuk
      // catatan yang isinya jelas cuma menyembunyikan isinya sendiri.
      final note = catatan(body: 'Nomor rekening Rian\n1234567890 BCA');

      expect(note.judul, 'Nomor rekening Rian');
      expect(note.cuplikan, '1234567890 BCA');
    });

    test('baris pertama tidak ditulis dua kali saat dia jadi judul', () {
      final note = catatan(body: 'Cuma satu baris');

      expect(note.judul, 'Cuma satu baris');
      expect(note.cuplikan, isEmpty);
    });

    test('judul kosong berisi spasi diperlakukan sama dengan tidak ada', () {
      final note = catatan(title: '   ', body: 'Isi catatan');

      expect(note.judul, 'Isi catatan');
      expect(note.cuplikan, isEmpty);
    });

    test('baris kosong di tengah tidak menghasilkan cuplikan berlubang', () {
      final note = catatan(body: 'Judul\n\n\nIsi satu\n\nIsi dua');

      expect(note.judul, 'Judul');
      expect(note.cuplikan, 'Isi satu Isi dua');
    });

    test('benar-benar kosong tetap punya judul yang bisa ditampilkan', () {
      final note = catatan();

      expect(note.judul, 'Tanpa judul');
      expect(note.cuplikan, isEmpty);
      expect(note.kosong, isTrue);
    });

    test('punya judul saja sudah bukan catatan kosong', () {
      expect(catatan(title: 'Nanti diisi').kosong, isFalse);
    });
  });

  group('urutkanCatatan', () {
    test('yang disematkan naik ke atas walau paling lama diubah', () {
      final hasil = urutkanCatatan([
        catatan(id: 'baru', diubah: DateTime(2026, 8, 19)),
        catatan(id: 'sematan', pinned: true, diubah: DateTime(2026, 1, 1)),
      ]);

      expect(hasil.map((n) => n.id), ['sematan', 'baru']);
    });

    test('di dalam tiap kelompok, yang terakhir diubah lebih dulu', () {
      final hasil = urutkanCatatan([
        catatan(id: 'lama', diubah: DateTime(2026, 8, 1)),
        catatan(id: 'baru', diubah: DateTime(2026, 8, 19)),
        catatan(id: 'sematan-lama', pinned: true, diubah: DateTime(2026, 7, 1)),
        catatan(id: 'sematan-baru', pinned: true, diubah: DateTime(2026, 8, 10)),
      ]);

      expect(
        hasil.map((n) => n.id),
        ['sematan-baru', 'sematan-lama', 'baru', 'lama'],
      );
    });

    test('daftar aslinya tidak ikut berubah urutannya', () {
      final asli = [
        catatan(id: 'a', diubah: DateTime(2026, 8, 1)),
        catatan(id: 'b', diubah: DateTime(2026, 8, 19)),
      ];
      urutkanCatatan(asli);

      expect(asli.map((n) => n.id), ['a', 'b']);
    });
  });

  group('cariCatatan', () {
    final daftar = [
      catatan(id: 'a', title: 'Wifi kos', body: 'kosanpakdhe2024'),
      catatan(id: 'b', body: 'Ide skripsi: deteksi pose buat koreksi form'),
      catatan(id: 'c', title: 'Belanja', body: 'beras, telur, minyak'),
    ];

    test('mencari di judul maupun isi', () {
      expect(cariCatatan(daftar, 'wifi').map((n) => n.id), ['a']);
      expect(cariCatatan(daftar, 'skripsi').map((n) => n.id), ['b']);
    });

    test('tidak peduli huruf besar-kecil', () {
      expect(cariCatatan(daftar, 'BELANJA').map((n) => n.id), ['c']);
    });

    test('kueri kosong mengembalikan semuanya, bukan tidak ada', () {
      expect(cariCatatan(daftar, '   ').length, 3);
    });

    test('yang tidak cocok tidak ikut', () {
      expect(cariCatatan(daftar, 'motor'), isEmpty);
    });
  });
}
