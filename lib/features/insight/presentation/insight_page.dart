import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/hero_header.dart';
import '../../academic/presentation/academic_providers.dart';
import '../../run/data/run_repository.dart';
import '../../workout/presentation/workout_providers.dart';
import '../domain/correlation.dart';

const _color = AppColors.dashboard;

/// Pola yang ditemukan dari data, dihitung ulang tiap halaman dibuka.
final insightsProvider = Provider.autoDispose<AsyncValue<List<Insight>>>((ref) {
  final tasks = ref.watch(tasksProvider);
  final sessions = ref.watch(workoutSessionsProvider);
  final runs = ref.watch(runsProvider);

  final error = tasks.error ?? sessions.error ?? runs.error;
  if (error != null) {
    return AsyncValue.error(
      error,
      tasks.stackTrace ?? sessions.stackTrace ?? runs.stackTrace ?? StackTrace.current,
    );
  }

  final t = tasks.value;
  final s = sessions.value;
  final r = runs.value;
  if (t == null || s == null || r == null) return const AsyncValue.loading();

  return AsyncValue.data(findInsights(tasks: t, sessions: s, runs: r));
});

/// Berapa minggu lagi sampai pola pertama bisa dihitung.
final insightReadinessProvider = Provider.autoDispose<int?>((ref) {
  final tasks = ref.watch(tasksProvider).value ?? const [];
  final sessions = ref.watch(workoutSessionsProvider).value ?? const [];
  final runs = ref.watch(runsProvider).value ?? const [];
  return weeksUntilReady(tasks: tasks, sessions: sessions, runs: runs);
});

/// 12 minggu terakhir untuk grafik. Null selama data masih dimuat.
final mingguTerakhirProvider = Provider.autoDispose<List<WeekBucket>?>((ref) {
  final tasks = ref.watch(tasksProvider).value;
  final sessions = ref.watch(workoutSessionsProvider).value;
  final runs = ref.watch(runsProvider).value;
  if (tasks == null || sessions == null || runs == null) return null;
  return mingguTerakhir(tasks: tasks, sessions: sessions, runs: runs, now: DateTime.now());
});

class InsightPage extends ConsumerWidget {
  const InsightPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insightsAsync = ref.watch(insightsProvider);
    final sisaMinggu = ref.watch(insightReadinessProvider);
    final minggu = ref.watch(mingguTerakhirProvider);

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          HeroHeader.sub(
            title: 'Pola',
            subtitle: 'Hubungan antara kebiasaan dan hasilmu',
            color: _color,
            leading: HeroIconButton(
              icon: Icons.arrow_back,
              tooltip: 'Kembali',
              onPressed: () => context.pop(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: insightsAsync.when(
              data: (insights) => insights.isEmpty
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _BelumCukup(sisaMinggu: sisaMinggu),
                        // Grafiknya tetap berguna selagi menunggu: kamu bisa
                        // melihat minggu mana yang masih kosong.
                        if (minggu != null &&
                            minggu.any((w) => w.sesiOlahraga + w.tugasSelesai > 0)) ...[
                          const SizedBox(height: AppSpacing.md),
                          GrafikMingguan(minggu: minggu),
                        ],
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _Pengantar(),
                        const SizedBox(height: AppSpacing.md),
                        if (minggu != null) ...[
                          GrafikMingguan(minggu: minggu),
                          const SizedBox(height: AppSpacing.md),
                        ],
                        for (final insight in insights)
                          Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: _InsightCard(insight: insight),
                          ),
                        const SizedBox(height: AppSpacing.md),
                        const _Peringatan(),
                      ],
                    ),
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => EmptyState(
                icon: Icons.error_outline,
                title: 'Gagal memuat',
                subtitle: '$error',
                color: _color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pengantar extends StatelessWidget {
  const _Pengantar();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Aplikasi lain tidak bisa menghitung ini: Strava tidak tahu nilaimu, '
      'aplikasi tugas tidak tahu kamu olahraga. Di sini keduanya ada.',
      style: TextStyle(
        fontSize: 13,
        height: 1.5,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.insight});

  final Insight insight;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final icon = switch (insight.kind) {
      InsightKind.olahragaVsKetepatan => Icons.task_alt,
      InsightKind.olahragaVsKecepatan => Icons.schedule,
      InsightKind.konsistensi => Icons.repeat,
    };

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: _color),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    insight.headline,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, height: 1.35),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              insight.detail,
              style: TextStyle(fontSize: 12, height: 1.5, color: colorScheme.onSurfaceVariant),
            ),
            if (insight.nilaiAktif != null && insight.nilaiSantai != null) ...[
              const SizedBox(height: AppSpacing.md),
              _BandingBatang(
                aktif: insight.nilaiAktif!,
                santai: insight.nilaiSantai!,
                persen: insight.kind == InsightKind.olahragaVsKetepatan,
              ),
            ] else if (insight.kind == InsightKind.konsistensi && insight.totalWeeks > 0) ...[
              const SizedBox(height: AppSpacing.md),
              _BarisMinggu(aktif: insight.weeksHigh, total: insight.totalWeeks),
            ],
            const SizedBox(height: 8),
            // Ukuran sampel ditampilkan terang-terangan. Pola dari 3 minggu
            // dan dari 30 minggu tidak sama bobotnya, dan kamu berhak tahu
            // yang mana yang sedang kamu baca.
            Text(
              insight.kind == InsightKind.konsistensi
                  ? 'Dari ${insight.totalWeeks} minggu'
                  : 'Dibanding dari ${insight.weeksHigh} minggu aktif dan '
                        '${insight.weeksLow} minggu jarang olahraga',
              style: TextStyle(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Peringatan extends StatelessWidget {
  const _Peringatan();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, size: 16, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Ini pola, bukan sebab-akibat. Bisa jadi olahraga membuatmu lebih '
                'teratur — bisa juga minggu yang longgar memang memberi ruang '
                'untuk keduanya sekaligus. Angkanya menunjukkan yang terjadi '
                'bersamaan, bukan yang menyebabkan.',
                style: TextStyle(fontSize: 12, height: 1.5, color: colorScheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BelumCukup extends StatelessWidget {
  const _BelumCukup({required this.sisaMinggu});

  final int? sisaMinggu;

  @override
  Widget build(BuildContext context) {
    // Dua keadaan berbeda: datanya belum cukup, atau datanya cukup tapi memang
    // tidak ada pola yang cukup kuat. Keduanya jangan disamakan.
    final belumCukupData = sisaMinggu != null;

    final terkumpul = belumCukupData ? kMingguDibutuhkan - sisaMinggu! : kMingguDibutuhkan;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EmptyState(
          icon: belumCukupData ? Icons.hourglass_empty : Icons.check_circle_outline,
          title: belumCukupData ? 'Belum cukup data' : 'Belum ada pola yang jelas',
          subtitle: belumCukupData
              ? 'Butuh sekitar $sisaMinggu minggu lagi yang ada tugas selesainya. '
                    'Pola dari sampel kecil cuma derau yang kebetulan berbentuk '
                    'kalimat meyakinkan.'
              : 'Datamu sudah cukup, tapi perbedaan antar minggu masih terlalu '
                    'kecil untuk disimpulkan. Itu bukan kabar buruk — artinya '
                    'hasilmu stabil.',
          color: _color,
        ),
        if (belumCukupData) ...[
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: terkumpul / kMingguDibutuhkan,
              minHeight: 8,
              color: _color,
              backgroundColor: _color.withValues(alpha: 0.12),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$terkumpul dari $kMingguDibutuhkan minggu terkumpul',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}

/// Dua batang: minggu aktif (≥3 hari olahraga) dan minggu jarang olahraga.
class _BandingBatang extends StatelessWidget {
  const _BandingBatang({required this.aktif, required this.santai, required this.persen});

  final double aktif;
  final double santai;

  /// True: angkanya persen 0–100. False: hari sebelum tenggat.
  final bool persen;

  String _label(double v) {
    if (persen) return '${v.round()}%';
    final r = (v * 10).round() / 10;
    final teks = (r == r.roundToDouble() ? r.round().toString() : r.toString()).replaceAll(
      '.',
      ',',
    );
    return '$teks hari';
  }

  @override
  Widget build(BuildContext context) {
    final maks = persen ? 100.0 : [aktif.abs(), santai.abs(), 0.5].reduce((a, b) => a > b ? a : b);
    return Column(
      children: [
        _Batang(
          label: 'Minggu aktif',
          nilai: _label(aktif),
          isi: aktif / maks,
          warna: AppColors.workout,
        ),
        const SizedBox(height: 6),
        _Batang(
          label: 'Minggu jarang',
          nilai: _label(santai),
          isi: santai / maks,
          warna: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ],
    );
  }
}

class _Batang extends StatelessWidget {
  const _Batang({required this.label, required this.nilai, required this.isi, required this.warna});

  final String label;
  final String nilai;
  final double isi;
  final Color warna;

  @override
  Widget build(BuildContext context) {
    final redup = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      children: [
        SizedBox(
          width: 92,
          child: Text(label, style: TextStyle(fontSize: 11.5, color: redup)),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: isi.clamp(0.0, 1.0)),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (_, v, _) => LinearProgressIndicator(
                value: v,
                minHeight: 10,
                color: warna,
                backgroundColor: warna.withValues(alpha: 0.12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 56,
          child: Text(
            nilai,
            textAlign: TextAlign.end,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

/// Satu kotak per minggu: terisi kalau minggu itu ada olahraganya.
class _BarisMinggu extends StatelessWidget {
  const _BarisMinggu({required this.aktif, required this.total});

  final int aktif;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        for (var i = 0; i < total; i++)
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: i < aktif ? AppColors.workout : AppColors.workout.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ],
    );
  }
}

/// Grafik 12 minggu: batang = hari olahraga, titik = ketepatan tugas.
///
/// Publik supaya bisa diuji tampilannya. Dua ukuran di satu grafik sengaja
/// tidak berbagi sumbu: batangnya hitungan hari (0–7), titiknya persen —
/// titik cuma diberi warna, bukan tinggi, supaya tidak ada yang mengira
/// keduanya diukur dengan skala yang sama.
class GrafikMingguan extends StatelessWidget {
  const GrafikMingguan({super.key, required this.minggu});

  final List<WeekBucket> minggu;

  static Color warnaTepat(WeekBucket w, ColorScheme cs) {
    if (w.tugasSelesai == 0) return cs.outlineVariant;
    final p = w.persenTepatWaktu;
    if (p >= 80) return AppColors.statusDone;
    if (p >= 50) return AppColors.priorityMedium;
    return AppColors.priorityHigh;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final redup = TextStyle(fontSize: 10.5, color: cs.onSurfaceVariant);
    final tanggal = DateFormat('d/M', 'id_ID');

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '12 minggu terakhir',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(height: AppSpacing.md),
            // Hanya area batang yang dipatok tingginya; titik dan label ikut
            // ukuran huruf supaya tidak terpotong saat huruf diperbesar.
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final (i, w) in minggu.indexed) ...[
                  if (i > 0) const SizedBox(width: 4),
                  Expanded(
                    child: Tooltip(
                      message:
                          'Minggu ${tanggal.format(w.start)}: ${w.sesiOlahraga} hari olahraga'
                          '${w.tugasSelesai == 0 ? '' : ', ${w.persenTepatWaktu.round()}% tugas tepat waktu'}',
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: warnaTepat(w, cs),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(height: 4),
                          SizedBox(
                            height: 80,
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0, end: w.sesiOlahraga.clamp(0, 7) / 7),
                                duration: Duration(milliseconds: 400 + i * 40),
                                curve: Curves.easeOutCubic,
                                builder: (_, v, _) => Container(
                                  height: 3 + v * 76,
                                  decoration: BoxDecoration(
                                    color: w.sesiOlahraga >= 3
                                        ? AppColors.workout
                                        : AppColors.workout.withValues(alpha: 0.4),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              i == minggu.length - 1 ? 'ini' : tanggal.format(w.start),
                              style: redup,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            const Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                _Legenda(warna: AppColors.workout, teks: 'Hari olahraga (penuh: ≥3)'),
                _Legenda(warna: AppColors.statusDone, teks: 'Tugas ≥80% tepat', bulat: true),
                _Legenda(warna: AppColors.priorityHigh, teks: '<50% tepat', bulat: true),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Legenda extends StatelessWidget {
  const _Legenda({required this.warna, required this.teks, this.bulat = false});

  final Color warna;
  final String teks;
  final bool bulat;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: warna,
            shape: bulat ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: bulat ? null : BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            teks,
            style: TextStyle(fontSize: 10.5, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}
