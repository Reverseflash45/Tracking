import 'package:flutter_test/flutter_test.dart';
import 'package:tracking/features/attendance/domain/attendance.dart';

Attendance _catat(String courseId, StatusKehadiran status, int hari) => Attendance(
      id: '$courseId-$hari',
      userId: 'u',
      courseId: courseId,
      meetingDate: DateTime(2026, 3, hari),
      status: status,
    );

void main() {
  group('rekapKehadiran', () {
    test('menghitung tiap status terpisah', () {
      final rekap = rekapKehadiran(
        catatan: [
          _catat('a', StatusKehadiran.hadir, 1),
          _catat('a', StatusKehadiran.hadir, 8),
          _catat('a', StatusKehadiran.izin, 15),
          _catat('a', StatusKehadiran.sakit, 22),
          _catat('a', StatusKehadiran.alpa, 29),
        ],
        courseIds: ['a'],
      ).single;

      expect(rekap.hadir, 2);
      expect(rekap.izin, 1);
      expect(rekap.sakit, 1);
      expect(rekap.alpa, 1);
      expect(rekap.tercatat, 5);
      expect(rekap.tidakHadir, 3, reason: 'izin, sakit, dan alpa');
    });

    test('mata kuliah tanpa catatan tetap muncul dengan angka nol', () {
      final rekap = rekapKehadiran(catatan: const [], courseIds: ['a', 'b']);

      expect(rekap.length, 2);
      expect(rekap.every((r) => r.tercatat == 0), isTrue);
    });

    test('belum ada catatan berarti persennya null, bukan nol', () {
      final rekap = rekapKehadiran(catatan: const [], courseIds: ['a']).single;

      expect(rekap.persenKehadiran, isNull,
          reason: 'belum mencatat tidak sama dengan tidak pernah hadir');
    });

    test('persen kehadiran dihitung dari yang tercatat saja', () {
      final rekap = rekapKehadiran(
        catatan: [
          _catat('a', StatusKehadiran.hadir, 1),
          _catat('a', StatusKehadiran.hadir, 8),
          _catat('a', StatusKehadiran.hadir, 15),
          _catat('a', StatusKehadiran.alpa, 22),
        ],
        courseIds: ['a'],
      ).single;

      expect(rekap.persenKehadiran, 75);
    });
  });

  group('jatah tidak masuk', () {
    RekapKehadiran buat({
      int hadir = 0,
      int izin = 0,
      int sakit = 0,
      int alpa = 0,
      int? total,
      int? persen,
    }) =>
        RekapKehadiran(
          courseId: 'a',
          hadir: hadir,
          izin: izin,
          sakit: sakit,
          alpa: alpa,
          totalPertemuan: total,
          maksAbsenPersen: persen,
        );

    test('tanpa jumlah pertemuan, jatahnya tidak ditebak', () {
      final rekap = buat(hadir: 5, alpa: 2);

      expect(rekap.jatahTidakHadir, isNull);
      expect(rekap.sisaJatah, isNull);
      expect(rekap.belumTercatat, isNull);
      expect(rekap.statusJatah, StatusJatah.belumDiketahui,
          reason: 'angka jatah yang salah lebih berbahaya daripada tidak ada angka');
    });

    test('16 pertemuan dengan batas 25% berarti jatahnya 4', () {
      expect(buat(total: 16).jatahTidakHadir, 4);
    });

    test('batas persen bisa diubah per mata kuliah', () {
      expect(buat(total: 16, persen: 20).jatahTidakHadir, 3);
    });

    test('jatah dibulatkan ke bawah', () {
      // 14 x 25% = 3.5. Membulatkannya ke atas berarti memberi satu jatah yang
      // sebenarnya tidak ada.
      expect(buat(total: 14).jatahTidakHadir, 3);
    });

    test('sisa jatah berkurang oleh izin dan sakit, bukan cuma alpa', () {
      final rekap = buat(hadir: 10, izin: 1, sakit: 1, alpa: 1, total: 16);

      expect(rekap.tidakHadir, 3);
      expect(rekap.sisaJatah, 1);
    });

    test('sisa satu pertemuan sudah dianggap hampir habis', () {
      expect(buat(hadir: 10, alpa: 3, total: 16).statusJatah, StatusJatah.hampir);
    });

    test('sisa dua pertemuan masih aman', () {
      expect(buat(hadir: 10, alpa: 2, total: 16).statusJatah, StatusJatah.aman);
    });

    test('lewat jatah ditampilkan negatif apa adanya', () {
      final rekap = buat(hadir: 5, alpa: 6, total: 16);

      expect(rekap.sisaJatah, -2);
      expect(rekap.statusJatah, StatusJatah.lewat);
    });

    test('pertemuan yang belum dicatat dihitung, dan tidak pernah negatif', () {
      expect(buat(hadir: 5, total: 16).belumTercatat, 11);
      expect(buat(hadir: 20, total: 16).belumTercatat, 0,
          reason: 'catatan lebih banyak dari jumlah pertemuan berarti salah isi, '
              'bukan pertemuan negatif');
    });
  });

  group('urutkanRekap', () {
    String nama(String id) => id;

    test('yang lewat jatah lebih dulu, yang belum diketahui paling belakang', () {
      final urut = urutkanRekap([
        const RekapKehadiran(courseId: 'aman', hadir: 10, izin: 0, sakit: 0, alpa: 0, totalPertemuan: 16),
        const RekapKehadiran(courseId: 'takTahu', hadir: 1, izin: 0, sakit: 0, alpa: 9),
        const RekapKehadiran(courseId: 'lewat', hadir: 2, izin: 0, sakit: 0, alpa: 6, totalPertemuan: 16),
        const RekapKehadiran(courseId: 'hampir', hadir: 5, izin: 0, sakit: 0, alpa: 3, totalPertemuan: 16),
      ], nama);

      expect(urut.map((r) => r.courseId).toList(), ['lewat', 'hampir', 'aman', 'takTahu']);
    });

    test('dalam status sama, sisa paling sedikit lebih dulu', () {
      final urut = urutkanRekap([
        const RekapKehadiran(courseId: 'sisa3', hadir: 9, izin: 0, sakit: 0, alpa: 1, totalPertemuan: 16),
        const RekapKehadiran(courseId: 'sisa2', hadir: 8, izin: 0, sakit: 0, alpa: 2, totalPertemuan: 16),
      ], nama);

      expect(urut.first.courseId, 'sisa2');
    });
  });
}
