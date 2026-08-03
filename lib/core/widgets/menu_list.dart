import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';

/// Satu baris di dalam [MenuList].
class MenuItemData {
  const MenuItemData({
    required this.icon,
    required this.label,
    required this.rute,
    this.warna,
    this.keterangan,
  });

  final IconData icon;
  final String label;
  final String rute;

  /// Warna aksen ikon. Null berarti ikut warna teks redup.
  final Color? warna;

  /// Kalimat pendek di bawah label. Diisi hanya kalau namanya belum
  /// menjelaskan dirinya. Keterangan yang cuma mengulang label justru menambah
  /// yang harus dibaca tanpa menambah yang diketahui.
  final String? keterangan;
}

/// Daftar tujuan berupa teks, bukan petak ikon.
///
/// Riset Nielsen Norman membandingkan keduanya langsung: petak gambar hanya
/// menampilkan sekitar empat item sekaligus dan membuat orang menggulir empat
/// kali lebih panjang dibanding daftar teks. Karena harus menggulir bolak-balik
/// untuk melihat semua pilihan, orang berhenti di pilihan pertama yang "cukup"
/// alih-alih memilih yang benar. Kesimpulannya: daftar teks untuk tingkat
/// navigasi atas, petak gambar hanya untuk tingkat dalam yang gambarnya memang
/// membedakan.
///
/// Di sini gambarnya tidak membedakan apa pun. Ikon kalkulator dan ikon badan
/// tidak memberi tahu mana "Kalkulator Kalori" dan mana "Profil Tubuh" —
/// tulisannya yang memberi tahu.
///
/// Ada alasan kedua yang lebih sederhana: jumlah pintasan di app ini jarang
/// habis dibagi tiga. Lima pintasan di petak tiga kolom menyisakan satu lubang
/// di baris kedua, dan lubang itu terbaca sebagai sesuatu yang belum selesai.
/// Daftar tidak pernah punya sisa.
class MenuList extends StatelessWidget {
  const MenuList({super.key, required this.items});

  final List<MenuItemData> items;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final (i, item) in items.indexed) ...[
            if (i > 0) const Divider(height: 1, indent: 52),
            _BarisMenu(item: item),
          ],
        ],
      ),
    );
  }
}

class _BarisMenu extends StatelessWidget {
  const _BarisMenu({required this.item});

  final MenuItemData item;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final warnaIkon = item.warna ?? colorScheme.onSurfaceVariant;

    return InkWell(
      onTap: () => context.push(item.rute),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 14,
        ),
        child: Row(
          children: [
            Icon(item.icon, size: 20, color: warnaIkon),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  if (item.keterangan case final keterangan?) ...[
                    const SizedBox(height: 2),
                    Text(
                      keterangan,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11.5, color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ],
        ),
      ),
    );
  }
}
