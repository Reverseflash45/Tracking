import 'package:flutter/material.dart';

class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

class AppTheme {
  AppTheme._();

  static const Color seedColor = Color(0xFF4667D9);
  static const double radius = 16;

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  /// Garis rambut pembatas kartu.
  ///
  /// Sebelumnya kartu dipisahkan dengan bayangan di tema terang dan tidak
  /// dipisahkan sama sekali di tema gelap (`elevation: isDark ? 0 : 1.5`).
  /// Itu bukan pilihan gaya, itu memang tidak ada jalan keluarnya: bayangan
  /// bekerja dengan menggelapkan latar, dan di latar yang sudah gelap tidak
  /// ada lagi yang bisa digelapkan. Di tema gelap kartunya jadi bidang warna
  /// yang mengambang tanpa tepi.
  ///
  /// Garis satu piksel bekerja di kedua tema, dan kebetulan juga arah yang
  /// diambil Linear, Vercel, Stripe, dan Notion belakangan ini: tepi tegas
  /// terbaca lebih tegas daripada bayangan lembut, sementara bayangan mulai
  /// terbaca sebagai peninggalan gaya lama.
  static BorderSide _garisTepi(ColorScheme colorScheme, bool isDark) => BorderSide(
        color: colorScheme.outlineVariant.withValues(alpha: isDark ? 0.55 : 0.7),
        width: 1,
      );

  static ThemeData _build(Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(seedColor: seedColor, brightness: brightness);
    final isDark = brightness == Brightness.dark;
    final tepi = _garisTepi(colorScheme, isDark);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,

      // Latar halaman satu tingkat lebih gelap daripada kartu, di kedua tema.
      // Kartu yang lebih terang dari latarnya sudah setengah memisahkan diri
      // sebelum garis tepinya digambar.
      scaffoldBackgroundColor:
          isDark ? colorScheme.surfaceContainerLowest : colorScheme.surfaceContainerLow,

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
        elevation: 0,
        color: isDark ? colorScheme.surfaceContainerLow : colorScheme.surface,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          side: tepi,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),

      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant.withValues(alpha: isDark ? 0.5 : 0.6),
        thickness: 1,
        space: 1,
      ),

      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        side: BorderSide.none,
        backgroundColor: colorScheme.surfaceContainerHighest,
        labelStyle: TextStyle(color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? colorScheme.surfaceContainerHigh : colorScheme.surfaceContainerLow,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
        // Kolom isian ikut memakai garis tepi yang sama dengan kartu. Dulu
        // tidak bertepi sama sekali, jadi batas antara "tempat mengetik" dan
        // "latar" cuma beda terang yang sangat tipis.
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.md),
          borderSide: tepi,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.md),
          borderSide: tepi,
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
          side: tepi,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.md)),
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 2,
        highlightElevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.md)),
      ),

      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        height: 68,
        backgroundColor: colorScheme.surface,
        indicatorColor: colorScheme.primaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? colorScheme.onSurface
                : colorScheme.onSurfaceVariant,
          ),
        ),
      ),

      listTileTheme: ListTileThemeData(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark ? colorScheme.surfaceContainerLow : colorScheme.surface,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? colorScheme.surfaceContainerLow : colorScheme.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: tepi,
          borderRadius: BorderRadius.circular(radius + 4),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.md)),
      ),
    );
  }
}
