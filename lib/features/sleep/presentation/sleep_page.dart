import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/daftar_bergaris.dart';
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
            HeroHeader.sub(
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
                  label: 'Hari cukup',
                ),
                HeroStatData(
                  icon: Icons.nights_stay_outlined,
                  value: '${ringkasan.hariKurang}',
                  label: 'Hari kurang',
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
                    _RingkasanCard(ringkasan: ringkasan, logs: logs),
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
                    DaftarBergaris(
                      indentGaris: 50,
                      children: [for (final log in logs) _SleepTile(log: log)],
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
  const _RingkasanCard({required this.ringkasan, required this.logs});

  final SleepSummary ringkasan;
  final List<SleepLog> logs;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final cukup = ringkasan.rataJam >= kSleepTargetMin;

    // Satu nilai per malam untuk 14 malam terakhir; malam tanpa catatan null.
    final hariIni = DateTime.now();
    final awal = DateTime(hariIni.year, hariIni.month, hariIni.day)
        .subtract(const Duration(days: kSleepWindowDays - 1));
    final jam = List<double?>.filled(kSleepWindowDays, null);
    for (final log in logs) {
      final d = DateTime(log.loggedOn.year, log.loggedOn.month, log.loggedOn.day);
      final i = d.difference(awal).inDays;
      if (i >= 0 && i < kSleepWindowDays) jam[i] = log.hours;
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Rata-rata ${ringkasan.hariTercatat} malam',
                        style: TextStyle(fontSize: 12.5, color: colorScheme.onSurfaceVariant),
                      ),
                      Text(
                        formatJamTidur(ringkasan.rataJam),
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.8,
                          color: cukup ? colorScheme.onSurface : AppColors.priorityMedium,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (cukup ? AppColors.statusDone : AppColors.priorityMedium)
                        .withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    '${ringkasan.persenCukup.round()}% malam cukup',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: cukup ? AppColors.statusDone : AppColors.priorityMedium,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 130,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutCubic,
                builder: (context, t, _) => CustomPaint(
                  size: Size.infinite,
                  painter: _LukisTidur(
                    jam: jam,
                    t: t,
                    cukup: _color,
                    kurang: AppColors.priorityMedium,
                    pita: _color.withValues(alpha: 0.08),
                    kosong: colorScheme.surfaceContainerHigh,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  DateFormat('d MMM', 'id_ID').format(awal),
                  style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                ),
                const Spacer(),
                Text(
                  'Pita = anjuran ${kSleepTargetMin.round()}–${kSleepTargetMax.round()} jam',
                  style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                ),
                const Spacer(),
                Text(
                  'Semalam',
                  style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LukisTidur extends CustomPainter {
  _LukisTidur({
    required this.jam,
    required this.t,
    required this.cukup,
    required this.kurang,
    required this.pita,
    required this.kosong,
  });

  final List<double?> jam;
  final double t;
  final Color cukup;
  final Color kurang;
  final Color pita;
  final Color kosong;

  // Sumbu dimulai dari 3 jam, bukan nol: semua malam berkisar 5–9 jam, dan
  // dari nol selisih satu jam hampir tidak kelihatan.
  static const _min = 3.0;
  static const _maks = 11.0;

  @override
  void paint(Canvas canvas, Size size) {
    double y(double j) =>
        size.height - (j.clamp(_min, _maks) - _min) / (_maks - _min) * size.height;

    // Pita anjuran 7–9 jam di belakang batang.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(0, y(kSleepTargetMax), size.width, y(kSleepTargetMin)),
        const Radius.circular(6),
      ),
      Paint()..color = pita,
    );

    final n = jam.length;
    const celah = 6.0;
    final lebar = (size.width - celah * (n - 1)) / n;
    final r = Radius.circular(lebar / 2.5);
    for (var i = 0; i < n; i++) {
      final x = i * (lebar + celah);
      final v = jam[i];
      if (v == null) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(x, size.height - 4, lebar, 4), r),
          Paint()..color = kosong,
        );
        continue;
      }
      final top = y(_min + (v - _min) * t);
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTRB(x, top, x + lebar, size.height),
          topLeft: r,
          topRight: r,
        ),
        Paint()..color = (v >= kSleepTargetMin ? cukup : kurang).withValues(
          alpha: i == n - 1 ? 1 : 0.8,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(_LukisTidur old) => old.t != t || old.jam != jam;
}

class _SleepTile extends ConsumerWidget {
  const _SleepTile({required this.log});

  final SleepLog log;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final cukup = log.hours >= kSleepTargetMin;
    final warna = cukup ? _color : AppColors.priorityMedium;

    return Dismissible(
      key: ValueKey(log.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: colorScheme.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Icon(Icons.delete_outline, color: colorScheme.onErrorContainer),
      ),
      onDismissed: (_) async {
        await ref.read(sleepRepositoryProvider).deleteSleep(log.id);
        ref.invalidate(sleepLogsProvider);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(cukup ? Icons.bedtime_rounded : Icons.nights_stay_outlined, size: 20, color: warna),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                _dayFormat.format(log.loggedOn),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
            Text(
              formatJamTidur(log.hours),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: cukup ? colorScheme.onSurface : AppColors.priorityMedium,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
