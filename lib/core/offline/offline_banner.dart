import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'pending_writes.dart';

final _timeFormat = DateFormat('d MMM HH:mm', 'id_ID');

/// Pemberitahu bahwa ada catatan yang belum sampai ke server.
///
/// Ditampilkan hanya kalau antreannya berisi. Catatan yang tertahan tanpa
/// diberitahu itu lebih buruk daripada gagal menyimpan terang-terangan: kamu
/// mengira sudah tercatat, padahal ada di satu HP saja.
class OfflineBanner extends ConsumerStatefulWidget {
  const OfflineBanner({super.key});

  @override
  ConsumerState<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends ConsumerState<OfflineBanner> {
  bool _mengirim = false;

  Future<void> _kirimUlang() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _mengirim = true);

    final hasil = await ref.read(pendingWriteQueueProvider).flush();
    ref.invalidate(pendingWritesProvider);

    if (!mounted) return;
    setState(() => _mengirim = false);

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          hasil.terkirim == 0
              ? 'Masih belum bisa terkirim. Coba lagi kalau sinyalnya sudah ada.'
              : '${hasil.terkirim} catatan terkirim'
                  '${hasil.tersisa > 0 ? ', ${hasil.tersisa} masih menunggu' : ''}.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final antrean = ref.watch(pendingWritesProvider).value ?? const <PendingWrite>[];
    if (antrean.isEmpty) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Card(
        margin: EdgeInsets.zero,
        color: AppColors.priorityMedium.withValues(alpha: 0.12),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.cloud_off_outlined,
                      size: 20, color: AppColors.priorityMedium),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${antrean.length} catatan belum terkirim',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tersimpan di HP dan aman. Akan terkirim sendiri '
                          'begitu sinyalnya ada.',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              for (final item in antrean.take(4))
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Icon(Icons.schedule,
                          size: 12, color: colorScheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${item.label}  ·  ${_timeFormat.format(item.queuedAt)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      // Satu catatan yang selalu ditolak server akan menahan
                      // sisanya, jadi harus ada cara membuangnya sendiri.
                      InkWell(
                        onTap: () async {
                          await ref.read(pendingWriteQueueProvider).hapus(item.id);
                          ref.invalidate(pendingWritesProvider);
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(Icons.close,
                              size: 12, color: colorScheme.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                ),
              if (antrean.length > 4)
                Text(
                  'dan ${antrean.length - 4} lainnya',
                  style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _mengirim ? null : _kirimUlang,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: AppColors.priorityMedium,
                  ),
                  icon: _mengirim
                      ? const SizedBox(
                          height: 14,
                          width: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync, size: 16),
                  label: Text(_mengirim ? 'Mengirim...' : 'Kirim sekarang'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
