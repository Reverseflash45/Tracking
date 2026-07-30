import '../data/models/task.dart';

class DeadlineStreak {
  const DeadlineStreak({
    required this.current,
    required this.best,
    required this.onTimePercentage,
  });

  final int current;
  final int best;

  /// 0-100, dari seluruh tugas yang sudah selesai.
  final double onTimePercentage;
}

/// Dihitung dari tugas yang sudah "done", diurutkan dari yang paling baru
/// diselesaikan. Streak berjalan selama tugas diselesaikan tepat waktu
/// (completedAt <= deadline) berturut-turut, berhenti begitu ketemu yang telat.
DeadlineStreak calculateDeadlineStreak(List<AcademicTask> tasks) {
  final completed = tasks.where((t) => t.isDone && t.completedAt != null).toList()
    ..sort((a, b) => b.completedAt!.compareTo(a.completedAt!));

  if (completed.isEmpty) {
    return const DeadlineStreak(current: 0, best: 0, onTimePercentage: 0);
  }

  var current = 0;
  for (final task in completed) {
    if (task.isOnTime) {
      current++;
    } else {
      break;
    }
  }

  var best = 0;
  var running = 0;
  var onTimeCount = 0;
  for (final task in completed) {
    if (task.isOnTime) {
      running++;
      onTimeCount++;
      if (running > best) best = running;
    } else {
      running = 0;
    }
  }

  final onTimePercentage = completed.isEmpty ? 0.0 : onTimeCount / completed.length * 100;

  return DeadlineStreak(current: current, best: best, onTimePercentage: onTimePercentage);
}
