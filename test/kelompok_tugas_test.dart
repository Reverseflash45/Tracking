import 'package:flutter_test/flutter_test.dart';
import 'package:tracking/features/academic/data/models/task.dart';
import 'package:tracking/features/academic/presentation/tasks_page.dart';

/// Tenggat dibuat persis seperti yang datang dari Supabase: jam dinding yang
/// ditandai UTC (akhiran +00:00).
AcademicTask tugas(String id, DateTime tenggatDinding, {TaskStatus status = TaskStatus.todo}) {
  return AcademicTask(
    id: id,
    userId: 'u',
    kind: TaskKind.kuliah,
    title: id,
    deadline: DateTime.utc(
      tenggatDinding.year,
      tenggatDinding.month,
      tenggatDinding.day,
      tenggatDinding.hour,
      tenggatDinding.minute,
    ),
    priority: TaskPriority.medium,
    status: status,
    createdAt: DateTime(2026),
  );
}

void main() {
  // Senin, 28 September 2026, pukul 02.40.
  final sekarang = DateTime(2026, 9, 28, 2, 40);

  List<String> judulKelompok(List<AcademicTask> t) =>
      [for (final (judul, _, _) in kelompokkanTugas(t, sekarang: sekarang)) judul];

  List<String> isi(List<AcademicTask> t, String judul) => [
    for (final (j, daftar, _) in kelompokkanTugas(t, sekarang: sekarang))
      if (j == judul) ...daftar.map((x) => x.id),
  ];

  test('tenggat besok 23.59 masuk "Besok", bukan "Minggu ini"', () {
    // Dulu tenggat dibandingkan sebagai instan UTC, sehingga 29 Sep 23.59
    // terbaca 30 Sep 06.59 WIB dan jatuh ke kelompok yang salah.
    final t = [tugas('a', DateTime(2026, 9, 29, 23, 59))];
    expect(isi(t, 'Besok'), ['a']);
  });

  test('urutan kelompok mengikuti waktu, selesai paling akhir', () {
    final t = [
      tugas('nanti', DateTime(2026, 10, 9, 23, 59)),
      tugas('selesai', DateTime(2026, 9, 20), status: TaskStatus.done),
      tugas('telat', DateTime(2026, 9, 27, 23, 59)),
      tugas('hariini', DateTime(2026, 9, 28, 23, 59)),
      tugas('minggu', DateTime(2026, 10, 2, 12)),
    ];
    expect(judulKelompok(t), ['Terlambat', 'Hari ini', 'Minggu ini', 'Nanti', 'Selesai']);
  });

  test('Minggu malam masih "Minggu ini", Senin depan sudah "Nanti"', () {
    final t = [
      tugas('minggu', DateTime(2026, 10, 4, 23, 59)),
      tugas('senin', DateTime(2026, 10, 5, 8)),
    ];
    expect(isi(t, 'Minggu ini'), ['minggu']);
    expect(isi(t, 'Nanti'), ['senin']);
  });

  test('kelompok kosong tidak ditampilkan', () {
    expect(kelompokkanTugas(const [], sekarang: sekarang), isEmpty);
  });

  test('tenggatLokal mempertahankan jam dinding', () {
    final t = tugas('a', DateTime(2026, 9, 29, 23, 59));
    expect(t.tenggatLokal, DateTime(2026, 9, 29, 23, 59));
    expect(t.tenggatLokal.isUtc, isFalse);
  });
}
