import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/hero_header.dart';
import '../../../core/widgets/section_header.dart';
import '../data/sleep_repository.dart';
import '../domain/sleep_stats.dart';

const _color = AppColors.statusInProgress;
final _dayFormat = DateFormat('EEEE, d MMM', 'id_ID');

/// Pilihan cepat yang menutup hampir semua malam. Slider terlalu halus untuk
/// angka yang memang cuma kira-kira — tidak ada yang tahu tidurnya 6,7 jam.
const List<double> _pilihanJam = [4, 5, 5.5, 6, 6.5, 7, 7.5, 8, 8.5, 9, 10];

class SleepPage extends ConsumerWidget {
  const SleepPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(sleepLogsProvider);
    final logs = logsAsync.value ?? const <SleepLog>[];
    final ringkasan = summarizeSleep(logs);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(sleepLogsProvider),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            HeroHeader(
              title: 'Tidur',
              subtitle: 'Rata-rata $kSleepWindowDays hari terakhir',
              color: _color,
              leading: HeroIconButton(
                icon: Icons.arrow_back,
                tooltip: 'Kembali',
                onPressed: () => context.pop(),
              ),
              stats: [
                HeroStatData(
                  icon: Icons.bedtime_outlined,
                  value: ringkasan.kosong ? '-' : formatJamTidur(ringkasan.rataJam),
                  label: 'Rata-rata',
                ),
                HeroStatData(
                  icon: Icons.check_circle_outline,
                  value: '${ringkasan.hariCukup}',
                  label: 'Hari Cukup',
                ),
                HeroStatData(
                  icon: Icons.nights_stay_outlined,
                  value: '${ringkasan.hariKurang}',
                  label: 'Hari Kurang',
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.xl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _CatatCard(),
                  if (!ringkasan.kosong) ...[
                    const SizedBox(height: AppSpacing.lg),
                    _RingkasanCard(ringkasan: ringkasan),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  const SectionHeader(
                    title: 'Riwayat',
                    icon: Icons.history,
                    color: _color,
                  ),
                  if (logs.isEmpty)
                    const EmptyState(
                      icon: Icons.bedtime_outlined,
                      title: 'Belum ada catatan tidur',
                      subtitle: 'Catat semalam kamu tidur berapa jam',
                      color: _color,
                    )
                  else
                    for (final log in logs)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: _SleepTile(log: log),
                      ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CatatCard extends ConsumerStatefulWidget {
  const _CatatCard();

  @override
  ConsumerState<_CatatCard> createState() => _CatatCardState();
}

class _CatatCardState extends ConsumerState<_CatatCard> {
  bool _menyimpan = false;

  Future<void> _simpan(double jam) async {
    final userId = ref.read(currentUserProvider)?.id;
    if (userId == null) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _menyimpan = true);
    try {
      await ref.read(sleepRepositoryProvider).saveSleep(
            userId: userId,
            date: DateTime.now(),
            hours: jam,
          );
      ref.invalidate(sleepLogsProvider);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Gagal menyimpan: $e')));
    } finally {
      if (mounted) setState(() => _menyimpan = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hariIni = ref.watch(todaySleepProvider);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.bedtime, size: 18, color: _color),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    hariIni == null
                        ? 'Semalam tidur berapa jam?'
                        : 'Semalam: ${formatJamTidur(hariIni.hours)}',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              hariIni == null
                  ? 'Dicatat di tanggal bangun, jadi begadang sampai subuh '
                      'tetap masuk hari ini.'
                  : 'Ketuk angka lain kalau mau dibetulkan.',
              style: TextStyle(
                fontSize: 11.5,
                height: 1.4,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final jam in _pilihanJam)
                  ChoiceChip(
                    label: Text(formatJamTidur(jam)),
                    selected: hariIni?.hours == jam,
                    onSelected: _menyimpan ? null : (_) => _simpan(jam),
                    visualDensity: VisualDensity.compact,
                    selectedColor: _color.withValues(alpha: 0.18),
                    labelStyle: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: hariIni?.hours == jam ? _color : colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RingkasanCard extends StatelessWidget {
  const _RingkasanCard({required this.ringkasan});

  final SleepSummary ringkasan;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final cukup = ringkasan.rataJam >= kSleepTargetMin;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              formatJamTidur(ringkasan.rataJam),
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w900,
                height: 1.1,
                color: cukup ? AppColors.statusDone : AppColors.priorityMedium,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Rata-rata dari ${ringkasan.hariTercatat} hari yang kamu catat '
              '(anjuran umum ${kSleepTargetMin.round()}–${kSleepTargetMax.round()} jam). '
              '${ringkasan.persenCukup.round()}% di antaranya cukup.',
              style: TextStyle(
                fontSize: 12,
                height: 1.45,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Dihitung dari hari yang tercatat saja — hari yang lupa dicatat '
              'bukan hari kurang tidur.',
              style: TextStyle(
                fontSize: 11,
                height: 1.4,
                fontStyle: FontStyle.italic,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SleepTile extends ConsumerWidget {
  const _SleepTile({required this.log});

  final SleepLog log;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final cukup = log.hours >= kSleepTargetMin;

    return Dismissible(
      key: ValueKey(log.id),
      direction: DismissDirection.endToStart,
      background: Container(
        decoration: BoxDecoration(
          color: colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(AppTheme.radius),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Icon(Icons.delete_outline, color: colorScheme.onErrorContainer),
      ),
      onDismissed: (_) async {
        await ref.read(sleepRepositoryProvider).deleteSleep(log.id);
        ref.invalidate(sleepLogsProvider);
      },
      child: Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          dense: true,
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (cukup ? AppColors.statusDone : AppColors.priorityMedium)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              cukup ? Icons.bedtime : Icons.nights_stay_outlined,
              size: 16,
              color: cukup ? AppColors.statusDone : AppColors.priorityMedium,
            ),
          ),
          title: Text(
            formatJamTidur(log.hours),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          subtitle: Text(
            _dayFormat.format(log.loggedOn),
            style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
          ),
        ),
      ),
    );
  }
}
