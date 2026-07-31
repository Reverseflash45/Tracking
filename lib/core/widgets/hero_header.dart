import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class HeroStatData {
  const HeroStatData({required this.icon, required this.value, required this.label});

  final IconData icon;
  final String value;
  final String label;
}

/// Header gradient dengan judul + baris statistik "glass", dipakai di semua
/// halaman utama supaya bahasa desainnya seragam dengan Dashboard.
class HeroHeader extends StatelessWidget {
  const HeroHeader({
    super.key,
    required this.title,
    required this.color,
    this.subtitle,
    this.trailing,
    this.leading,
    this.stats = const [],
  });

  final String title;
  final Color color;
  final String? subtitle;
  final Widget? trailing;
  final Widget? leading;
  final List<HeroStatData> stats;

  /// Gradient diturunkan dari satu warna aksen: sedikit lebih terang di kiri-atas
  /// dan digeser hue-nya di kanan-bawah, supaya tiap kategori punya nuansa sendiri.
  static List<Color> gradientFor(Color color) {
    final hsl = HSLColor.fromColor(color);
    return [
      hsl.withLightness((hsl.lightness + 0.06).clamp(0.0, 1.0)).toColor(),
      hsl
          .withHue((hsl.hue + 24) % 360)
          .withLightness((hsl.lightness - 0.09).clamp(0.0, 1.0))
          .toColor(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        MediaQuery.of(context).padding.top + AppSpacing.md,
        AppSpacing.md,
        AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientFor(color),
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: AppSpacing.sm),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
          if (stats.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                for (var i = 0; i < stats.length; i++) ...[
                  if (i > 0) const SizedBox(width: AppSpacing.sm),
                  Expanded(child: HeroStat(data: stats[i])),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class HeroStat extends StatelessWidget {
  const HeroStat({super.key, required this.data});

  final HeroStatData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(data.icon, color: Colors.white, size: 18),
          const SizedBox(height: 8),
          Text(
            data.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 20,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            data.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11),
          ),
        ],
      ),
    );
  }
}

/// Tombol ikon transparan untuk diletakkan di dalam [HeroHeader].
class HeroIconButton extends StatelessWidget {
  const HeroIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon, color: Colors.white),
      style: IconButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
