import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/notifications/notification_service.dart';
import '../../../core/notifications/notification_settings_controller.dart';
import '../../../core/notifications/smart_reminders.dart';
import '../../../core/offline/pending_writes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/hero_header.dart';
import '../data/berkala_repository.dart';
import '../domain/berkala.dart';
import 'berkala_form_sheet.dart';

const _color = AppColors.dashboard;

/// Tandai [item] selesai hari ini, dengan tombol batal di snackbar.
///
/// Publik karena Beranda juga memakainya. Tetap jalan tanpa sinyal: catatannya
/// masuk antrean dan terkirim begitu online.
Future<void> tandaiBerkalaSelesai(BuildContext context, RutinitasBerkala item) async {
  final messenger = ScaffoldMessenger.of(context);
  // Container, bukan ref: di Beranda kartunya hilang begitu ditandai selesai,
  // dan ref milik widget yang sudah dibuang tidak boleh dipakai lagi saat
  // tombol Batal ditekan.
  final container = ProviderScope.containerOf(context, listen: false);
  final repo = container.read(berkalaRepositoryProvider);

  void segarkan() {
    container.invalidate(pendingWritesProvider);
    container.invalidate(berkalaProvider);
    container.invalidate(riwayatBerkalaProvider(item.id));
  }

  final ({String logId, bool terkirim}) hasil;
  try {
    hasil = await repo.tandaiSelesai(item, DateTime.now());
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Gagal menandai: $e')));
    return;
  }
  segarkan();

  messenger.showSnackBar(
    SnackBar(
      content: Text(
        hasil.terkirim
            ? '${item.title} selesai. Berikutnya ${item.intervalDays} hari lagi.'
            : '${item.title} selesai — tersimpan di HP, dikirim begitu online.',
      ),
      action: SnackBarAction(
        label: 'Batal',
        onPressed: () async {
          try {
            await repo.batalkan(hasil.logId);
          } catch (e) {
            messenger.showSnackBar(SnackBar(content: Text('Gagal membatalkan: $e')));
            return;
          }
          segarkan();
        },
      ),
    ),
  );
}

/// Rutinitas berkala: hal yang diulang tiap beberapa hari, bukan tiap hari
/// tertentu dalam seminggu.
class BerkalaPage extends ConsumerWidget {
  const BerkalaPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(berkalaProvider);
    final semua = async.value ?? const <RutinitasBerkala>[];
    final now = DateTime.now();
    final perlu = semua.where((r) => r.perluDikerjakan(now)).length;
    final mendatang = [
      for (final r in semua)
        if (!r.perluDikerjakan(now)) r.sisaHari(now),
    ];

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _bukaForm(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Rutinitas'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(berkalaProvider),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            HeroHeader.sub(
              title: 'Rutinitas berkala',
              subtitle: 'Yang perlu diulang tiap beberapa hari',
              color: _color,
              leading: HeroIconButton(
                icon: Icons.arrow_back,
                tooltip: 'Kembali',
                onPressed: () => context.pop(),
              ),
              stats: [
                HeroStatData(
                  icon: Icons.event_repeat_outlined,
                  value: '${semua.length}',
                  label: 'Rutinitas',
                ),
                HeroStatData(
                  icon: Icons.notification_important_outlined,
                  value: '$perlu',
                  label: 'Perlu dikerjakan',
                ),
                HeroStatData(
                  icon: Icons.hourglass_bottom,
                  value: mendatang.isEmpty
                      ? '—'
                      : '${mendatang.reduce((a, b) => a < b ? a : b)}h',
                  label: 'Berikutnya',
                ),
              ],
            ),
            const _BannerPengingat(),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 96),
              child: async.when(
                data: (_) => semua.isEmpty
                    ? const EmptyState(
                        icon: Icons.event_repeat_outlined,
                        title: 'Belum ada rutinitas berkala',
                        subtitle: 'Misal absen akun tiap 25 hari, ganti sprei tiap '
                            '14 hari. Tekan + untuk menambah.',
                        color: _color,
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final item in semua)
                            Padding(
                              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                              child: KartuBerkala(
                                item: item,
                                onTap: () => _bukaForm(context, ref, item),
                                onSelesai: () => tandaiBerkalaSelesai(context, item),
                              ),
                            ),
                        ],
                      ),
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, _) => EmptyState(
                  icon: Icons.error_outline,
                  title: 'Gagal memuat rutinitas berkala',
                  subtitle: '$error',
                  color: _color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _bukaForm(BuildContext context, WidgetRef ref, [RutinitasBerkala? awal]) async {
    final hasil = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => BerkalaFormSheet(awal: awal),
    );
    if (hasil == true) ref.invalidate(berkalaProvider);
  }
}

/// Muncul kalau pengingat jenis ini tidak akan berbunyi — saklar utama mati,
/// atau jenisnya sendiri dimatikan. Tanpa ini kamu baru tahu notifikasinya
/// tidak jalan setelah absennya terlewat.
class _BannerPengingat extends ConsumerWidget {
  const _BannerPengingat();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(notificationServiceProvider);
    final settings = ref.watch(notificationSettingsProvider);
    if (!service.supported || settings.nyala(ReminderKind.berkala)) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
      child: Card(
        margin: EdgeInsets.zero,
        color: AppColors.deadline.withValues(alpha: 0.1),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.sm, AppSpacing.sm),
          child: Row(
            children: [
              const Icon(Icons.notifications_off_outlined, size: 20, color: AppColors.deadline),
              const SizedBox(width: AppSpacing.sm + 4),
              const Expanded(
                child: Text(
                  'Pengingat rutinitas berkala belum menyala.',
                  style: TextStyle(fontSize: 13),
                ),
              ),
              TextButton(
                onPressed: () async {
                  final controller = ref.read(notificationSettingsProvider.notifier);
                  final messenger = ScaffoldMessenger.of(context);
                  final aktif = settings.aktif || await controller.setAktif(true);
                  if (!aktif) {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Izin notifikasi ditolak. Aktifkan lewat setelan HP.'),
                      ),
                    );
                    return;
                  }
                  await controller.setJenis(ReminderKind.berkala, true);
                },
                child: const Text('Nyalakan'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Satu rutinitas berkala. Publik supaya Beranda bisa memakai tampilan yang
/// sama — dua tampilan berbeda untuk data yang sama akan mulai berbeda
/// pendapat soal kapan sesuatu "telat".
class KartuBerkala extends StatelessWidget {
  const KartuBerkala({
    super.key,
    required this.item,
    required this.onSelesai,
    this.onTap,
  });

  final RutinitasBerkala item;
  final VoidCallback onSelesai;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final sisa = item.sisaHari(now);
    final mendesak = sisa <= 1;
    final warna = mendesak ? AppColors.deadline : _color;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm + 4, AppSpacing.sm, AppSpacing.sm + 4),
          child: Row(
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: item.kemajuan(now),
                      strokeWidth: 4,
                      color: warna,
                      backgroundColor: warna.withValues(alpha: 0.14),
                    ),
                    Icon(Icons.event_repeat_outlined, size: 16, color: warna),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Tiap ${item.intervalDays} hari · terakhir '
                      '${DateFormat('d MMM', 'id_ID').format(item.lastDoneOn)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11.5, color: colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      labelSisaHari(sisa),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: mendesak ? AppColors.deadline : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              // Tombol selalu ada, bukan cuma saat jatuh tempo: kadang kamu
              // sudah absen lebih awal, dan hitungannya harus ikut mulai lagi.
              sisa <= 0
                  ? FilledButton.tonal(
                      onPressed: onSelesai,
                      style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
                      child: const Text('Sudah'),
                    )
                  : IconButton(
                      tooltip: 'Tandai sudah dilakukan hari ini',
                      onPressed: onSelesai,
                      icon: Icon(Icons.check_circle_outline, color: colorScheme.onSurfaceVariant),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
