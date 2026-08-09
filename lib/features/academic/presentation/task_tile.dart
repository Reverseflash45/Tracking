import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../data/academic_repository.dart';
import '../data/models/task.dart';
import 'academic_providers.dart';

final _dateFormat = DateFormat('d MMM y, HH:mm', 'id_ID');

Color priorityColor(TaskPriority priority) {
  switch (priority) {
    case TaskPriority.high:
      return AppColors.priorityHigh;
    case TaskPriority.medium:
      return AppColors.priorityMedium;
    case TaskPriority.low:
      return AppColors.priorityLow;
  }
}

Color statusColor(TaskStatus status, ColorScheme colorScheme) {
  switch (status) {
    case TaskStatus.todo:
      return colorScheme.onSurfaceVariant;
    case TaskStatus.inProgress:
      return AppColors.statusInProgress;
    case TaskStatus.done:
      return AppColors.statusDone;
  }
}

/// Label relatif ke hari ini, biar urgensi kebaca sekilas tanpa hitung tanggal.
String countdownLabel(DateTime deadline) {
  final now = DateTime.now();
  final deadlineDay = DateTime(deadline.year, deadline.month, deadline.day);
  final todayDay = DateTime(now.year, now.month, now.day);
  final diff = deadlineDay.difference(todayDay).inDays;

  if (diff < 0) return 'Terlambat ${-diff} hari';
  if (diff == 0) return 'Hari ini';
  if (diff == 1) return 'Besok';
  return '$diff hari lagi';
}

/// Mengubah status satu tugas dan memastikan hasilnya terlihat.
///
/// Tiga hal yang sebelumnya tidak ada:
///
/// 1. Perubahannya langsung tampak, tidak menunggu seluruh daftar diambil ulang
///    dari server lebih dulu.
/// 2. Kegagalan dari server ditampilkan. Sebelumnya `await`-nya tidak dibungkus
///    apa pun, jadi penolakan berakhir sebagai error asinkron yang tidak pernah
///    sampai ke layar: tombol ditekan, tidak ada yang berubah, tidak ada yang
///    menjelaskan.
/// 3. Kalau gagal, tampilannya dikembalikan — bukan ditinggal menampilkan
///    keadaan yang tidak pernah tersimpan.
Future<void> ubahStatusTugas(
  BuildContext context,
  WidgetRef ref,
  String taskId,
  TaskStatus status,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final bayangan = ref.read(statusSementaraProvider.notifier);

  bayangan.tandai(taskId, status);
  try {
    await ref.read(academicRepositoryProvider).updateTaskStatus(taskId, status);
  } catch (error) {
    bayangan.lupakan(taskId);
    messenger.showSnackBar(
      SnackBar(content: Text('Gagal mengubah status: $error')),
    );
    return;
  }

  if (!context.mounted) return;
  ref.invalidate(tasksProvider);

  // Bayangannya dilepas begitu daftar dari server benar-benar memuat status
  // yang baru. Kalau pengambilan ulangnya gagal — misal sinyal hilang tepat
  // setelah tulisannya berhasil — bayangannya sengaja dibiarkan: server sudah
  // menyimpan status itu, jadi dialah yang benar, bukan cache lama.
  try {
    final segar = await ref.read(tasksProvider.future);
    if (segar.any((task) => task.id == taskId && task.status == status)) {
      bayangan.lupakan(taskId);
    }
  } catch (_) {
    // Sengaja didiamkan: daftarnya sendiri sudah menampilkan kegagalannya.
  }
}

/// Satu baris tugas, dipakai daftar tugas kuliah maupun pribadi.
class TaskTile extends ConsumerWidget {
  const TaskTile({super.key, required this.task, this.tampilkanMatkul = true});

  final AcademicTask task;

  /// Daftar tugas pribadi mematikan ini: di sana tidak ada mata kuliah, dan
  /// menuliskan "Umum" di tiap baris cuma menambah tinggi tanpa menambah arti.
  final bool tampilkanMatkul;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final accent = priorityColor(task.priority);
    final overdue = !task.isDone && task.deadline.isBefore(DateTime.now());
    final warnaStatus = statusColor(task.status, colorScheme);

    return Dismissible(
      key: ValueKey(task.id),
      direction: DismissDirection.endToStart,
      background: Container(
        decoration: BoxDecoration(
          color: colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(AppTheme.radius),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Icon(Icons.delete_outline, color: colorScheme.onErrorContainer),
      ),
      confirmDismiss: (_) => showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Hapus tugas?'),
          content: Text('Tugas "${task.title}" akan dihapus.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hapus')),
          ],
        ),
      ),
      onDismissed: (_) async {
        final messenger = ScaffoldMessenger.of(context);
        try {
          await ref.read(academicRepositoryProvider).deleteTask(task.id);
        } catch (error) {
          messenger.showSnackBar(SnackBar(content: Text('Gagal menghapus: $error')));
        }
        ref.invalidate(tasksProvider);
      },
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/academic/tasks/${task.id}'),
          child: Container(
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: accent, width: 4)),
            ),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.sm,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                IconButton(
                  tooltip: task.isDone ? 'Tandai belum selesai' : 'Tandai selesai',
                  onPressed: () => ubahStatusTugas(
                    context,
                    ref,
                    task.id,
                    task.isDone ? TaskStatus.todo : TaskStatus.done,
                  ),
                  icon: Icon(
                    task.isDone ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: task.isDone ? AppColors.statusDone : colorScheme.onSurfaceVariant,
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        task.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          decoration: task.isDone ? TextDecoration.lineThrough : null,
                          color: task.isDone ? colorScheme.onSurfaceVariant : null,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (tampilkanMatkul)
                            _MetaPill(
                              icon: Icons.menu_book_outlined,
                              label: task.courseName ?? 'Umum',
                              color: colorScheme.onSurfaceVariant,
                            ),
                          _MetaPill(
                            icon: overdue ? Icons.warning_amber_rounded : Icons.event_outlined,
                            label: task.isDone
                                ? _dateFormat.format(task.deadline)
                                : countdownLabel(task.deadline),
                            color: overdue ? AppColors.priorityHigh : colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                PopupMenuButton<TaskStatus>(
                  initialValue: task.status,
                  tooltip: 'Ubah status',
                  onSelected: (status) => ubahStatusTugas(context, ref, task.id, status),
                  itemBuilder: (context) => TaskStatus.values
                      .map((status) => PopupMenuItem(value: status, child: Text(status.label)))
                      .toList(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: warnaStatus.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      task.status.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: warnaStatus,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    // Teksnya dipotong dengan elipsis, bukan dibiarkan melebar. Nama mata
    // kuliah datang dari isian sendiri dan hasil impor KRS — panjangnya tidak
    // ada batas, dan di layar 320dp dengan huruf diperbesar, "Keamanan Cyber"
    // saja sudah meluber. Ketahuannya dari uji tampilan, bukan dari melihat.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}
