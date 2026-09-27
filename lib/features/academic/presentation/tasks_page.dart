import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/warna_matkul.dart';
import '../../../core/widgets/daftar_bergaris.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/hero_header.dart';
import '../data/models/task.dart';
import 'academic_providers.dart';
import 'task_tile.dart';

enum _TaskFilter {
  all('Semua'),
  todo('Belum'),
  inProgress('Proses'),
  done('Selesai');

  const _TaskFilter(this.label);
  final String label;

  bool matches(AcademicTask task) {
    switch (this) {
      case _TaskFilter.all:
        return true;
      case _TaskFilter.todo:
        return task.status == TaskStatus.todo;
      case _TaskFilter.inProgress:
        return task.status == TaskStatus.inProgress;
      case _TaskFilter.done:
        return task.status == TaskStatus.done;
    }
  }
}

class TasksPage extends ConsumerStatefulWidget {
  const TasksPage({super.key});

  @override
  ConsumerState<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends ConsumerState<TasksPage> {
  _TaskFilter _filter = _TaskFilter.all;

  /// Saring per mata kuliah; null = semua.
  String? _matkul;

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(tasksTampilProvider);

    // Halaman ini khusus tugas kuliah; urusan pribadi punya halamannya sendiri.
    // Keduanya dipisah karena dilihat pada waktu yang berbeda: daftar kuliah
    // dibuka saat memikirkan kuliah, dan mencampurnya dengan "servis motor"
    // membuat keduanya sama-sama sulit dibaca.
    final kuliah = (tasksAsync.value ?? const <AcademicTask>[])
        .where((t) => t.kind == TaskKind.kuliah)
        .toList();

    final unfinished = kuliah.where((t) => !t.isDone).length;
    final overdue =
        kuliah.where((t) => !t.isDone && t.tenggatLokal.isBefore(DateTime.now())).length;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/academic/tasks/new');
          ref.invalidate(tasksProvider);
        },
        icon: const Icon(Icons.add),
        label: const Text('Tugas'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(tasksProvider),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            HeroHeader(
              title: 'Tugas',
              subtitle: overdue > 0
                  ? '$unfinished belum selesai · $overdue terlambat'
                  : '$unfinished belum selesai',
              color: AppColors.deadline,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  HeroIconButton(
                    icon: Icons.person_outline,
                    tooltip: 'Tugas pribadi',
                    onPressed: () async {
                      await context.push('/academic/tasks/pribadi');
                      ref.invalidate(tasksProvider);
                    },
                  ),
                  HeroIconButton(
                    icon: Icons.inventory_2_outlined,
                    tooltip: 'Arsip per mata kuliah',
                    onPressed: () => context.push('/academic/tasks/arsip'),
                  ),
                  HeroIconButton(
                    icon: Icons.event_repeat,
                    tooltip: 'Tugas berulang',
                    onPressed: () async {
                      await context.push('/academic/tasks/recurring');
                      ref.invalidate(tasksProvider);
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: _KartuProgresMinggu(tugas: kuliah),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.xs,
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final filter in _TaskFilter.values) ...[
                      if (filter != _TaskFilter.values.first) const SizedBox(width: AppSpacing.sm),
                      FilterChip(
                        label: Text('${filter.label}  ${kuliah.where(filter.matches).length}'),
                        selected: _filter == filter,
                        onSelected: (_) => setState(() => _filter = filter),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (_daftarMatkul(kuliah) case final matkul when matkul.length > 1)
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
                  children: [
                    for (final (id, nama) in matkul) ...[
                      ActionChip(
                        avatar: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: warnaMatkul(id),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        label: Text(nama),
                        backgroundColor: _matkul == id
                            ? warnaMatkul(id).withValues(alpha: 0.16)
                            : null,
                        side: BorderSide(
                          color: _matkul == id
                              ? warnaMatkul(id)
                              : Theme.of(context).colorScheme.outlineVariant,
                        ),
                        onPressed: () => setState(() => _matkul = _matkul == id ? null : id),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, 96),
              child: tasksAsync.when(
                data: (_) {
                  final filtered = kuliah
                      .where(_filter.matches)
                      .where((t) => _matkul == null || t.courseId == _matkul)
                      .toList();
                  if (filtered.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.md),
                      child: EmptyState(
                        icon: Icons.checklist_outlined,
                        title: _filter == _TaskFilter.all
                            ? 'Belum ada tugas kuliah'
                            : 'Tidak ada tugas ${_filter.label.toLowerCase()}',
                        subtitle: _filter == _TaskFilter.all
                            ? 'Tekan tombol + untuk menambahkan'
                            : 'Coba ganti filter di atas',
                        color: AppColors.deadline,
                      ),
                    );
                  }
                  final kelompok = kelompokkanTugas(filtered);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final (judul, isi, warna) in kelompok) ...[
                        JudulKelompokTugas(judul: judul, jumlah: isi.length, warna: warna),
                        DaftarBergaris(
                          indentGaris: 52,
                          children: [for (final task in isi) TaskTile(task: task)],
                        ),
                      ],
                    ],
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, stackTrace) => EmptyState(
                  icon: Icons.error_outline,
                  title: 'Gagal memuat tugas',
                  subtitle: '$error',
                  color: AppColors.deadline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Membagi tugas ke kelompok waktu: Terlambat, Hari ini, Besok, Minggu ini,
/// Nanti, lalu Selesai. Urutan di dalam kelompok mengikuti tenggat; yang
/// selesai diurutkan dari yang paling baru.
///
/// Publik supaya bisa diuji tanpa menggambar halaman.
List<(String, List<AcademicTask>, Color?)> kelompokkanTugas(
  List<AcademicTask> tugas, {
  DateTime? sekarang,
}) {
  final n = sekarang ?? DateTime.now();
  final hariIni = DateTime(n.year, n.month, n.day);
  final besok = hariIni.add(const Duration(days: 1));
  final lusa = hariIni.add(const Duration(days: 2));
  final akhirMinggu = hariIni.add(Duration(days: 8 - hariIni.weekday));

  final terlambat = <AcademicTask>[];
  final hari = <AcademicTask>[];
  final esok = <AcademicTask>[];
  final minggu = <AcademicTask>[];
  final nanti = <AcademicTask>[];
  final selesai = <AcademicTask>[];

  for (final t in tugas) {
    if (t.isDone) {
      selesai.add(t);
    } else if (t.tenggatLokal.isBefore(n)) {
      terlambat.add(t);
    } else if (t.tenggatLokal.isBefore(besok)) {
      hari.add(t);
    } else if (t.tenggatLokal.isBefore(lusa)) {
      esok.add(t);
    } else if (t.tenggatLokal.isBefore(akhirMinggu)) {
      minggu.add(t);
    } else {
      nanti.add(t);
    }
  }
  int naik(AcademicTask a, AcademicTask b) => a.deadline.compareTo(b.deadline);
  for (final l in [terlambat, hari, esok, minggu, nanti]) {
    l.sort(naik);
  }
  selesai.sort((a, b) => b.deadline.compareTo(a.deadline));

  return [
    if (terlambat.isNotEmpty) ('Terlambat', terlambat, AppColors.deadline),
    if (hari.isNotEmpty) ('Hari ini', hari, AppColors.deadline),
    if (esok.isNotEmpty) ('Besok', esok, AppColors.priorityMedium),
    if (minggu.isNotEmpty) ('Minggu ini', minggu, null),
    if (nanti.isNotEmpty) ('Nanti', nanti, null),
    if (selesai.isNotEmpty) ('Selesai', selesai, AppColors.statusDone),
  ];
}

class JudulKelompokTugas extends StatelessWidget {
  const JudulKelompokTugas({super.key, required this.judul, required this.jumlah, this.warna});

  final String judul;
  final int jumlah;
  final Color? warna;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
      child: Row(
        children: [
          if (warna != null) ...[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: warna, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
          ],
          Text(
            judul,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: warna == AppColors.deadline ? AppColors.deadline : colorScheme.onSurface,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$jumlah',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Seberapa jauh tugas pekan ini sudah beres, plus hitungan yang mendesak.
class _KartuProgresMinggu extends StatelessWidget {
  const _KartuProgresMinggu({required this.tugas});

  final List<AcademicTask> tugas;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final n = DateTime.now();
    final senin = DateTime(n.year, n.month, n.day).subtract(Duration(days: n.weekday - 1));
    final minggu = senin.add(const Duration(days: 7));
    final pekanIni = tugas
        .where((t) => !t.tenggatLokal.isBefore(senin) && t.tenggatLokal.isBefore(minggu))
        .toList();
    final beres = pekanIni.where((t) => t.isDone).length;
    final total = pekanIni.length;
    final rasio = total == 0 ? 0.0 : beres / total;
    final dalam48Jam = tugas
        .where(
          (t) =>
              !t.isDone &&
              !t.tenggatLokal.isBefore(n) &&
              t.tenggatLokal.difference(n) < const Duration(hours: 48),
        )
        .length;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox.square(
              dimension: 58,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: rasio),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOutCubic,
                    builder: (context, v, _) => CircularProgressIndicator(
                      value: v,
                      strokeWidth: 7,
                      strokeCap: StrokeCap.round,
                      color: AppColors.deadline,
                      backgroundColor: AppColors.deadline.withValues(alpha: 0.14),
                    ),
                  ),
                  Center(
                    child: Text(
                      '${(rasio * 100).round()}%',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pekan ini',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    total == 0
                        ? 'Tidak ada tenggat pekan ini'
                        : '$beres dari $total tugas selesai',
                    style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
                  ),
                  if (dalam48Jam > 0) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.deadline.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        '$dalam48Jam jatuh tempo dalam 48 jam',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.deadline,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mata kuliah yang punya tugas, sebagai (id, nama), urut abjad.
List<(String, String)> _daftarMatkul(List<AcademicTask> tugas) {
  final peta = <String, String>{};
  for (final t in tugas) {
    if (t.courseId case final id?) peta[id] = t.courseName ?? 'Tanpa nama';
  }
  final isi = [for (final e in peta.entries) (e.key, e.value)];
  isi.sort((a, b) => a.$2.compareTo(b.$2));
  return isi;
}
