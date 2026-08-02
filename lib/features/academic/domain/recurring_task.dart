/// Tugas yang datang tiap minggu, dan aturan pembuatan otomatisnya.
library;

import '../data/models/task.dart';

/// Seberapa jauh ke depan tugas dibuat otomatis.
///
/// Tiga minggu: cukup panjang supaya kamu tetap melihat tugas yang akan datang
/// meski app tidak dibuka seminggu, cukup pendek supaya daftar tugas tidak
/// dipenuhi kejadian yang masih dua bulan lagi dan belum tentu relevan.
const int kHorizonTugasBerulangHari = 21;

class RecurringTask {
  const RecurringTask({
    required this.id,
    required this.userId,
    this.courseId,
    this.courseName,
    required this.title,
    this.description,
    required this.priority,
    required this.weekday,
    required this.deadlineMinute,
    this.active = true,
  });

  final String id;
  final String userId;
  final String? courseId;
  final String? courseName;
  final String title;
  final String? description;
  final TaskPriority priority;

  /// 1 = Senin ... 7 = Minggu.
  final int weekday;

  /// Jam deadline dalam menit dari tengah malam.
  final int deadlineMinute;

  final bool active;

  String get jamLabel {
    final jam = (deadlineMinute ~/ 60).toString().padLeft(2, '0');
    final menit = (deadlineMinute % 60).toString().padLeft(2, '0');
    return '$jam:$menit';
  }

  factory RecurringTask.fromMap(Map<String, dynamic> map) => RecurringTask(
        id: map['id'] as String,
        userId: map['user_id'] as String,
        courseId: map['course_id'] as String?,
        courseName: (map['courses'] as Map<String, dynamic>?)?['name'] as String?,
        title: map['title'] as String,
        description: map['description'] as String?,
        priority: TaskPriority.fromDb(map['priority'] as String),
        weekday: map['weekday'] as int,
        deadlineMinute: map['deadline_minute'] as int,
        active: map['active'] as bool? ?? true,
      );
}

/// Satu kejadian yang perlu dibuat jadi tugas nyata.
class TugasTerjadwal {
  const TugasTerjadwal({required this.sumber, required this.tanggal, required this.deadline});

  final RecurringTask sumber;

  /// Tanggal kejadiannya (tanpa jam) — inilah yang disimpan ke `recurring_on`
  /// dan yang membuat pembuatan ulang tidak menghasilkan tugas kembar.
  final DateTime tanggal;

  /// Deadline lengkap dengan jamnya.
  final DateTime deadline;
}

String _dateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

/// Kunci satu kejadian, dipakai untuk mencocokkan dengan tugas yang sudah ada.
String occurrenceKey(String recurringId, DateTime tanggal) =>
    '$recurringId|${_dateKey(tanggal)}';

/// Kejadian dalam horizon yang belum punya tugas.
///
/// [sudahAda] berisi hasil [occurrenceKey] dari tugas yang sudah tercatat —
/// termasuk yang sudah kamu hapus? Tidak: tugas yang dihapus memang akan dibuat
/// ulang. Itu disengaja. Yang tidak mau kamu kerjakan minggu ini sebaiknya
/// ditandai selesai atau template-nya dimatikan; menghapus satu kejadian tidak
/// bisa dibedakan dari belum pernah dibuat tanpa menyimpan nisan di database.
List<TugasTerjadwal> occurrencesToCreate({
  required List<RecurringTask> templates,
  required Set<String> sudahAda,
  required DateTime now,
  int horizonHari = kHorizonTugasBerulangHari,
}) {
  final hariIni = DateTime(now.year, now.month, now.day);
  final hasil = <TugasTerjadwal>[];

  for (final template in templates) {
    if (!template.active) continue;

    for (var offset = 0; offset <= horizonHari; offset++) {
      final tanggal = hariIni.add(Duration(days: offset));
      if (tanggal.weekday != template.weekday) continue;

      final deadline = DateTime(
        tanggal.year,
        tanggal.month,
        tanggal.day,
        template.deadlineMinute ~/ 60,
        template.deadlineMinute % 60,
      );

      // Kejadian hari ini yang jamnya sudah lewat tidak dibuat: tugas yang
      // lahir sudah terlambat cuma jadi angka merah palsu di riwayatmu.
      if (!deadline.isAfter(now)) continue;
      if (sudahAda.contains(occurrenceKey(template.id, tanggal))) continue;

      hasil.add(TugasTerjadwal(sumber: template, tanggal: tanggal, deadline: deadline));
    }
  }

  hasil.sort((a, b) => a.deadline.compareTo(b.deadline));
  return hasil;
}

/// Kunci kejadian dari tugas yang sudah tercatat.
Set<String> existingOccurrenceKeys(Iterable<AcademicTask> tasks) => {
      for (final task in tasks)
        if (task.recurringId != null && task.recurringOn != null)
          occurrenceKey(task.recurringId!, task.recurringOn!),
    };
