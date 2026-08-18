import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/hero_header.dart';
import '../data/models/course.dart';
import '../data/models/task.dart';
import '../domain/arsip_tugas.dart';
import '../domain/matkul_aktif.dart';
import 'academic_providers.dart';
import 'task_tile.dart' show countdownLabel, statusColor;

const _color = AppColors.deadline;
final _tanggal = DateFormat('d MMM y', 'id_ID');

enum _Saring {
  semua('Semua'),
  belum('Belum'),
  proses('Proses'),
  selesai('Selesai');

  const _Saring(this.label);
  final String label;

  bool cocok(AcademicTask task) => switch (this) {
        _Saring.semua => true,
        _Saring.belum => task.status == TaskStatus.todo,
        _Saring.proses => task.status == TaskStatus.inProgress,
        _Saring.selesai => task.status == TaskStatus.done,
      };
}

/// Arsip tugas kuliah, dikelompokkan per mata kuliah.
///
/// Daftar Tugas menjawab "apa yang harus dikerjakan berikutnya" — semuanya
/// dicampur, diurut deadline. Halaman ini menjawab pertanyaan yang lain: "mata
/// kuliah ini tugasnya sudah apa saja". Dua pertanyaan itu butuh dua susunan
/// yang berbeda, dan satu daftar tidak bisa melayani keduanya.
class TaskArchivePage extends ConsumerStatefulWidget {
  const TaskArchivePage({super.key});

  @override
  ConsumerState<TaskArchivePage> createState() => _TaskArchivePageState();
}

class _TaskArchivePageState extends ConsumerState<TaskArchivePage> {
  _Saring _saring = _Saring.semua;

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(tasksTampilProvider);
    final semuaCourses = ref.watch(coursesProvider).value ?? const <Course>[];
    final jadwal = ref.watch(classSchedulesProvider).value ?? const [];

    // Mata kuliah semester ini tetap muncul walau belum punya satu tugas pun —
    // "belum pernah kamu tulis" adalah jawaban yang berbeda dari "tidak ada".
    // Mata kuliah semester lalu ikut lewat tugasnya sendiri: arsip memang untuk
    // melihat ke belakang, jadi yang punya tugas tidak pernah disembunyikan.
    final aktif = {
      for (final c in matkulAktif(semuaCourses, jadwal)) c.id: c.name,
    };

    final arsip = arsipTugas(tasksAsync.value ?? const [], matkulAktif: aktif);
    final totalTugas = arsip.fold(0, (jumlah, m) => jumlah + m.total);
    final totalSelesai = arsip.fold(0, (jumlah, m) => jumlah + m.selesai);
    final adaPekerjaan = arsip.where((m) => m.belumSelesai > 0).length;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(tasksProvider);
          ref.invalidate(coursesProvider);
          ref.invalidate(classSchedulesProvider);
        },
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            HeroHeader.sub(
              title: 'Arsip Tugas',
              subtitle: 'Tugas kuliah per mata kuliah',
              color: _color,
              leading: HeroIconButton(
                icon: Icons.arrow_back,
                tooltip: 'Kembali',
                onPressed: () => context.pop(),
              ),
              stats: [
                HeroStatData(
                  icon: Icons.menu_book_outlined,
                  value: '$adaPekerjaan',
                  label: 'Masih Ada Tugas',
                ),
                HeroStatData(icon: Icons.task_alt, value: '$totalSelesai', label: 'Selesai'),
                HeroStatData(
                  icon: Icons.checklist_outlined,
                  value: '$totalTugas',
                  label: 'Total Tugas',
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final saring in _Saring.values) ...[
                      if (saring != _Saring.values.first) const SizedBox(width: AppSpacing.sm),
                      FilterChip(
                        label: Text(saring.label),
                        selected: _saring == saring,
                        onSelected: (_) => setState(() => _saring = saring),
                        selectedColor: _color.withValues(alpha: 0.18),
                        checkmarkColor: _color,
                        labelStyle: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: _saring == saring
                              ? _color
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.xl),
              child: tasksAsync.when(
                data: (_) => arsip.isEmpty
                    ? const EmptyState(
                        icon: Icons.inventory_2_outlined,
                        title: 'Belum ada yang diarsipkan',
                        subtitle: 'Tambahkan jadwal kuliah atau tugas dulu',
                        color: _color,
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final matkul in arsip)
                            Padding(
                              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                              child: KartuArsipMatkul(
                                matkul: matkul,
                                tampil: [
                                  for (final task in matkul.tugas)
                                    if (_saring.cocok(task)) task,
                                ],
                                labelSaring:
                                    _saring == _Saring.semua ? null : _saring.label,
                              ),
                            ),
                        ],
                      ),
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, stackTrace) => EmptyState(
                  icon: Icons.error_outline,
                  title: 'Gagal memuat tugas',
                  subtitle: '$error',
                  color: _color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Satu mata kuliah beserta tugasnya. Publik supaya tata letaknya bisa
/// digambar langsung di test tampilan tanpa menghidupkan seluruh halaman.
class KartuArsipMatkul extends StatelessWidget {
  const KartuArsipMatkul({
    super.key,
    required this.matkul,
    required this.tampil,
    this.labelSaring,
  });

  final ArsipMatkul matkul;

  /// Tugas yang lolos saringan. Kartunya sengaja tidak menyaring sendiri: yang
  /// menentukan saringan adalah halaman, dan kartu yang ikut tahu soal itu jadi
  /// tidak bisa dipakai di tempat lain.
  final List<AcademicTask> tampil;

  /// Nama saringan yang sedang aktif, untuk kalimat saat hasilnya kosong. Null
  /// berarti tidak sedang menyaring.
  final String? labelSaring;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Theme(
        // ExpansionTile menggambar garisnya sendiri di atas dan di bawah, dan
        // di dalam kartu yang sudah punya garis tepi itu jadi dua garis kembar.
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          // Kuncinya ikut berubah bersama saringan supaya kartunya membuka
          // sendiri saat kamu menyaring — di situ isinya sedikit dan memang
          // itu yang sedang dicari.
          key: PageStorageKey('${labelSaring ?? ''}-${matkul.courseId}'),
          initiallyExpanded: labelSaring != null && tampil.isNotEmpty,
          tilePadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          childrenPadding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          title: Text(
            matkul.nama,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: _Ringkasan(matkul: matkul),
          ),
          children: [
            if (tampil.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Text(
                  matkul.total == 0
                      ? 'Belum ada tugas yang dicatat untuk mata kuliah ini.'
                      : 'Tidak ada tugas ${labelSaring?.toLowerCase()} di mata kuliah ini.',
                  style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                ),
              )
            else
              for (final task in tampil) _BarisTugas(task: task),
          ],
        ),
      ),
    );
  }
}

/// Hitungan per status plus batang progres.
class _Ringkasan extends StatelessWidget {
  const _Ringkasan({required this.matkul});

  final ArsipMatkul matkul;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (matkul.progres case final progres?) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 2,
            children: [
              _Hitungan(label: 'Belum', nilai: matkul.belum, warna: colorScheme.onSurfaceVariant),
              _Hitungan(label: 'Proses', nilai: matkul.proses, warna: AppColors.statusInProgress),
              _Hitungan(label: 'Selesai', nilai: matkul.selesai, warna: AppColors.statusDone),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progres,
              minHeight: 4,
              backgroundColor: colorScheme.surfaceContainerHighest,
              valueColor: const AlwaysStoppedAnimation(AppColors.statusDone),
            ),
          ),
        ],
      );
    }

    return Text(
      'Belum ada tugas',
      style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
    );
  }
}

class _Hitungan extends StatelessWidget {
  const _Hitungan({required this.label, required this.nilai, required this.warna});

  final String label;
  final int nilai;
  final Color warna;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$nilai ',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: warna),
          ),
          TextSpan(
            text: label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _BarisTugas extends StatelessWidget {
  const _BarisTugas({required this.task});

  final AcademicTask task;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final warna = statusColor(task.status, colorScheme);
    final terlambat = !task.isDone && task.deadline.isBefore(DateTime.now());

    return InkWell(
      onTap: () => context.push('/academic/tasks/${task.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(color: warna, shape: BoxShape.circle),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    task.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      decoration: task.isDone ? TextDecoration.lineThrough : null,
                      color: task.isDone ? colorScheme.onSurfaceVariant : null,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    task.isDone
                        ? _tanggal.format(task.deadline)
                        : '${_tanggal.format(task.deadline)} · ${countdownLabel(task.deadline)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: terlambat ? AppColors.priorityHigh : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              task.status.label,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: warna),
            ),
          ],
        ),
      ),
    );
  }
}
