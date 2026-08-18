import 'package:flutter_test/flutter_test.dart';
import 'package:tracking/features/academic/data/models/task.dart';
import 'package:tracking/features/academic/domain/arsip_tugas.dart';

AcademicTask tugas(
  String id, {
  String? courseId,
  String? courseName,
  TaskKind kind = TaskKind.kuliah,
  TaskStatus status = TaskStatus.todo,
  DateTime? deadline,
}) =>
    AcademicTask(
      id: id,
      userId: 'u1',
      courseId: courseId,
      courseName: courseName,
      kind: kind,
      title: 'Tugas $id',
      deadline: deadline ?? DateTime(2026, 8, 20),
      priority: TaskPriority.medium,
      status: status,
      createdAt: DateTime(2026, 8, 1),
    );

void main() {
  group('pengelompokan', () {
    test('tugas dikelompokkan per mata kuliah', () {
      final hasil = arsipTugas([
        tugas('a', courseId: 'c1', courseName: 'Keamanan Cyber'),
        tugas('b', courseId: 'c1', courseName: 'Keamanan Cyber'),
        tugas('c', courseId: 'c2', courseName: 'Aljabar Linier'),
      ]);

      expect(hasil.length, 2);
      expect(hasil.firstWhere((m) => m.courseId == 'c1').total, 2);
      expect(hasil.firstWhere((m) => m.courseId == 'c2').total, 1);
    });

    test('tugas pribadi tidak ikut sama sekali', () {
      // Halaman ini menjawab "mata kuliah ini tugasnya apa saja". Tugas pribadi
      // memang tidak punya mata kuliah, dan menaruhnya di kelompok "tanpa mata
      // kuliah" membuatnya tercampur dengan tugas kuliah yang matkulnya lupa
      // dipilih — dua hal yang berbeda.
      final hasil = arsipTugas([
        tugas('a', courseId: 'c1', courseName: 'Keamanan Cyber'),
        tugas('b', kind: TaskKind.pribadi),
      ]);

      expect(hasil.length, 1);
      expect(hasil.single.total, 1);
    });

    test('tugas kuliah tanpa mata kuliah punya kelompoknya sendiri', () {
      final hasil = arsipTugas([tugas('a')]);

      expect(hasil.single.courseId, isNull);
      expect(hasil.single.nama, 'Tanpa mata kuliah');
    });

    test('mata kuliah aktif tetap muncul walau belum punya tugas', () {
      // "Belum pernah kamu tulis" adalah jawaban yang berbeda dari "tidak ada",
      // dan mata kuliah yang menghilang dari daftar cuma menyampaikan yang
      // kedua.
      final hasil = arsipTugas(
        [tugas('a', courseId: 'c1', courseName: 'Keamanan Cyber')],
        matkulAktif: {'c1': 'Keamanan Cyber', 'c2': 'Aljabar Linier'},
      );

      final kosong = hasil.firstWhere((m) => m.courseId == 'c2');
      expect(kosong.total, 0);
      expect(kosong.progres, isNull, reason: 'belum ada tugas bukan berarti 0%');
    });

    test('nama dari daftar mata kuliah menang atas nama yang menempel di tugas', () {
      final hasil = arsipTugas(
        [tugas('a', courseId: 'c1', courseName: 'Nama Lama')],
        matkulAktif: {'c1': 'Nama Baru'},
      );

      expect(hasil.single.nama, 'Nama Baru');
    });
  });

  group('hitungan', () {
    test('belum, proses, dan selesai dihitung terpisah', () {
      final hasil = arsipTugas([
        tugas('a', courseId: 'c1', status: TaskStatus.todo),
        tugas('b', courseId: 'c1', status: TaskStatus.inProgress),
        tugas('c', courseId: 'c1', status: TaskStatus.done),
        tugas('d', courseId: 'c1', status: TaskStatus.done),
      ]);

      final m = hasil.single;
      expect(m.belum, 1);
      expect(m.proses, 1);
      expect(m.selesai, 2);
      expect(m.belumSelesai, 2, reason: 'yang sedang diproses belum selesai');
      expect(m.progres, 0.5);
    });
  });

  group('urutan', () {
    test('yang belum selesai naik di atas yang sudah tuntas', () {
      final hasil = arsipTugas([
        tugas('a', courseId: 'c1', courseName: 'Aljabar', status: TaskStatus.done),
        tugas('b', courseId: 'c2', courseName: 'Zoologi', status: TaskStatus.todo),
      ]);

      expect(hasil.map((m) => m.courseId), ['c2', 'c1']);
    });

    test('mata kuliah tanpa tugas duduk di antara keduanya', () {
      // Belum punya tugas lebih sering berarti lupa mencatat daripada memang
      // tidak ada, jadi dia tidak boleh tenggelam bersama yang sudah tuntas.
      final hasil = arsipTugas(
        [
          tugas('a', courseId: 'c1', status: TaskStatus.done),
          tugas('b', courseId: 'c3', status: TaskStatus.todo),
        ],
        matkulAktif: {'c1': 'Satu', 'c2': 'Dua', 'c3': 'Tiga'},
      );

      expect(hasil.map((m) => m.courseId), ['c3', 'c2', 'c1']);
    });

    test('mata kuliah setingkat diurut alfabetis', () {
      final hasil = arsipTugas([
        tugas('a', courseId: 'c1', courseName: 'Zoologi'),
        tugas('b', courseId: 'c2', courseName: 'aljabar'),
      ]);

      expect(hasil.map((m) => m.nama), ['aljabar', 'Zoologi']);
    });

    test('di dalam satu matkul, yang belum selesai diurut deadline terdekat', () {
      final hasil = arsipTugas([
        tugas('jauh', courseId: 'c1', deadline: DateTime(2026, 9, 1)),
        tugas('dekat', courseId: 'c1', deadline: DateTime(2026, 8, 19)),
      ]);

      expect(hasil.single.tugas.map((t) => t.id), ['dekat', 'jauh']);
    });

    test('yang sudah selesai turun ke bawah, terbaru lebih dulu', () {
      final hasil = arsipTugas([
        tugas('lama', courseId: 'c1', status: TaskStatus.done, deadline: DateTime(2026, 7, 1)),
        tugas('baru', courseId: 'c1', status: TaskStatus.done, deadline: DateTime(2026, 8, 1)),
        tugas('belum', courseId: 'c1', deadline: DateTime(2026, 9, 1)),
      ]);

      expect(hasil.single.tugas.map((t) => t.id), ['belum', 'baru', 'lama']);
    });
  });
}
