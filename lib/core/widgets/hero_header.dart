import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class HeroStatData {
  const HeroStatData({
    required this.icon,
    required this.value,
    required this.label,
  });

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
      context.dependOnInheritedWidgetOfExactType<HeaderScope>()?.style ??
      GayaHeader.gradien;

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
      child: style == GayaHeader.gradien
          ? _buildGradien(context)
          : _buildDatar(context),
    );
  }

  /// Header akar tab: judul besar di atas latar halaman, bukan blok warna.
  ///
  /// Dulu ini blok gradient dengan rona digeser, sudut bawah membulat 28, dan
  /// tiga kotak kaca berikon — bentuk yang sama persis di kelima tab, hanya
  /// beda warna. Itu wajah template yang paling mudah dikenali. Sekarang
  /// judulnya yang besar, dan statistik menjadi satu strip bergaris tipis.
  /// Warna kategori tidak lagi mengecat header; tab bawah sudah memberi tahu
  /// di mana kamu berada.
  Widget _buildGradien(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md + 4,
        MediaQuery.of(context).padding.top + 20,
        AppSpacing.sm + 4,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 12)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                        fontSize: 28,
                        height: 1.15,
                        letterSpacing: -0.8,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 13.5,
                          height: 1.35,
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
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: KartuStatistik(stats: stats),
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
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    height: 1.1,
                    letterSpacing: -0.3,
                    fontFeatures: const [FontFeature.tabularFigures()],
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

/// Satu statistik berdiri sendiri: angka besar dan label, tanpa ikon.
class HeroStat extends StatelessWidget {
  const HeroStat({super.key, required this.data});

  final HeroStatData data;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Angka mengecil kalau kolomnya sempit, bukan terpotong jadi
        // "-Rp23…": angka yang tidak utuh lebih menyesatkan daripada kecil.
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            data.value,
            maxLines: 1,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w700,
              fontSize: 22,
              height: 1.1,
              letterSpacing: -0.5,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          data.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
        ),
      ],
    );
  }
}

/// Statistik dalam satu kartu, kolom dipisah garis rambut. Dipakai header akar
/// tab dan Beranda.
class KartuStatistik extends StatelessWidget {
  const KartuStatistik({super.key, required this.stats});

  final List<HeroStatData> stats;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surfaceContainerLow : colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            for (var i = 0; i < stats.length; i++) ...[
              if (i > 0)
                VerticalDivider(width: 1, color: colorScheme.outlineVariant),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: HeroStat(data: stats[i]),
                ),
              ),
            ],
          ],
        ),
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
    final colorScheme = Theme.of(context).colorScheme;
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon, color: colorScheme.onSurfaceVariant, size: 22),
    );
  }
}
