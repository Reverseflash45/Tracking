import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/hero_header.dart';
import '../data/models/task.dart';
import 'academic_providers.dart';
import 'task_tile.dart';

/// Daftar tugas pribadi — halaman tersendiri, bukan saringan di daftar tugas
/// kuliah.
///
/// Dua daftar ini dibuka pada saat yang berbeda. Yang kuliah dilihat saat
/// memikirkan kuliah, dan "servis motor" yang menyelip di antara laporan
/// praktikum tidak membantu keduanya. Dipisah, masing-masing bisa dibaca
/// sampai habis tanpa menyaring apa pun dengan mata.
///
/// Warnanya tetap warna Tugas. Di app ini warna menandakan bagian, bukan
/// halaman: Nilai, Kalender, dan Absensi pun memakai warna Jadwal.
class PersonalTasksPage extends ConsumerStatefulWidget {
  const PersonalTasksPage({super.key});

  @override
  ConsumerState<PersonalTasksPage> createState() => _PersonalTasksPageState();
}

enum _SaringPribadi {
  semua('Semua'),
  belum('Belum'),
  proses('Proses'),
  selesai('Selesai');

  const _SaringPribadi(this.label);
  final String label;

  bool cocok(AcademicTask task) => switch (this) {
        _SaringPribadi.semua => true,
        _SaringPribadi.belum => task.status == TaskStatus.todo,
        _SaringPribadi.proses => task.status == TaskStatus.inProgress,
        _SaringPribadi.selesai => task.status == TaskStatus.done,
      };
}

class _PersonalTasksPageState extends ConsumerState<PersonalTasksPage> {
  _SaringPribadi _saring = _SaringPribadi.semua;

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(tasksTampilProvider);
    final pribadi = (tasksAsync.value ?? const <AcademicTask>[])
        .where((t) => t.kind == TaskKind.pribadi)
        .toList();

    final belum = pribadi.where((t) => !t.isDone).length;
    final terlambat =
        pribadi.where((t) => !t.isDone && t.deadline.isBefore(DateTime.now())).length;
    final selesai = pribadi.where((t) => t.isDone).length;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/academic/tasks/new?kind=pribadi');
          ref.invalidate(tasksProvider);
        },
        backgroundColor: AppColors.deadline,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Tugas'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(tasksProvider),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            HeroHeader.sub(
              title: 'Tugas Pribadi',
              subtitle: 'Urusan di luar kuliah',
              color: AppColors.deadline,
              leading: HeroIconButton(
                icon: Icons.arrow_back,
                tooltip: 'Kembali',
                onPressed: () => context.pop(),
              ),
              stats: [
                HeroStatData(
                  icon: Icons.pending_actions,
                  value: '$belum',
                  label: 'Belum Selesai',
                ),
                HeroStatData(
                  icon: Icons.warning_amber_rounded,
                  value: '$terlambat',
                  label: 'Terlambat',
                ),
                HeroStatData(icon: Icons.task_alt, value: '$selesai', label: 'Selesai'),
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
                    for (final saring in _SaringPribadi.values) ...[
                      if (saring != _SaringPribadi.values.first)
                        const SizedBox(width: AppSpacing.sm),
                      FilterChip(
                        label: Text(saring.label),
                        selected: _saring == saring,
                        onSelected: (_) => setState(() => _saring = saring),
                        selectedColor: AppColors.deadline.withValues(alpha: 0.18),
                        checkmarkColor: AppColors.deadline,
                        labelStyle: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: _saring == saring
                              ? AppColors.deadline
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, 96),
              child: tasksAsync.when(
                data: (_) {
                  final tampil = pribadi.where(_saring.cocok).toList();
                  if (tampil.isEmpty) {
                    return EmptyState(
                      icon: Icons.person_outline,
                      title: _saring == _SaringPribadi.semua
                          ? 'Belum ada tugas pribadi'
                          : 'Tidak ada tugas ${_saring.label.toLowerCase()}',
                      subtitle: _saring == _SaringPribadi.semua
                          ? 'Servis motor, perpanjang STNK, bayar kos — '
                              'apa pun yang bukan urusan kuliah'
                          : 'Coba ganti filter di atas',
                      color: AppColors.deadline,
                    );
                  }
                  return Column(
                    children: [
                      for (final task in tampil)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          // Mata kuliah tidak ditampilkan: tugas pribadi memang
                          // tidak punya, dan menuliskan "Umum" di tiap baris
                          // cuma menambah tinggi tanpa menambah arti.
                          child: TaskTile(task: task, tampilkanMatkul: false),
                        ),
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
