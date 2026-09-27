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

    return Dismissible(
      key: ValueKey(task.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: colorScheme.errorContainer,
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
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Hapus'),
            ),
          ],
        ),
      ),
      onDismissed: (_) async {
        final messenger = ScaffoldMessenger.of(context);
        try {
          await ref.read(academicRepositoryProvider).deleteTask(task.id);
        } catch (error) {
          messenger.showSnackBar(
            SnackBar(content: Text('Gagal menghapus: $error')),
          );
        }
        ref.invalidate(tasksProvider);
      },
      // Satu baris datar di dalam DaftarBergaris — bukan kartu berbingkai
      // dengan garis warna prioritas di kiri. Prioritas tinggi cukup satu
      // titik merah di depan judul; status "Belum" tidak perlu lencana karena
      // memang keadaan bawaan.
      child: InkWell(
        onTap: () => context.push('/academic/tasks/${task.id}'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, AppSpacing.md, 6),
          child: Row(
            children: [
              IconButton(
                tooltip: task.isDone
                    ? 'Tandai belum selesai'
                    : 'Tandai selesai',
                onPressed: () => ubahStatusTugas(
                  context,
                  ref,
                  task.id,
                  task.isDone ? TaskStatus.todo : TaskStatus.done,
                ),
                icon: Icon(
                  task.isDone
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  size: 22,
                  color: task.isDone
                      ? AppColors.statusDone
                      : colorScheme.outline,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        if (task.priority == TaskPriority.high &&
                            !task.isDone) ...[
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 7),
                        ],
                        Flexible(
                          child: Text(
                            task.title,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14.5,
                              height: 1.3,
                              decoration: task.isDone
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: task.isDone
                                  ? colorScheme.onSurfaceVariant
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        if (tampilkanMatkul) task.courseName ?? 'Umum',
                        task.isDone
                            ? _dateFormat.format(task.deadline)
                            : countdownLabel(task.deadline),
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: overdue
                            ? AppColors.priorityHigh
                            : colorScheme.onSurfaceVariant,
                        fontWeight: overdue ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              PopupMenuButton<TaskStatus>(
                initialValue: task.status,
                tooltip: 'Ubah status',
                onSelected: (status) =>
                    ubahStatusTugas(context, ref, task.id, status),
                itemBuilder: (context) => TaskStatus.values
                    .map(
                      (status) => PopupMenuItem(
                        value: status,
                        child: Text(status.label),
                      ),
                    )
                    .toList(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        task.status.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: task.status == TaskStatus.inProgress
                              ? colorScheme.primary
                              : colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Icon(
                        Icons.expand_more,
                        size: 16,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
