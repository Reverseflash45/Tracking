import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'update_checker.dart';

/// Tawarkan versi baru. [otomatis] berarti muncul sendiri saat app dibuka —
/// "Nanti saja" di situ juga berarti versi ini tidak ditawarkan lagi.
Future<void> tawarkanUpdate(
  BuildContext context,
  WidgetRef ref,
  InfoRilis rilis, {
  required String versiSekarang,
  bool otomatis = false,
}) async {
  final colorScheme = Theme.of(context).colorScheme;
  final catatan = ringkasCatatan(rilis.catatan);

  final pilihan = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.system_update_alt),
      title: Text('Versi ${rilis.versi} tersedia'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Kamu memakai versi $versiSekarang.',
              style: TextStyle(fontSize: 12.5, color: colorScheme.onSurfaceVariant),
            ),
            if (catatan.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(catatan, style: const TextStyle(fontSize: 13, height: 1.4)),
            ],
            const SizedBox(height: 12),
            Text(
              rilis.apkArm64 == null
                  ? 'Unduh APK dari halaman rilis, lalu pasang.'
                  : '"Unduh" mengambil APK untuk hampir semua HP (arm64). '
                      'HP lama? Pilih arm32 di halaman rilis.',
              style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, 'nanti'), child: const Text('Nanti saja')),
        TextButton(onPressed: () => Navigator.pop(context, 'halaman'), child: const Text('Halaman rilis')),
        if (rilis.apkArm64 != null)
          FilledButton(onPressed: () => Navigator.pop(context, 'unduh'), child: const Text('Unduh')),
      ],
    ),
  );

  final tujuan = switch (pilihan) {
    'unduh' => rilis.apkArm64,
    'halaman' => rilis.halaman,
    _ => null,
  };
  if (tujuan != null) {
    await launchUrl(Uri.parse(tujuan), mode: LaunchMode.externalApplication);
  } else if (otomatis) {
    await ref.read(updateCheckerProvider).lewati(rilis.versi);
  }
}

/// Cek manual dari Profil: selalu memeriksa sekarang, dan memberi tahu juga
/// kalau sudah versi terbaru.
Future<void> cekUpdateManual(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(const SnackBar(content: Text('Memeriksa versi terbaru...')));
  final hasil = await ref.read(updateCheckerProvider).cek();
  messenger.hideCurrentSnackBar();
  if (!context.mounted) return;

  final rilis = hasil.rilisBaru;
  if (rilis == null) {
    messenger.showSnackBar(
      SnackBar(content: Text('Sudah versi terbaru (${hasil.versiSekarang}).')),
    );
    return;
  }
  await tawarkanUpdate(context, ref, rilis, versiSekarang: hasil.versiSekarang);
}
