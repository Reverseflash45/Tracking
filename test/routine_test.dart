import 'package:flutter_test/flutter_test.dart';
import 'package:tracking/features/academic/data/models/class_schedule.dart';
import 'package:tracking/features/routine/domain/routine.dart';

RoutineItem kegiatan(
  String judul, {
  int hari = 1,
  String mulai = '07:00:00',
  String? selesai,
  KategoriRutinitas kategori = KategoriRutinitas.lainnya,
  String? catatan,
}) =>
    RoutineItem(
      id: '$hari-$mulai-$judul',
      userId: 'u1',
      dayOfWeek: hari,
      startTime: mulai,
      endTime: selesai,
      title: judul,
      category: kategori,
      note: catatan,
    );

ClassSchedule kelas(
  String nama, {
  int hari = 1,
  String mulai = '07:00:00',
  String selesai = '11:00:00',
  String? ruang,
  bool phl = false,
}) =>
    ClassSchedule(
      id: 'k-$nama',
      userId: 'u1',
      courseId: 'c-$nama',
      courseName: nama,
      dayOfWeek: hari,
      startTime: mulai,
      endTime: selesai,
      room: ruang,
      isPhl: phl,
      specificDate: phl ? DateTime(2026, 8, 20) : null,
    );

void main() {
  group('lineMasaHarian', () {
    test('rutinitas dan kelas digabung, terurut menurut jam', () {
      final baris = lineMasaHarian(
        hari: 1,
        rutinitas: [
          kegiatan('Bangun', mulai: '05:45:00', kategori: KategoriRutinitas.bangun),
          kegiatan('Makan siang', mulai: '11:15:00', kategori: KategoriRutinitas.makan),
          kegiatan('Workout A', mulai: '16:30:00', selesai: '17:30:00'),
        ],
        jadwal: [kelas('Backend Lanjut', mulai: '07:00:00', selesai: '11:00:00')],
      );

      expect(
        baris.map((b) => b.judul),
        ['Bangun', 'Backend Lanjut', 'Makan siang', 'Workout A'],
      );
    });

    test('hari lain tidak ikut', () {
      final baris = lineMasaHarian(
        hari: 2,
        rutinitas: [kegiatan('Senin saja', hari: 1)],
        jadwal: [kelas('Senin saja juga', hari: 1)],
      );

      expect(baris, isEmpty);
    });

    test('kelas ditandai berasal dari jadwal dan tidak bisa diubah di sini', () {
      final baris = lineMasaHarian(
        hari: 1,
        rutinitas: [kegiatan('Sarapan', mulai: '06:15:00')],
        jadwal: [kelas('Backend Lanjut', ruang: 'LAB Bahasa 1')],
      );

      final kuliah = baris.firstWhere((b) => b.dariKuliah);
      expect(kuliah.routineId, isNull);
      expect(kuliah.kategori, isNull);
      expect(kuliah.keterangan, 'LAB Bahasa 1');

      expect(baris.firstWhere((b) => !b.dariKuliah).routineId, isNotNull);
    });

    test('kelas pengganti (PHL) tidak ikut', () {
      // Halaman ini pola mingguan. PHL terjadi pada satu tanggal, jadi
      // menampilkannya di sini berarti kelas pengganti bulan lalu muncul tiap
      // minggu selamanya.
      final baris = lineMasaHarian(hari: 1, jadwal: [kelas('Pengganti', phl: true)]);

      expect(baris, isEmpty);
    });

    test('catatan kosong tidak jadi baris keterangan kosong', () {
      final baris = lineMasaHarian(
        hari: 1,
        rutinitas: [kegiatan('Santai', catatan: '   ')],
      );

      expect(baris.single.keterangan, isNull);
    });

    test('jam ditampilkan tanpa detik', () {
      final baris = lineMasaHarian(
        hari: 1,
        rutinitas: [kegiatan('Workout', mulai: '16:30:00', selesai: '17:30:00')],
      );

      expect(baris.single.mulai, '16:30');
      expect(baris.single.selesai, '17:30');
    });
  });

  group('durasi', () {
    test('kegiatan sesaat tidak punya durasi, dan itu bukan nol', () {
      final baris = lineMasaHarian(hari: 1, rutinitas: [kegiatan('Bangun', mulai: '05:45:00')]);

      expect(baris.single.durasiMenit, isNull);
    });

    test('rentang biasa dihitung dalam menit', () {
      final baris = lineMasaHarian(
        hari: 1,
        rutinitas: [kegiatan('Kerja', mulai: '12:00:00', selesai: '15:00:00')],
      );

      expect(baris.single.durasiMenit, 180);
    });

    test('melewati tengah malam tidak jadi durasi negatif', () {
      final baris = lineMasaHarian(
        hari: 1,
        rutinitas: [kegiatan('Tidur', mulai: '22:30:00', selesai: '05:45:00')],
      );

      expect(baris.single.durasiMenit, 435);
    });

    test('menitTerisi melewatkan kegiatan yang tidak punya jam selesai', () {
      // Angkanya "jam terisi", bukan "jam sibuk". Kegiatan sesaat memang tidak
      // diketahui panjangnya, dan menghitungnya nol sama bohongnya dengan
      // menebaknya satu jam.
      final baris = lineMasaHarian(
        hari: 1,
        rutinitas: [
          kegiatan('Bangun', mulai: '05:45:00'),
          kegiatan('Kerja', mulai: '12:00:00', selesai: '15:00:00'),
        ],
        jadwal: [kelas('Backend', mulai: '07:00:00', selesai: '11:00:00')],
      );

      expect(menitTerisi(baris), 180 + 240);
    });
  });

  group('labelDurasi', () {
    test('kurang dari sejam ditulis menit saja', () {
      expect(labelDurasi(45), '45m');
    });

    test('jam bulat tidak menyeret nol menit', () {
      expect(labelDurasi(120), '2j');
    });

    test('jam dan menit ditulis dua-duanya', () {
      expect(labelDurasi(210), '3j 30m');
    });

    test('kosong tetap punya bentuk yang bisa ditampilkan', () {
      expect(labelDurasi(0), '0m');
    });
  });

  group('hariTerisi', () {
    test('hanya hari yang punya rutinitas, kelas tidak ikut menghitung', () {
      // Titik penanda di pemilih hari menjawab "hari mana yang sudah kususun",
      // bukan "hari mana yang ada kelasnya" — yang kedua sudah dijawab halaman
      // Jadwal.
      final hasil = hariTerisi([
        kegiatan('Bangun', hari: 1),
        kegiatan('Tidur', hari: 1),
        kegiatan('Workout', hari: 3),
      ]);

      expect(hasil, {1, 3});
    });

    test('tanpa rutinitas sama sekali menghasilkan himpunan kosong', () {
      expect(hariTerisi(const []), isEmpty);
    });
  });

  group('KategoriRutinitas.fromDb', () {
    test('nilai tidak dikenal jatuh ke lainnya, bukan melempar', () {
      expect(KategoriRutinitas.fromDb(null), KategoriRutinitas.lainnya);
      expect(KategoriRutinitas.fromDb('entah'), KategoriRutinitas.lainnya);
      expect(KategoriRutinitas.fromDb('workout'), KategoriRutinitas.workout);
    });
  });
}
