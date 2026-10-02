import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/share/image_share.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/hero_header.dart';
import '../../academic/data/models/class_schedule.dart' show weekDayName;
import '../../academic/presentation/academic_providers.dart';
import '../../nutrition/data/nutrition_repository.dart';
import '../../run/data/run_repository.dart';
import '../../watchlist/data/watchlist_repository.dart';
import '../../watchlist/domain/watchlist.dart';
import '../../workout/presentation/workout_providers.dart';
import '../domain/wrapped_stats.dart';
import 'wrapped_share_card.dart';

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

const _hariPendek = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

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

  /// Ketuk sepertiga kiri untuk mundur, sisanya untuk maju — seperti story.
  void _ketuk(TapUpDetails details, double lebar, int jumlah) {
    final mundur = details.localPosition.dx < lebar / 3;
    final tujuan = (_page + (mundur ? -1 : 1)).clamp(0, jumlah - 1);
    if (tujuan == _page) return;
    _pageController.animateToPage(
      tujuan,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  void _bagikan(WrappedStats stats) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SharePreviewPage(
          title: 'Bagikan rekap',
          accent: AppColors.profile,
          card: WrappedShareCard(stats: stats),
          fileName:
              'wrapped-${_period.name}-'
              '${DateTime.now().toIso8601String().substring(0, 10)}.png',
          text: 'Rekap ${stats.period.phrase}: ${stats.persona}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(tasksProvider).value;
    final sessions = ref.watch(workoutSessionsProvider).value;
    final foods = ref.watch(foodLogsProvider).value;
    final waters = ref.watch(waterLogsProvider).value;
    final runs = ref.watch(runsProvider).value;
    // Watchlist tidak dijadikan syarat: dia boleh kosong selamanya kalau kamu
    // memang tidak memakainya, dan menunggunya termuat akan menahan seluruh
    // rekap yang datanya sudah siap.
    final media = ref.watch(watchlistProvider).value ?? const <MediaItem>[];
    final loading =
        tasks == null || sessions == null || foods == null || waters == null || runs == null;

    WrappedStats hitung(DateTime now) => computeWrappedStats(
      period: _period,
      now: now,
      tasks: tasks!,
      sessions: sessions!,
      foods: foods!,
      waters: waters!,
      runs: runs!,
      media: media,
    );

    final now = DateTime.now();
    final stats = loading ? null : hitung(now);
    final lalu = loading ? null : hitung(momenSebelumnya(_period, now));

    final cards = stats == null ? const <StoryCardData>[] : _buildCards(stats, lalu!);

    return Scaffold(
      body: Column(
        children: [
          HeroHeader.sub(
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
            trailing: stats == null || stats.kosong
                ? null
                : HeroIconButton(
                    icon: Icons.ios_share,
                    tooltip: 'Bagikan rekap',
                    onPressed: () => _bagikan(stats),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: SegmentedButton<WrappedPeriod>(
              segments: [
                for (final period in WrappedPeriod.values)
                  ButtonSegment(value: period, label: Text(period.label)),
              ],
              selected: {_period},
              onSelectionChanged: (selection) => _setPeriod(selection.first),
            ),
          ),
          if (!loading && !stats!.kosong)
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
              child: _BilahStory(jumlah: cards.length, aktif: _page),
            ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : (stats!.kosong
                      ? _EmptyWrapped(period: _period)
                      : LayoutBuilder(
                          builder: (context, constraints) => GestureDetector(
                            onTapUp: (d) => _ketuk(d, constraints.maxWidth, cards.length),
                            child: PageView.builder(
                              controller: _pageController,
                              itemCount: cards.length,
                              onPageChanged: (index) => setState(() => _page = index),
                              itemBuilder: (context, index) => Padding(
                                padding: EdgeInsets.fromLTRB(
                                  AppSpacing.md,
                                  0,
                                  AppSpacing.md,
                                  MediaQuery.of(context).padding.bottom + AppSpacing.md,
                                ),
                                child: StoryCard(
                                  // Kunci per periode: ganti periode = animasi
                                  // hitung naik diputar ulang dari nol.
                                  key: ValueKey('${_period.name}-$index'),
                                  data: cards[index],
                                  color: _storyColors[index % _storyColors.length],
                                ),
                              ),
                            ),
                          ),
                        )),
          ),
        ],
      ),
    );
  }

  List<StoryCardData> _buildCards(WrappedStats stats, WrappedStats lalu) {
    final phrase = stats.period.phrase;
    // Perbandingan hanya kalau periode lalu memang ada isinya. "▲ 12 dari
    // bulan lalu" saat bulan lalu app belum dipakai cuma membanggakan hal
    // yang tidak terjadi.
    final banding = lalu.kosong ? null : stats.period.phraseSebelumnya;
    Selisih? selisih(num sekarang, num sebelumnya) =>
        banding == null ? null : Selisih(sekarang - sebelumnya, banding);

    return [
      StoryCardData(
        icon: Icons.auto_awesome,
        eyebrow: 'Rekap $phrase',
        teks: stats.persona,
        caption: 'Julukanmu berdasarkan aktivitas $phrase',
      ),
      StoryCardData(
        icon: Icons.task_alt,
        eyebrow: 'Tugas selesai',
        angka: stats.tugasSelesai,
        selisih: selisih(stats.tugasSelesai, lalu.tugasSelesai),
        caption: stats.tugasSelesai == 0
            ? 'Belum ada tugas yang diselesaikan $phrase'
            : '${stats.persenTepatWaktu}% di antaranya tepat waktu',
        persen: stats.tugasSelesai == 0 ? null : stats.persenTepatWaktu / 100,
      ),
      StoryCardData(
        icon: Icons.fitness_center,
        eyebrow: 'Sesi workout',
        angka: stats.sesiWorkout,
        selisih: selisih(stats.sesiWorkout, lalu.sesiWorkout),
        caption: [
          if (stats.totalVolume > 0)
            'Total volume ${_numberFormat.format(stats.totalVolume.round())} kg'
          else
            'Belum ada sesi angkat beban $phrase',
          if (stats.latihanFavorit != null)
            'Paling sering: ${stats.latihanFavorit!.label} (${stats.latihanFavorit!.count}x)',
        ].join('\n'),
      ),
      // Kartu nutrisi hanya muncul kalau memang ada catatannya — kartu berisi
      // "0 kkal" tidak memberi tahu apa pun selain bahwa fiturnya belum dipakai.
      if (!stats.nutrisi.kosong)
        StoryCardData(
          icon: Icons.restaurant_menu,
          eyebrow: stats.nutrisi.hariTercatat == 0 ? 'Gelas air' : 'Rata-rata kalori',
          angka: stats.nutrisi.hariTercatat == 0
              ? stats.nutrisi.totalGelas
              : stats.nutrisi.rataKalori.round(),
          satuan: stats.nutrisi.hariTercatat == 0 ? null : 'kkal',
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
      if (!stats.tontonan.kosong)
        StoryCardData(
          icon: Icons.movie_outlined,
          eyebrow: 'Judul tamat',
          angka: stats.tontonan.judulTamat,
          caption: [
            if (stats.tontonan.asalTerbanyak case final asal?)
              'Paling banyak ${asal.label} (${asal.count} judul)'
            else
              'Ditamatkan $phrase',
            if (stats.tontonan.bentukTerbanyak case final bentuk?)
              'Kebanyakan ${bentuk.label.toLowerCase()}',
            if (stats.tontonan.rataNilai case final rata?)
              'Rata-rata nilaimu ${rata.toStringAsFixed(1)} '
                  'dari ${stats.tontonan.jumlahDinilai} judul',
          ].join('\n'),
        ),
      if (stats.sesiLari > 0)
        StoryCardData(
          icon: Icons.directions_run,
          eyebrow: 'Jarak lari',
          angka: stats.jarakLariMeter < 1000
              ? stats.jarakLariMeter.round()
              : stats.jarakLariMeter / 1000,
          satuan: stats.jarakLariMeter < 1000 ? 'm' : 'km',
          desimal: stats.jarakLariMeter < 1000 ? 0 : 1,
          selisih: banding == null
              ? null
              : Selisih(
                  (stats.jarakLariMeter - lalu.jarakLariMeter) / 1000,
                  banding,
                  satuan: 'km',
                  desimal: 1,
                ),
          caption: [
            '${stats.sesiLari} sesi lari $phrase',
            if (stats.lariTerjauhMeter > 0)
              'Terjauh sekali lari: '
                  '${(stats.lariTerjauhMeter / 1000).toStringAsFixed(2)} km',
          ].join('\n'),
        ),
      StoryCardData(
        icon: Icons.local_fire_department,
        eyebrow: 'Hari aktif',
        angka: stats.hariAktif,
        selisih: selisih(stats.hariAktif, lalu.hariAktif),
        caption: stats.hariPalingProduktif == null
            ? 'Hari dengan tugas selesai, workout, atau lari'
            : 'Paling produktif hari ${weekDayName(stats.hariPalingProduktif!)}',
        perHari: stats.aktivitasPerHari,
      ),
      StoryCardData(
        icon: Icons.emoji_events,
        eyebrow: 'Sorotan',
        angka: stats.prBeban?.weightKg,
        satuan: stats.prBeban == null ? null : 'kg',
        desimal:
            stats.prBeban == null ||
                stats.prBeban!.weightKg == stats.prBeban!.weightKg.roundToDouble()
            ? 0
            : 1,
        teks: stats.prBeban == null ? (stats.matkulTersibuk?.label ?? '-') : null,
        caption: [
          if (stats.prBeban != null) 'Beban terberat: ${stats.prBeban!.exerciseName}',
          if (stats.matkulTersibuk != null)
            'Matkul tersibuk: ${stats.matkulTersibuk!.label} (${stats.matkulTersibuk!.count} tugas)',
        ].join('\n'),
      ),
      StoryCardData(
        icon: Icons.grid_view_rounded,
        eyebrow: 'Ringkasan $phrase',
        teks: stats.persona,
        caption: '',
        ringkasan: [
          (Icons.task_alt, '${stats.tugasSelesai}', 'Tugas selesai'),
          (Icons.fitness_center, '${stats.sesiWorkout}', 'Sesi workout'),
          (Icons.local_fire_department, '${stats.hariAktif}', 'Hari aktif'),
          if (stats.sesiLari > 0)
            (
              Icons.directions_run,
              '${(stats.jarakLariMeter / 1000).toStringAsFixed(1)} km',
              'Lari',
            ),
          if (stats.totalVolume > 0)
            (Icons.scale_outlined, _numberFormat.format(stats.totalVolume.round()), 'Volume (kg)'),
          if (!stats.nutrisi.kosong && stats.nutrisi.hariTercatat > 0)
            (
              Icons.restaurant_menu,
              _numberFormat.format(stats.nutrisi.rataKalori.round()),
              'kkal/hari',
            ),
        ],
        onBagikan: () => _bagikan(stats),
      ),
    ];
  }
}

/// Selisih dengan periode sebelumnya.
class Selisih {
  const Selisih(this.nilai, this.phrase, {this.satuan, this.desimal = 0});

  final num nilai;

  /// "bulan lalu", dst.
  final String phrase;
  final String? satuan;
  final int desimal;

  String get label {
    final besar = nilai.abs();
    if (besar < (desimal == 0 ? 1 : 0.05)) return 'Sama seperti $phrase';
    final angka = desimal == 0
        ? '${besar.round()}'
        : besar.toStringAsFixed(desimal).replaceAll('.', ',');
    return '${nilai > 0 ? '▲' : '▼'} $angka${satuan == null ? '' : ' $satuan'} dari $phrase';
  }
}

/// Isi satu kartu story.
class StoryCardData {
  const StoryCardData({
    required this.icon,
    required this.eyebrow,
    required this.caption,
    this.angka,
    this.teks,
    this.satuan,
    this.desimal = 0,
    this.selisih,
    this.persen,
    this.perHari,
    this.ringkasan,
    this.onBagikan,
  });

  final IconData icon;
  final String eyebrow;
  final String caption;

  /// Angka utama, dianimasikan menghitung naik. Diabaikan kalau [teks] ada.
  final num? angka;

  /// Isi utama berupa teks (julukan, nama matkul).
  final String? teks;
  final String? satuan;
  final int desimal;
  final Selisih? selisih;

  /// 0..1, digambar sebagai batang tipis (mis. persen tepat waktu).
  final double? persen;

  /// Tujuh angka Senin–Minggu, digambar sebagai grafik batang kecil.
  final List<int>? perHari;

  /// Kartu penutup: kisi angka ringkasan.
  final List<(IconData, String, String)>? ringkasan;
  final VoidCallback? onBagikan;
}

/// Bilah segmen di atas kartu, seperti story: segmen yang sudah lewat penuh,
/// yang sedang dibuka disorot.
class _BilahStory extends StatelessWidget {
  const _BilahStory({required this.jumlah, required this.aktif});

  final int jumlah;
  final int aktif;

  @override
  Widget build(BuildContext context) {
    final redup = Theme.of(context).colorScheme.outlineVariant;
    return Row(
      children: [
        for (var i = 0; i < jumlah; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              height: 4,
              decoration: BoxDecoration(
                color: i <= aktif ? _storyColors[aktif % _storyColors.length] : redup,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Satu kartu story. Publik supaya tata letaknya bisa diuji tanpa provider.
class StoryCard extends StatelessWidget {
  const StoryCard({super.key, required this.data, required this.color});

  final StoryCardData data;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final putihRedup = Colors.white.withValues(alpha: 0.85);

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: HeroHeader.gradientFor(color),
          ),
        ),
        child: Stack(
          children: [
            // Ikon besar samar di pojok: memberi kartu bentuk tanpa bersaing
            // dengan angkanya.
            Positioned(
              right: -36,
              bottom: -36,
              child: Icon(data.icon, size: 220, color: Colors.white.withValues(alpha: 0.09)),
            ),
            // Kartu bisa lebih tinggi dari layar pendek saat caption panjang,
            // jadi isinya bisa di-scroll sendiri.
            SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: _Muncul(
                child: Column(
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
                        color: putihRedup,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _IsiUtama(data: data),
                    if (data.selisih case final s?) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          s.label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                    if (data.persen case final p?) ...[
                      const SizedBox(height: AppSpacing.md),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: p),
                          duration: const Duration(milliseconds: 900),
                          curve: Curves.easeOutCubic,
                          builder: (_, v, _) => LinearProgressIndicator(
                            value: v,
                            minHeight: 8,
                            color: Colors.white,
                            backgroundColor: Colors.white.withValues(alpha: 0.22),
                          ),
                        ),
                      ),
                    ],
                    if (data.caption.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        data.caption,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.92),
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    ],
                    if (data.perHari case final perHari?) ...[
                      const SizedBox(height: AppSpacing.lg),
                      _GrafikPerHari(nilai: perHari),
                    ],
                    if (data.ringkasan case final isi?) ...[
                      const SizedBox(height: AppSpacing.lg),
                      _KisiRingkasan(isi: isi),
                    ],
                    if (data.onBagikan case final bagikan?) ...[
                      const SizedBox(height: AppSpacing.lg),
                      FilledButton.icon(
                        onPressed: bagikan,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: color,
                        ),
                        icon: const Icon(Icons.ios_share, size: 18),
                        label: const Text('Bagikan rekap'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IsiUtama extends StatelessWidget {
  const _IsiUtama({required this.data});

  final StoryCardData data;

  @override
  Widget build(BuildContext context) {
    const gayaTeks = TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.w900,
      fontSize: 34,
      height: 1.1,
    );

    final teks = data.teks;
    final angka = data.angka;
    if (teks != null || angka == null) return Text(teks ?? '-', style: gayaTeks);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: angka.toDouble()),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) {
        final tampil = data.desimal == 0
            ? _numberFormat.format(v.round())
            : v.toStringAsFixed(data.desimal).replaceAll('.', ',');
        return FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: tampil),
                if (data.satuan case final satuan?)
                  TextSpan(
                    text: ' $satuan',
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                  ),
              ],
            ),
            maxLines: 1,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 64,
              height: 1.05,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        );
      },
    );
  }
}

/// Isi kartu muncul sedikit dari bawah saat kartu dibuka.
class _Muncul extends StatelessWidget {
  const _Muncul({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      builder: (_, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, (1 - v) * 16), child: child),
      ),
      child: child,
    );
  }
}

class _GrafikPerHari extends StatelessWidget {
  const _GrafikPerHari({required this.nilai});

  final List<int> nilai;

  @override
  Widget build(BuildContext context) {
    final maks = nilai.fold<int>(0, (a, b) => a > b ? a : b);
    // Yang dipatok hanya tinggi area batang; label di atas dan bawahnya ikut
    // ukuran huruf, supaya tidak terpotong saat huruf diperbesar.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < 7; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  nilai[i] == 0 ? '' : '${nilai[i]}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                SizedBox(
                  height: 56,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: maks == 0 ? 0 : nilai[i] / maks),
                      duration: Duration(milliseconds: 500 + i * 60),
                      curve: Curves.easeOutCubic,
                      builder: (_, v, _) => Container(
                        height: 4 + v * 52,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(
                            alpha: nilai[i] == maks && maks > 0 ? 1 : 0.45,
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _hariPendek[i],
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 10.5),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _KisiRingkasan extends StatelessWidget {
  const _KisiRingkasan({required this.isi});

  final List<(IconData, String, String)> isi;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final (ikon, nilai, label) in isi)
          Container(
            width: 132,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(ikon, color: Colors.white, size: 18),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    nilai,
                    maxLines: 1,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 11.5),
                ),
              ],
            ),
          ),
      ],
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
