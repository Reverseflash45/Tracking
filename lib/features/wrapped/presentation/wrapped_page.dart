import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/hero_header.dart';
import '../../academic/data/models/class_schedule.dart' show weekDayName;
import '../../academic/presentation/academic_providers.dart';
import '../../nutrition/data/nutrition_repository.dart';
import '../../run/data/run_repository.dart';
import '../../workout/presentation/workout_providers.dart';
import '../domain/wrapped_stats.dart';

final _numberFormat = NumberFormat.decimalPattern('id_ID');
final _rangeFormat = DateFormat('d MMM', 'id_ID');

/// Tiap halaman story punya warna sendiri supaya swipe-nya terasa berpindah bab.
const _storyColors = [
  AppColors.dashboard,
  AppColors.deadline,
  AppColors.workout,
  AppColors.academic,
  AppColors.profile,
];

class WrappedPage extends ConsumerStatefulWidget {
  const WrappedPage({super.key});

  @override
  ConsumerState<WrappedPage> createState() => _WrappedPageState();
}

class _WrappedPageState extends ConsumerState<WrappedPage> {
  final _pageController = PageController();
  WrappedPeriod _period = WrappedPeriod.bulanan;
  int _page = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _setPeriod(WrappedPeriod period) {
    setState(() {
      _period = period;
      _page = 0;
    });
    if (_pageController.hasClients) _pageController.jumpToPage(0);
  }

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(tasksProvider).value;
    final sessions = ref.watch(workoutSessionsProvider).value;
    final foods = ref.watch(foodLogsProvider).value;
    final waters = ref.watch(waterLogsProvider).value;
    final runs = ref.watch(runsProvider).value;
    final loading =
        tasks == null || sessions == null || foods == null || waters == null || runs == null;

    final stats = loading
        ? null
        : computeWrappedStats(
            period: _period,
            now: DateTime.now(),
            tasks: tasks,
            sessions: sessions,
            foods: foods,
            waters: waters,
            runs: runs,
          );

    final cards = stats == null ? const <_StoryCardData>[] : _buildCards(stats);

    return Scaffold(
      body: Column(
        children: [
          HeroHeader(
            title: 'Wrapped',
            subtitle: stats == null
                ? 'Menyiapkan rekapmu...'
                : '${_rangeFormat.format(stats.range.start)} - '
                    '${_rangeFormat.format(stats.range.end)}',
            color: AppColors.profile,
            leading: HeroIconButton(
              icon: Icons.arrow_back,
              tooltip: 'Kembali',
              onPressed: () => context.pop(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: SegmentedButton<WrappedPeriod>(
              segments: [
                for (final period in WrappedPeriod.values)
                  ButtonSegment(value: period, label: Text(period.label)),
              ],
              selected: {_period},
              onSelectionChanged: (selection) => _setPeriod(selection.first),
            ),
          ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : (stats!.kosong
                    ? _EmptyWrapped(period: _period)
                    : PageView.builder(
                        controller: _pageController,
                        itemCount: cards.length,
                        onPageChanged: (index) => setState(() => _page = index),
                        itemBuilder: (context, index) => Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.md,
                            0,
                            AppSpacing.md,
                            AppSpacing.md,
                          ),
                          child: _StoryCard(
                            data: cards[index],
                            color: _storyColors[index % _storyColors.length],
                          ),
                        ),
                      )),
          ),
          if (!loading && !stats!.kosong)
            Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).padding.bottom + AppSpacing.md,
                top: AppSpacing.sm,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < cards.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == _page ? 20 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: i == _page
                            ? _storyColors[i % _storyColors.length]
                            : Theme.of(context).colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  List<_StoryCardData> _buildCards(WrappedStats stats) {
    final phrase = stats.period.phrase;

    return [
      _StoryCardData(
        icon: Icons.auto_awesome,
        eyebrow: 'Rekap $phrase',
        value: stats.persona,
        valueIsText: true,
        caption: 'Julukanmu berdasarkan aktivitas $phrase',
      ),
      _StoryCardData(
        icon: Icons.task_alt,
        eyebrow: 'Tugas selesai',
        value: '${stats.tugasSelesai}',
        caption: stats.tugasSelesai == 0
            ? 'Belum ada tugas yang diselesaikan $phrase'
            : '${stats.persenTepatWaktu}% di antaranya tepat waktu',
      ),
      _StoryCardData(
        icon: Icons.fitness_center,
        eyebrow: 'Sesi workout',
        value: '${stats.sesiWorkout}',
        caption: stats.totalVolume > 0
            ? 'Total volume ${_numberFormat.format(stats.totalVolume.round())} kg'
            : 'Belum ada sesi angkat beban $phrase',
      ),
      // Kartu nutrisi hanya muncul kalau memang ada catatannya — kartu berisi
      // "0 kkal" tidak memberi tahu apa pun selain bahwa fiturnya belum dipakai.
      if (!stats.nutrisi.kosong)
        _StoryCardData(
          icon: Icons.restaurant_menu,
          eyebrow: 'Rata-rata kalori',
          value: stats.nutrisi.hariTercatat == 0
              ? '${stats.nutrisi.totalGelas}'
              : _numberFormat.format(stats.nutrisi.rataKalori.round()),
          valueIsText: false,
          caption: [
            if (stats.nutrisi.hariTercatat > 0)
              'Dari ${stats.nutrisi.hariTercatat} hari yang kamu catat'
            else
              'Gelas air diminum $phrase',
            if (stats.nutrisi.hariTercatat > 0)
              'Rata-rata protein ${stats.nutrisi.rataProtein.round()} g per hari',
            if (stats.nutrisi.makananFavorit != null)
              'Paling sering: ${stats.nutrisi.makananFavorit!.label} '
                  '(${stats.nutrisi.makananFavorit!.count}x)',
            if (stats.nutrisi.hariTercatat > 0 && stats.nutrisi.totalGelas > 0)
              '${stats.nutrisi.totalGelas} gelas air diminum',
          ].join('\n'),
        ),
      if (stats.sesiLari > 0)
        _StoryCardData(
          icon: Icons.directions_run,
          eyebrow: 'Jarak lari',
          value: stats.jarakLariMeter < 1000
              ? '${stats.jarakLariMeter.round()} m'
              : '${(stats.jarakLariMeter / 1000).toStringAsFixed(1)} km',
          caption: [
            '${stats.sesiLari} sesi lari $phrase',
            if (stats.lariTerjauhMeter > 0)
              'Terjauh sekali lari: '
                  '${(stats.lariTerjauhMeter / 1000).toStringAsFixed(2)} km',
          ].join('\n'),
        ),
      _StoryCardData(
        icon: Icons.local_fire_department,
        eyebrow: 'Hari aktif',
        value: '${stats.hariAktif}',
        caption: stats.hariPalingProduktif == null
            ? 'Hari dengan tugas selesai atau workout'
            : 'Paling produktif hari ${weekDayName(stats.hariPalingProduktif!)}',
      ),
      _StoryCardData(
        icon: Icons.emoji_events,
        eyebrow: 'Sorotan',
        value: stats.prBeban != null
            ? '${_numberFormat.format(stats.prBeban!.weightKg)} kg'
            : (stats.matkulTersibuk?.label ?? '-'),
        valueIsText: stats.prBeban == null,
        caption: [
          if (stats.prBeban != null) 'Beban terberat: ${stats.prBeban!.exerciseName}',
          if (stats.latihanFavorit != null)
            'Latihan tersering: ${stats.latihanFavorit!.label} (${stats.latihanFavorit!.count}x)',
          if (stats.matkulTersibuk != null)
            'Matkul tersibuk: ${stats.matkulTersibuk!.label} (${stats.matkulTersibuk!.count} tugas)',
        ].join('\n'),
      ),
    ];
  }
}

class _StoryCardData {
  const _StoryCardData({
    required this.icon,
    required this.eyebrow,
    required this.value,
    required this.caption,
    this.valueIsText = false,
  });

  final IconData icon;
  final String eyebrow;
  final String value;
  final String caption;

  /// Teks (mis. julukan) perlu font lebih kecil daripada angka besar.
  final bool valueIsText;
}

class _StoryCard extends StatelessWidget {
  const _StoryCard({required this.data, required this.color});

  final _StoryCardData data;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: HeroHeader.gradientFor(color),
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      // Kartu bisa jadi lebih tinggi dari layar pendek saat caption panjang,
      // jadi isinya dibuat bisa di-scroll sendiri.
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
              ),
              child: Icon(data.icon, color: Colors.white, size: 26),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              data.eyebrow.toUpperCase(),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              data.value,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: data.valueIsText ? 36 : 64,
                height: 1.05,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              data.caption,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyWrapped extends StatelessWidget {
  const _EmptyWrapped({required this.period});

  final WrappedPeriod period;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.profile.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.hourglass_empty, size: 32, color: AppColors.profile),
            ),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'Belum cukup data',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Belum ada tugas selesai, sesi workout, atau catatan makan '
              '${period.phrase}. Coba pilih periode yang lebih panjang.',
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
