import 'package:flutter/material.dart';

/// Judul kelompok di dalam halaman.
///
/// Dulu tiap judul membawa ikon di dalam kotak berwarna. Diulang enam kali
/// dalam satu layar, kotak-kotak itu berhenti membantu membaca dan mulai
/// bersaing dengan isinya — padahal yang perlu menonjol justru angka dan
/// kalimat di kartunya, bukan penanda bagiannya.
///
/// Sekarang: huruf kecil, tebal, redup, dengan ikon polos seukuran huruf.
/// Judul bagian memang tugasnya mengalah.
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.icon, this.color, this.trailing});

  final String title;
  final IconData? icon;

  /// Warna aksen ikon. Null berarti ikut warna teks redup — dipakai judul yang
  /// mengelompokkan beberapa hal sekaligus, yang memang tidak mewakili satu
  /// kategori warna tertentu.
  final Color? color;

  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final warnaIkon = color ?? colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 10),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: warnaIkon),
            const SizedBox(width: 7),
          ],
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
