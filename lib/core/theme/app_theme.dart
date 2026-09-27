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

  static const Color seedColor = Color(0xFF2E55C8);
  static const double radius = 14;
  static const String fontFamily = 'PlusJakartaSans';

  /// Permukaan netral, satu aksen.
  ///
  /// `ColorScheme.fromSeed` mewarnai SEMUA permukaan dengan rona benihnya —
  /// latar jadi lavender, kartu keunguan, kolom isian ungu muda. Itu wajah
  /// Material 3 bawaan yang langsung dikenali sebagai "belum didesain". Di sini
  /// hanya warna aksen yang berasal dari benih; latar, kartu, garis, dan teks
  /// dibuat abu-abu netral yang sedikit hangat, sehingga satu-satunya warna di
  /// layar adalah yang memang sedang menyampaikan sesuatu.
  static ColorScheme _skema(Brightness brightness) {
    final dasar = ColorScheme.fromSeed(seedColor: seedColor, brightness: brightness);
    if (brightness == Brightness.light) {
      return dasar.copyWith(
        primary: const Color(0xFF2E55C8),
        onPrimary: Colors.white,
        primaryContainer: const Color(0xFFE8EDFB),
        onPrimaryContainer: const Color(0xFF16307A),
        secondaryContainer: const Color(0xFFEDEDEA),
        onSecondaryContainer: const Color(0xFF17181B),
        surface: Colors.white,
        onSurface: const Color(0xFF17181B),
        onSurfaceVariant: const Color(0xFF686C73),
        surfaceContainerLowest: Colors.white,
        surfaceContainerLow: const Color(0xFFF5F5F2),
        surfaceContainer: const Color(0xFFF0F0ED),
        surfaceContainerHigh: const Color(0xFFEAEAE7),
        surfaceContainerHighest: const Color(0xFFE3E3E0),
        outline: const Color(0xFFC6C7C2),
        outlineVariant: const Color(0xFFE2E2DE),
        surfaceTint: Colors.transparent,
      );
    }
    return dasar.copyWith(
      primary: const Color(0xFF86A2F4),
      onPrimary: const Color(0xFF0B1A45),
      primaryContainer: const Color(0xFF1D2B55),
      onPrimaryContainer: const Color(0xFFD9E2FF),
      secondaryContainer: const Color(0xFF25282C),
      onSecondaryContainer: const Color(0xFFECEDEF),
      surface: const Color(0xFF141518),
      onSurface: const Color(0xFFECEDEF),
      onSurfaceVariant: const Color(0xFF9A9EA6),
      surfaceContainerLowest: const Color(0xFF0C0D0F),
      surfaceContainerLow: const Color(0xFF141518),
      surfaceContainer: const Color(0xFF1A1C1F),
      surfaceContainerHigh: const Color(0xFF202226),
      surfaceContainerHighest: const Color(0xFF282A2F),
      outline: const Color(0xFF3B3E44),
      outlineVariant: const Color(0xFF272A2E),
      surfaceTint: Colors.transparent,
    );
  }

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
    final colorScheme = _skema(brightness);
    final isDark = brightness == Brightness.dark;
    final tepi = _garisTepi(colorScheme, isDark);
    final teks = ThemeData(brightness: brightness).textTheme.apply(
          fontFamily: fontFamily,
          bodyColor: colorScheme.onSurface,
          displayColor: colorScheme.onSurface,
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      fontFamily: fontFamily,
      // Judul dirapatkan sedikit: huruf besar dengan jarak bawaan terlihat
      // renggang dan "dirakit", sementara badan teks dibiarkan lega.
      textTheme: teks.copyWith(
        headlineMedium: teks.headlineMedium?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.6),
        headlineSmall: teks.headlineSmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.4),
        titleLarge: teks.titleLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.3),
        titleMedium: teks.titleMedium?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.1),
        titleSmall: teks.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        labelLarge: teks.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),

      // Latar halaman satu tingkat lebih gelap daripada kartu, di kedua tema.
      // Kartu yang lebih terang dari latarnya sudah setengah memisahkan diri
      // sebelum garis tepinya digambar.
      scaffoldBackgroundColor:
          isDark ? colorScheme.surfaceContainerLowest : colorScheme.surfaceContainerLow,

      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 19,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
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

      // Chip netral; yang terpilih berganti jadi tinta gelap, bukan warna.
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        side: tepi,
        backgroundColor: isDark ? colorScheme.surfaceContainerLow : colorScheme.surface,
        selectedColor: colorScheme.onSurface,
        checkmarkColor: colorScheme.surface,
        showCheckmark: false,
        // Chip hanya me-resolve *warna* label per keadaan (lewat
        // WidgetStateColor), bukan TextStyle-nya secara utuh — jadi warna
        // terpilih harus dititipkan di sini, bukan di WidgetStateTextStyle.
        labelStyle: TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w600,
          fontSize: 13,
          color: WidgetStateColor.resolveWith((states) =>
              states.contains(WidgetState.selected) ? colorScheme.surface : colorScheme.onSurfaceVariant),
        ),
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
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          side: BorderSide(color: colorScheme.outline),
          foregroundColor: colorScheme.onSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),

      // Satu tombol tambah yang sama di semua tab: tinta gelap, bukan warna
      // kategori. Tombol berwarna berbeda-beda di tiap tab membuat aksi yang
      // sama terlihat seperti lima aksi berbeda.
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 1,
        highlightElevation: 0,
        backgroundColor: colorScheme.onSurface,
        foregroundColor: colorScheme.surface,
        extendedTextStyle: const TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w700, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),

      // Tanpa pil berwarna di balik ikon aktif: cukup ikon dan label yang
      // menebal. Garis rambut di atas menggantikan bayangan.
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        height: 64,
        backgroundColor: colorScheme.surface,
        indicatorColor: Colors.transparent,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 23,
            color: states.contains(WidgetState.selected) ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontFamily: fontFamily,
            fontSize: 11.5,
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: colorScheme.onSurface,
          selectedForegroundColor: colorScheme.surface,
          side: BorderSide(color: colorScheme.outlineVariant),
          textStyle: const TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w600),
        ),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.primary,
        linearTrackColor: colorScheme.surfaceContainerHighest,
        linearMinHeight: 6,
        borderRadius: BorderRadius.circular(99),
      ),
    );
  }
}
