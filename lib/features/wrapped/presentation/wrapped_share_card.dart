import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/hero_header.dart';
import '../domain/wrapped_stats.dart';

final _rangeFormat = DateFormat('d MMM', 'id_ID');
final _numberFormat = NumberFormat.decimalPattern('id_ID');

/// Kartu rekap untuk dibagikan.
///
/// Isinya angka yang sudah dihitung, bukan pilihan halaman story yang sedang
/// terbuka — supaya satu gambar menceritakan seluruh periodenya, bukan satu
/// potongan yang kebetulan sedang tampil.
class WrappedShareCard extends StatelessWidget {
  const WrappedShareCard({super.key, required this.stats});

  final WrappedStats stats;

  @override
  Widget build(BuildContext context) {
    final baris = <({IconData icon, String label, String value})>[
      (
        icon: Icons.task_alt,
        label: 'Tugas selesai',
        value: '${stats.tugasSelesai}',
      ),
      if (stats.sesiWorkout > 0)
        (
          icon: Icons.fitness_center,
          label: 'Sesi latihan',
          value: '${stats.sesiWorkout}',
        ),
      if (stats.sesiLari > 0)
        (
          icon: Icons.directions_run,
          label: 'Jarak lari',
          value: '${(stats.jarakLariMeter / 1000).toStringAsFixed(1)} km',
        ),
      (
        icon: Icons.local_fire_department,
        label: 'Hari aktif',
        value: '${stats.hariAktif}',
      ),
      if (stats.totalVolume > 0)
        (
          icon: Icons.scale_outlined,
          label: 'Total angkatan',
          value: '${_numberFormat.format(stats.totalVolume.round())} kg',
        ),
    ];

    return Container(
      width: 320,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: HeroHeader.gradientFor(AppColors.profile),
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'REKAP ${stats.period.label.toUpperCase()}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${_rangeFormat.format(stats.range.start)} - '
            '${_rangeFormat.format(stats.range.end)}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            stats.persona,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w900,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 20),
          for (final item in baris)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Icon(item.icon, color: Colors.white.withValues(alpha: 0.85), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.label,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Text(
                    item.value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          if (stats.tugasSelesai > 0) ...[
            const SizedBox(height: 4),
            Text(
              '${stats.persenTepatWaktu}% tugas selesai tepat waktu',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 14,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
