import 'package:flutter_test/flutter_test.dart';
import 'package:tracking/features/academic/data/models/class_schedule.dart';
import 'package:tracking/features/academic/data/models/course.dart';
import 'package:tracking/features/academic/domain/matkul_aktif.dart';

Course matkul(String id, String nama) => Course(
      id: id,
      userId: 'u1',
      name: nama,
      createdAt: DateTime(2026, 1, 1),
    );

ClassSchedule jadwal(String courseId) => ClassSchedule(
      id: 'j-$courseId',
      userId: 'u1',
      courseId: courseId,
      courseName: '-',
      dayOfWeek: 1,
      startTime: '07:00:00',
      endTime: '09:00:00',
    );

void main() {
  final semua = [
    matkul('c1', 'Algoritma dan Pemrograman'), // semester 1, sudah lewat
    matkul('c2', 'Kalkulus'), // semester 1, sudah lewat
    matkul('c3', 'Keamanan Cyber'), // semester ini
    matkul('c4', 'Pemrograman Backend Lanjut'), // semester ini
  ];

  group('matkulAktif', () {
    test('hanya mengembalikan mata kuliah yang punya jadwal', () {
      final hasil = matkulAktif(semua, [jadwal('c3'), jadwal('c4')]);

      expect(hasil.map((c) => c.id), ['c3', 'c4']);
    });

    test('satu mata kuliah dengan beberapa jadwal tetap muncul sekali', () {
      final hasil = matkulAktif(semua, [jadwal('c3'), jadwal('c3'), jadwal('c3')]);

      expect(hasil.map((c) => c.id), ['c3']);
    });

    test('tanpa satu jadwal pun, seluruh daftar dikembalikan', () {
      // Belum ada dasar untuk menyaring. Menyembunyikan semuanya cuma membuat
      // form tugas mustahil dipakai sebelum jadwal diisi.
      final hasil = matkulAktif(semua, const []);

      expect(hasil, semua);
    });

    test('jadwal untuk mata kuliah yang sudah dihapus tidak memunculkan apa pun', () {
      final hasil = matkulAktif(semua, [jadwal('c9')]);

      expect(hasil, isEmpty);
    });

    test('yang ada di tetap ikut walau jadwalnya sudah lewat', () {
      // Halaman absensi memakai ini: mata kuliah semester lalu yang sudah
      // terlanjur punya catatan kehadiran tidak boleh jadi tidak bisa dibuka.
      final hasil = matkulAktif(semua, [jadwal('c3')], tetap: {'c1'});

      expect(hasil.map((c) => c.id), ['c1', 'c3']);
    });

    test('urutannya tetap urutan daftar aslinya, bukan yang disisipkan di ujung', () {
      final hasil = matkulAktif(semua, [jadwal('c4')], tetap: {'c2'});

      expect(hasil.map((c) => c.id), ['c2', 'c4']);
    });

    test('tetap tidak menghidupkan id yang sudah tidak ada di daftar', () {
      final hasil = matkulAktif(semua, [jadwal('c3')], tetap: {'sudah-dihapus'});

      expect(hasil.map((c) => c.id), ['c3']);
    });

    test('tanpa jadwal, tetap tidak mempersempit daftar jadi isi tetap saja', () {
      // Kalau tidak begini, halaman yang belum punya jadwal cuma menampilkan
      // mata kuliah yang sudah tercatat — dan mata kuliah lain tidak akan
      // pernah bisa mulai dicatat.
      final hasil = matkulAktif(semua, const [], tetap: {'c1'});

      expect(hasil, semua);
    });
  });

  group('pilihanMatkul', () {
    test('mata kuliah yang sedang dipakai tugas lama tetap disertakan', () {
      // Tanpa ini, membuka tugas semester lalu menampilkan pilihan yang tidak
      // memuat mata kuliahnya sendiri — dan menyimpan ulang tugas itu diam-diam
      // melepas mata kuliahnya.
      final hasil = pilihanMatkul(semua, [jadwal('c3')], dipakai: 'c1');

      expect(hasil.map((c) => c.id), ['c1', 'c3']);
    });

    test('tidak menggandakan kalau yang dipakai memang masih aktif', () {
      final hasil = pilihanMatkul(semua, [jadwal('c3')], dipakai: 'c3');

      expect(hasil.map((c) => c.id), ['c3']);
    });

    test('id yang sudah tidak ada di daftar tidak menambah baris hantu', () {
      final hasil = pilihanMatkul(semua, [jadwal('c3')], dipakai: 'sudah-dihapus');

      expect(hasil.map((c) => c.id), ['c3']);
    });

    test('semuanya: true membuka kembali seluruh daftar', () {
      final hasil = pilihanMatkul(semua, [jadwal('c3')], semuanya: true);

      expect(hasil, semua);
    });
  });
}
