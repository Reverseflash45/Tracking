import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

enum CalendarEventType {
  jadwal('Jadwal', Icons.school_outlined, AppColors.academic),
  tugas('Tugas', Icons.alarm, AppColors.deadline),
  workout('Workout', Icons.fitness_center, AppColors.workout);

  const CalendarEventType(this.label, this.icon, this.color);

  final String label;
  final IconData icon;
  final Color color;
}

/// Satu baris di kalender. Menyatukan jadwal kuliah, deadline tugas, dan sesi
/// workout ke dalam satu bentuk supaya bisa ditampilkan dalam daftar yang sama.
class CalendarEvent {
  const CalendarEvent({
    required this.type,
    required this.title,
    required this.sortKey,
    this.subtitle,
    this.route,
  });

  final CalendarEventType type;
  final String title;

  /// Menit dari tengah malam, dipakai untuk mengurutkan isi satu hari.
  /// Sesi workout yang tidak punya jam diletakkan di akhir.
  final int sortKey;

  final String? subtitle;

  /// Rute tujuan saat item diketuk; null berarti tidak bisa dibuka.
  final String? route;
}
