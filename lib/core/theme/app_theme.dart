import 'package:flutter/material.dart';

class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

/// Tangga ukuran huruf. Delapan langkah, dan tidak ada langkah kesembilan.
///
/// Sebelum ini theme tidak punya textTheme sama sekali, jadi tiap widget
/// mengarang ukurannya sendiri: 29 ukuran berbeda tersebar di 452 tempat,
/// termasuk 11.5, 12.5, 13.5, dan 14.5. Beda setengah piksel antara dua teks
/// bersebelahan tidak terbaca sebagai "yang ini lebih penting" — terbacanya
/// seperti layar yang salah render. Hierarki baru terasa kalau langkahnya
/// cukup jauh untuk terlihat.
///
/// Lantainya 11sp. Material menaruh label terkecilnya di 11sp dan teks isi di
/// 14sp; app ini sebelumnya memakai 9 dan 10 untuk hal yang tetap harus
/// dibaca. Padat itu boleh, terlalu kecil untuk dibaca tidak.
class AppText {
  AppText._();

  /// 11 — satuan, keterangan di bawah angka. Sekecil-kecilnya yang boleh.
  static const double mikro = 11;

  /// 12 — label, kapsul, teks di dalam tombol kecil.
  static const double label = 12;

  /// 13 — teks pendukung di dalam kartu.
  static const double isi = 13;

  /// 14 — teks utama dan judul baris daftar. Ukuran baku Material.
  static const double badan = 14;

  /// 16 — judul kartu.
  static const double judulKartu = 16;

  /// 20 — judul halaman.
  static const double judulHalaman = 20;

  /// 24 — angka ringkasan.
  static const double angka = 24;

  /// 32 — satu angka besar yang jadi inti sebuah layar.
  static const double angkaBesar = 32;
}

class AppTheme {
  AppTheme._();

  static const Color seedColor = Color(0xFF3B6FE5);
  static const double radius = 16;

  /// Peran Material dipetakan ke tangga di atas, supaya widget yang memakai
  /// `Theme.of(context).textTheme` mendarat di langkah yang sama dengan widget
  /// yang menulis ukurannya langsung.
  static TextTheme _textTheme(ColorScheme colorScheme) => TextTheme(
        displayLarge: const TextStyle(fontSize: AppText.angkaBesar, fontWeight: FontWeight.w800),
        displayMedium: const TextStyle(fontSize: AppText.angkaBesar, fontWeight: FontWeight.w800),
        displaySmall: const TextStyle(fontSize: AppText.angka, fontWeight: FontWeight.w800),
        headlineLarge: const TextStyle(fontSize: AppText.angka, fontWeight: FontWeight.w700),
        headlineMedium: const TextStyle(fontSize: AppText.judulHalaman, fontWeight: FontWeight.w700),
        headlineSmall: const TextStyle(fontSize: AppText.judulHalaman, fontWeight: FontWeight.w700),
        titleLarge: const TextStyle(fontSize: AppText.judulHalaman, fontWeight: FontWeight.w700),
        titleMedium: const TextStyle(fontSize: AppText.judulKartu, fontWeight: FontWeight.w700),
        titleSmall: const TextStyle(fontSize: AppText.badan, fontWeight: FontWeight.w700),
        bodyLarge: const TextStyle(fontSize: AppText.judulKartu),
        bodyMedium: const TextStyle(fontSize: AppText.badan),
        bodySmall: TextStyle(fontSize: AppText.isi, color: colorScheme.onSurfaceVariant),
        labelLarge: const TextStyle(fontSize: AppText.badan, fontWeight: FontWeight.w700),
        labelMedium: const TextStyle(fontSize: AppText.label, fontWeight: FontWeight.w600),
        labelSmall: TextStyle(fontSize: AppText.mikro, color: colorScheme.onSurfaceVariant),
      );

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(seedColor: seedColor, brightness: brightness);
    final isDark = brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      textTheme: _textTheme(colorScheme),
      scaffoldBackgroundColor: colorScheme.surfaceContainerLowest,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: colorScheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: isDark ? 0 : 1.5,
        shadowColor: colorScheme.shadow.withValues(alpha: 0.12),
        color: isDark ? colorScheme.surfaceContainerHigh : colorScheme.surfaceContainer,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        side: BorderSide.none,
        backgroundColor: colorScheme.surfaceContainerHighest,
        labelStyle: TextStyle(color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.4 : 0.6),
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.md),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.md),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.md),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.md)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.md)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        height: 68,
        backgroundColor: colorScheme.surface,
        indicatorColor: colorScheme.primaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 13,
            fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? colorScheme.onSurface
                : colorScheme.onSurfaceVariant,
          ),
        ),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
      ),
    );
  }
}
