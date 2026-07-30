import '../data/models/workout_session.dart';

class WorkoutStreak {
  const WorkoutStreak({required this.current, required this.best});

  final int current;
  final int best;
}

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

/// Streak workout dihitung dari tanggal sesi unik. Streak "aktif" boleh punya
/// grace 1 hari (kalau belum sempat workout hari ini tapi kemarin masih jalan).
WorkoutStreak calculateWorkoutStreak(List<WorkoutSession> sessions) {
  if (sessions.isEmpty) return const WorkoutStreak(current: 0, best: 0);

  final uniqueDates = sessions.map((s) => _dateOnly(s.sessionDate)).toSet().toList()
    ..sort((a, b) => b.compareTo(a));

  final today = _dateOnly(DateTime.now());
  final yesterday = today.subtract(const Duration(days: 1));

  var current = 0;
  if (uniqueDates.first == today || uniqueDates.first == yesterday) {
    current = 1;
    for (var i = 0; i < uniqueDates.length - 1; i++) {
      final diff = uniqueDates[i].difference(uniqueDates[i + 1]).inDays;
      if (diff == 1) {
        current++;
      } else {
        break;
      }
    }
  }

  var best = 1;
  var running = 1;
  for (var i = 0; i < uniqueDates.length - 1; i++) {
    final diff = uniqueDates[i].difference(uniqueDates[i + 1]).inDays;
    if (diff == 1) {
      running++;
    } else {
      running = 1;
    }
    if (running > best) best = running;
  }

  return WorkoutStreak(current: current, best: best);
}
