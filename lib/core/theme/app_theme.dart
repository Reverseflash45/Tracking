import 'package:flutter/material.dart';

/// Jarak, semuanya kelipatan 4.
///
/// Grid 8pt dipakai Apple maupun Google, dengan 4 sebagai setengah langkah
/// untuk jarak halus di dalam satu komponen. App ini dulu memakai 21 nilai
/// berbeda — termasuk 5, 6, 9, 13, 18, dan 26 — yang artinya tiap layar
/// meleset dari garis yang sama sedikit-sedikit. Melesetnya tidak kelihatan
/// satu per satu; yang kelihatan cuma rasa bahwa semuanya agak goyang.
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

/// Kelengkungan sudut, empat langkah.
///
/// Dulu ada 12 nilai berbeda, dan yang paling sering dipakai (10, 37 kali)
/// bukan yang ada di theme (16, 4 kali). Theme-nya ditulis lalu diabaikan.
///
/// Sudut yang berbeda-beda tanpa alasan membuat elemen yang sebenarnya sejenis
/// terlihat berasal dari app yang berbeda.
class AppRadius {
  AppRadius._();

  /// 12 — elemen kecil di dalam kartu: kapsul kategori, kotak ikon, tombol.
  static const double kecil = 12;

  /// 16 — kartu dan kolom isian. Ukuran baku.
  static const double kartu = 16;

  /// 24 — lembar yang naik dari bawah dan wadah selebar layar.
  static const double besar = 24;

  /// Setengah lingkaran penuh untuk bentuk pil.
  static const double kapsul = 999;
}

/// Tangga ukuran huruf. Enam langkah, dan tidak ada langkah ketujuh.
///
/// Sebelum ini theme tidak punya textTheme sama sekali, jadi tiap widget
/// mengarang ukurannya sendiri: 29 ukuran berbeda tersebar di 452 tempat,
/// termasuk 11.5, 12.5, 13.5, dan 14.5.
///
/// Langkahnya bukan cuma harus sedikit, tapi harus berjauhan. Panduan hierarki
/// visual memakai rasio 1.25–1.5x antar tingkat: di bawah itu mata tidak
/// mengenali bedanya sebagai "yang ini lebih penting", dan dua teks
/// bersebelahan yang bedanya satu piksel malah terbaca seperti layar yang
/// salah render. Karena itu 11 dan 13 ikut dihapus, bukan cuma yang setengah.
///
/// Lantainya 12sp. Material menaruh label terkecilnya di 11sp dan teks isi di
/// 14sp; app ini sebelumnya memakai 9 dan 10 untuk hal yang tetap harus
/// dibaca. Padat itu boleh, terlalu kecil untuk dibaca tidak.
class AppText {
  AppText._();

  /// 12 — label, kapsul, satuan. Sekecil-kecilnya yang boleh.
  static const double label = 12;

  /// 14 — teks isi dan judul baris daftar. Ukuran baku Material.
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
        bodySmall: TextStyle(fontSize: AppText.label, color: colorScheme.onSurfaceVariant),
        labelLarge: const TextStyle(fontSize: AppText.badan, fontWeight: FontWeight.w700),
        labelMedium: const TextStyle(fontSize: AppText.label, fontWeight: FontWeight.w600),
        labelSmall: TextStyle(fontSize: AppText.label, color: colorScheme.onSurfaceVariant),
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
          // Label bar bawah tetap di langkah terkecil. Ini penanda tujuan, dan
          // membesarkannya bikin lima label mulai berdesakan.
          (states) => TextStyle(
            fontSize: AppText.label,
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
