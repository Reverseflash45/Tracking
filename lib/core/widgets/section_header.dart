import 'package:flutter/material.dart';

/// Judul kelompok di dalam halaman.
///
/// Dulu tiap judul membawa ikon di dalam kotak berwarna. Diulang enam kali
/// dalam satu layar, kotak-kotak itu berhenti membantu membaca dan mulai
/// bersaing dengan isinya — padahal yang perlu menonjol justru angka dan
/// kalimat di kartunya, bukan penanda bagiannya.
///
/// Sekarang: judul tebal berhuruf kalimat, sama dengan judul bagian di
/// Beranda, tanpa ikon. Cukup besar untuk jadi penanda saat menggulir.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.icon,
    this.color,
    this.trailing,
  });

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

    // Ikon di depan judul bagian dihapus: tiap bagian punya ikon adalah pola
    // template, dan labelnya sudah cukup. Parameter [icon] dan [color] tetap
    // diterima supaya pemanggil lama tidak perlu diubah.
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10, top: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
