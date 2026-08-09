import 'package:flutter_test/flutter_test.dart';
import 'package:tracking/features/academic/data/models/task.dart';

AcademicTask tugas({
  TaskStatus status = TaskStatus.todo,
  DateTime? completedAt,
}) =>
    AcademicTask(
      id: 't1',
      userId: 'u1',
      courseId: 'c1',
      courseName: 'Keamanan Cyber',
      kind: TaskKind.kuliah,
      title: 'Laporan Praktikum Bab 3',
      description: 'Kumpulkan lewat portal',
      deadline: DateTime(2026, 8, 20, 23, 59),
      priority: TaskPriority.high,
      status: status,
      createdAt: DateTime(2026, 8, 1),
      completedAt: completedAt,
      recurringId: 'r1',
      recurringOn: DateTime(2026, 8, 18),
    );

void main() {
  group('TaskKind.fromDb', () {
    test('nilai yang tidak dikenal jatuh ke kuliah, bukan melempar', () {
      // Kolomnya baru ada sejak migrasi 0024. Baris lama — dan HP yang belum
      // menjalankan migrasinya — mengirim null, dan itu harus tetap terbaca.
      expect(TaskKind.fromDb(null), TaskKind.kuliah);
      expect(TaskKind.fromDb('entah'), TaskKind.kuliah);
      expect(TaskKind.fromDb('pribadi'), TaskKind.pribadi);
    });
  });

  group('denganStatus', () {
    test('menandai selesai ikut mengisi waktu penyelesaian', () {
      final hasil = tugas().denganStatus(TaskStatus.done);

      expect(hasil.status, TaskStatus.done);
      expect(hasil.completedAt, isNotNull);
    });

    test('waktu penyelesaian yang sudah ada tidak digeser ulang', () {
      final semula = DateTime(2026, 8, 19, 10);
      final hasil = tugas(status: TaskStatus.done, completedAt: semula)
          .denganStatus(TaskStatus.done);

      expect(hasil.completedAt, semula);
    });

    test('membatalkan selesai ikut menghapus waktu penyelesaiannya', () {
      // Kalau tidak, tugas yang dibatalkan tetap terhitung selesai tepat waktu
      // di rekap — dan angkanya jadi bohong.
      final hasil = tugas(status: TaskStatus.done, completedAt: DateTime(2026, 8, 19))
          .denganStatus(TaskStatus.todo);

      expect(hasil.status, TaskStatus.todo);
      expect(hasil.completedAt, isNull);
      expect(hasil.isOnTime, isFalse);
    });

    test('tidak ada isi lain yang ikut berubah', () {
      final asli = tugas();
      final hasil = asli.denganStatus(TaskStatus.inProgress);

      expect(hasil.id, asli.id);
      expect(hasil.courseId, asli.courseId);
      expect(hasil.courseName, asli.courseName);
      expect(hasil.kind, asli.kind);
      expect(hasil.title, asli.title);
      expect(hasil.description, asli.description);
      expect(hasil.deadline, asli.deadline);
      expect(hasil.priority, asli.priority);
      expect(hasil.createdAt, asli.createdAt);
      expect(hasil.recurringId, asli.recurringId);
      expect(hasil.recurringOn, asli.recurringOn);
    });
  });
}
