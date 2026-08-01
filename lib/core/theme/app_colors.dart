import 'package:flutter/material.dart';

/// Warna per kategori konten, dipakai konsisten di seluruh app: hero header,
/// section header, ikon list, dan indikator tab bawah.
class AppColors {
  AppColors._();

  static const Color dashboard = Color(0xFF3B6FE5);
  static const Color academic = Color(0xFF4F46E5);
  static const Color deadline = Color(0xFFF4511E);
  static const Color workout = Color(0xFF00897B);
  static const Color profile = Color(0xFF8E24AA);

  /// Hijau tua untuk keuangan. Sengaja lebih gelap dari [priorityLow] dan
  /// [statusDone] yang sama-sama hijau, supaya tidak tertukar dengan penanda
  /// status di daftar tugas.
  static const Color finance = Color(0xFF2E7D32);

  static const Color priorityHigh = Color(0xFFE53935);
  static const Color priorityMedium = Color(0xFFFB8C00);
  static const Color priorityLow = Color(0xFF43A047);

  static const Color statusInProgress = Color(0xFF1E88E5);
  static const Color statusDone = Color(0xFF43A047);
}
