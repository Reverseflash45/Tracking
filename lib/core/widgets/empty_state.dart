import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Tampilan saat belum ada isinya.
///
/// Dulu ikonnya duduk di dalam lingkaran berwarna. Karena widget ini muncul di
/// hampir tiap halaman, lingkaran itu jadi bentuk yang paling sering terlihat
/// di seluruh app — dan yang paling sering terlihat sebaiknya justru yang
/// paling tenang.
///
/// Panduan hierarki visual membagi kontras jadi tiga tingkat: yang utama
/// penuh, yang kedua 70–80%, yang ketiga 40–50%. Layar kosong itu tingkat
/// ketiga — dia mengabari, bukan menuntut. Jadi ikonnya diredupkan, judulnya
/// yang dapat kontras penuh, dan warna kategori tinggal satu titik di ikon,
/// bukan satu bidang di belakangnya.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.color,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  /// Warna aksen ikon, dibedakan per kategori. Null berarti ikut warna teks
  /// redup. Berapa pun warnanya, opasitasnya diturunkan di sini.
  final Color? color;

  /// True untuk versi ringkas (satu baris) di dalam kartu kecil di Beranda.
  /// False (default) untuk halaman kosong penuh.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final accent = (color ?? colorScheme.onSurfaceVariant).withValues(alpha: 0.55);

    if (compact) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            Icon(icon, size: 24, color: accent),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: AppText.badan,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle case final subtitle?) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: AppText.label,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      // Lega di atas dan bawah. Ruang kosong bukan ruang terbuang: ini
      // satu-satunya isi layar, dan menyempitkannya cuma membuat pesannya
      // terlihat seperti kesalahan.
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.xl + AppSpacing.md,
        horizontal: AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 32, color: accent),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            style: const TextStyle(
              fontSize: AppText.judulKartu,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          if (subtitle case final subtitle?) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: AppText.badan,
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
