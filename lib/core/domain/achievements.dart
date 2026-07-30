import 'package:flutter/material.dart';

class Achievement {
  const Achievement({required this.label, required this.icon});

  final String label;
  final IconData icon;
}

/// Badge ringan dihitung langsung dari angka streak, tanpa disimpan di DB.
/// Cikal bakal gamification penuh (achievement custom, tersimpan) di fase berikutnya.
List<Achievement> computeAchievements({
  required int workoutStreak,
  required int deadlineStreak,
}) {
  final achievements = <Achievement>[];

  if (workoutStreak >= 100) {
    achievements.add(const Achievement(label: 'Gym Beast · 100 Hari', icon: Icons.emoji_events));
  } else if (workoutStreak >= 30) {
    achievements.add(const Achievement(label: 'Workout 30 Hari', icon: Icons.military_tech));
  } else if (workoutStreak >= 7) {
    achievements.add(const Achievement(label: 'Workout 7 Hari', icon: Icons.local_fire_department));
  }

  if (deadlineStreak >= 10) {
    achievements.add(const Achievement(label: 'Deadline Master', icon: Icons.workspace_premium));
  } else if (deadlineStreak >= 5) {
    achievements.add(const Achievement(label: 'Never Late', icon: Icons.verified));
  }

  return achievements;
}
