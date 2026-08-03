import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class HeroStatData {
  const HeroStatData({required this.icon, required this.value, required this.label});

  final IconData icon;
  final String value;
  final String label;
}

/// Dua tampilan untuk satu header.
///
/// [gradien] cuma dipakai lima akar tab. [datar] untuk semua halaman yang
/// dibuka dari halaman lain.
///
/// Ini keputusan yang paling mengubah rasa app-nya. Sebelumnya 33 sub-halaman
/// memakai header gradient penuh yang sama persis — warna berbeda-beda, tapi
/// bentuknya identik: blok gradient, tiga kotak kaca, sudut bawah membulat 28.
/// Diulang sebanyak itu, gradientnya berhenti berarti "ini bagian penting" dan
/// berubah jadi latar belakang yang selalu ada. Sekarang gradient jadi penanda
/// tempat: kalau layarmu bergradient, kamu ada di salah satu dari lima tujuan
/// utama; kalau datar, kamu sedang masuk ke dalam sesuatu.
enum GayaHeader { gradien, datar }

/// Membawa gaya header ke bawah pohon widget, supaya [HeroIconButton] tahu
/// harus tampil putih di atas gradient atau gelap di atas permukaan biasa —
/// tanpa satu pun halaman perlu mengubah pemanggilannya.
class HeaderScope extends InheritedWidget {
  const HeaderScope({super.key, required this.style, required super.child});

  final GayaHeader style;

  static GayaHeader of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<HeaderScope>()?.style ?? GayaHeader.gradien;

  @override
  bool updateShouldNotify(HeaderScope oldWidget) => oldWidget.style != style;
}

/// Header halaman.
///
/// Pakai [HeroHeader.sub] untuk halaman yang punya tombol kembali.
class HeroHeader extends StatelessWidget {
  const HeroHeader({
    super.key,
    required this.title,
    required this.color,
    this.subtitle,
    this.trailing,
    this.leading,
    this.stats = const [],
  }) : style = GayaHeader.gradien;

  /// Header untuk sub-halaman: tanpa gradient, tanpa kotak kaca.
  ///
  /// [color] tetap diminta, tapi sekarang cuma jadi aksen — warna ikon dan
  /// angka statistik. Warna kategori masih membedakan bagian tanpa harus
  /// mengecat seperlima layar.
  const HeroHeader.sub({
    super.key,
    required this.title,
    required this.color,
    this.subtitle,
    this.trailing,
    this.leading,
    this.stats = const [],
  }) : style = GayaHeader.datar;

  final String title;
  final Color color;
  final String? subtitle;
  final Widget? trailing;
  final Widget? leading;
  final List<HeroStatData> stats;
  final GayaHeader style;

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
    return HeaderScope(
      style: style,
      child: style == GayaHeader.gradien ? _buildGradien(context) : _buildDatar(context),
    );
  }

  Widget _buildGradien(BuildContext context) {
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

  Widget _buildDatar(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      color: colorScheme.surface,
      padding: EdgeInsets.fromLTRB(
        AppSpacing.sm,
        MediaQuery.of(context).padding.top + AppSpacing.sm,
        AppSpacing.sm,
        stats.isEmpty ? AppSpacing.sm : AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              ?leading,
              // Tanpa tombol kembali, judulnya tetap sejajar dengan judul
              // halaman lain — bukan menempel ke tepi kiri layar.
              SizedBox(width: leading == null ? AppSpacing.sm : 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                        fontSize: 19,
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 1),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
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
            const SizedBox(height: AppSpacing.md),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: _StatStrip(stats: stats, color: color),
            ),
          ],
        ],
      ),
    );
  }
}

/// Statistik versi datar: angka dan label saja, dipisah garis tipis.
///
/// Tanpa kotak, tanpa ikon. Ikon di kotak statistik tidak pernah menambah
/// pengertian — labelnya sudah menyebutkan hal yang sama dengan kata — dan
/// tiga kotak berikon berjajar adalah bentuk yang paling sering dipakai
/// template.
class _StatStrip extends StatelessWidget {
  const _StatStrip({required this.stats, required this.color});

  final List<HeroStatData> stats;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (var i = 0; i < stats.length; i++) ...[
          if (i > 0)
            Container(
              width: 1,
              height: 26,
              margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              color: colorScheme.outlineVariant.withValues(alpha: 0.6),
            ),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  stats[i].value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  stats[i].label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
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

/// Tombol ikon di dalam [HeroHeader].
///
/// Tampilannya mengikuti gaya header tempatnya berada, jadi halaman tidak
/// perlu tahu sedang bergradient atau datar.
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
    final datar = HeaderScope.of(context) == GayaHeader.datar;
    final colorScheme = Theme.of(context).colorScheme;

    if (datar) {
      return IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        icon: Icon(icon, color: colorScheme.onSurfaceVariant, size: 22),
      );
    }

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
