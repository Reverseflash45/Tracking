import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/domain/achievements.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../../../core/offline/offline_banner.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/hero_header.dart';
import '../../../core/widgets/menu_list.dart';
import '../../../core/widgets/section_header.dart';
import '../../academic/data/models/class_schedule.dart';
import '../../academic/data/models/task.dart';
import '../../academic/presentation/academic_providers.dart';
import '../../body/data/body_repository.dart';
import '../../body/domain/calorie_calculator.dart';
import '../../finance/data/finance_repository.dart';
import '../../finance/domain/finance_stats.dart';
import '../../nutrition/data/nutrition_repository.dart';
import '../../profile/data/profile_repository.dart';
import '../../workout/presentation/workout_providers.dart';

final _dayFormat = DateFormat('EEEE, d MMMM y', 'id_ID');

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(classSchedulesProvider);
          ref.invalidate(tasksProvider);
          ref.invalidate(workoutSessionsProvider);
          ref.invalidate(profileProvider);
          ref.invalidate(foodLogsProvider);
          ref.invalidate(waterLogsProvider);
        },
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const _HeroHeader(),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.xl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Ditaruh paling atas: catatan yang tertahan harus terlihat
                  // sebelum kamu menganggap semuanya sudah tersimpan.
                  const OfflineBanner(),
                  const _AchievementsRow(),

                  // Tiga pertanyaan, tiga kartu: apa yang harus kulakukan hari
                  // ini, bagaimana badanku, bagaimana uangku. Tiap kartu satu
                  // daftar bergaris, bukan kartu-kartu kecil yang ditumpuk.
                  const SectionHeader(title: 'Hari ini'),
                  const _KartuHariIni(),
                  const SizedBox(height: AppSpacing.lg),

                  const SectionHeader(title: 'Badan'),
                  const _KartuBadan(),
                  const SizedBox(height: AppSpacing.lg),

                  const SectionHeader(title: 'Uang'),
                  const _FinanceCard(),
                  const SizedBox(height: AppSpacing.lg),

                  const SectionHeader(title: 'Lainnya'),
                  const _PintasanLainnya(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sapaan dan tanggal di atas latar halaman, lalu tiga angka dalam satu strip.
///
/// Dulu blok gradient biru-ungu berisi avatar, sapaan berseru, dan tiga kotak
/// kaca berikon api, petir, dan centang. Sekarang tanggal jadi label kecil,
/// sapaannya besar dan tenang, dan angkanya berbicara sendiri tanpa ikon.
class _HeroHeader extends ConsumerWidget {
  const _HeroHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final user = ref.watch(currentUserProvider);
    final profile = ref.watch(profileProvider).value;
    final fullName = profile?.fullName;
    final displayName = (fullName != null && fullName.trim().isNotEmpty)
        ? fullName.trim().split(' ').first
        : (user?.email?.split('@').first ?? 'Mahasiswa');
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';
    final avatarUrl = profile?.avatarUrl;

    final workoutStreak = ref.watch(workoutStreakProvider).value?.current ?? 0;
    final deadlineStreak =
        ref.watch(deadlineStreakProvider).value?.current ?? 0;
    final doneToday =
        ref.watch(tasksProvider).value?.where((t) {
          final completed = t.completedAt;
          final now = DateTime.now();
          return completed != null &&
              completed.year == now.year &&
              completed.month == now.month &&
              completed.day == now.day;
        }).length ??
        0;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md + 4,
        MediaQuery.of(context).padding.top + 18,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _Menyusut(
                  child: Text(
                    _dayFormat.format(DateTime.now()).toUpperCase(),
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.9,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              HeroIconButton(
                icon: Icons.search,
                tooltip: 'Cari',
                onPressed: () => context.push('/search'),
              ),
              // Foto profil membuka Profil — pola yang sudah dikenal dari app lain.
              Semantics(
                button: true,
                label: 'Buka profil',
                child: InkWell(
                  onTap: () => context.push('/profile'),
                  customBorder: const CircleBorder(),
                  child: CircleAvatar(
                    radius: 17,
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    backgroundImage: avatarUrl != null
                        ? NetworkImage(avatarUrl)
                        : null,
                    child: avatarUrl == null
                        ? Text(
                            initial,
                            style: TextStyle(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          )
                        : null,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          _Menyusut(
            child: Text(
              'Halo, $displayName.',
              style: TextStyle(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w700,
                fontSize: 30,
                height: 1.1,
                letterSpacing: -0.9,
              ),
            ),
          ),
          const SizedBox(height: 18),
          KartuStatistik(
            stats: [
              HeroStatData(
                icon: Icons.local_fire_department,
                value: '$workoutStreak hari',
                label: 'Rutin latihan',
              ),
              HeroStatData(
                icon: Icons.bolt,
                value: '$deadlineStreak hari',
                label: 'Tepat waktu',
              ),
              HeroStatData(
                icon: Icons.task_alt,
                value: '$doneToday',
                label: 'Selesai hari ini',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Pintasan ke bagian yang tidak punya tab sendiri.
///
/// Dulu tersebar: Target dan Wishlist jadi tombol kecil di header, sedangkan
/// Watchlist, Kendaraan, dan Dokumen terkubur dua lapis di dalam Profil —
/// tempat orang mencari setelan, bukan mencari fitur. Sekarang kelimanya
/// berjajar di layar yang paling sering kamu buka.
/// Fitur yang tidak punya kartu ringkasan sendiri di Beranda.
///
/// Dulu lima petak ikon, tiga per baris — yang berarti baris kedua selalu
/// menyisakan satu lubang. Lubang itu terbaca sebagai sesuatu yang belum
/// selesai, dan jumlah pintasan di sini memang tidak akan pernah habis dibagi
/// tiga.
///
/// Keterangannya sengaja tidak diisi untuk yang namanya sudah menjelaskan
/// dirinya. "Target" tidak butuh; "Watchlist" butuh, karena namanya tidak
/// memberi tahu isinya film atau tempat menabung.
class _PintasanLainnya extends StatelessWidget {
  const _PintasanLainnya();

  static const _isi = [
    MenuItemData(
      icon: Icons.schedule_outlined,
      label: 'Rutinitas',
      rute: '/routine',
      warna: AppColors.dashboard,
      keterangan: 'Jadwal harian di luar kuliah',
    ),
    MenuItemData(
      icon: Icons.sticky_note_2_outlined,
      label: 'Catatan',
      rute: '/notes',
      warna: AppColors.note,
      keterangan: 'Apa pun yang perlu diingat',
    ),
    MenuItemData(
      icon: Icons.flag_outlined,
      label: 'Target',
      rute: '/goals',
      warna: AppColors.dashboard,
    ),
    MenuItemData(
      icon: Icons.favorite_outline,
      label: 'Wishlist',
      rute: '/wishlist',
      warna: AppColors.finance,
      keterangan: 'Barang yang ingin dibeli',
    ),
    MenuItemData(
      icon: Icons.movie_outlined,
      label: 'Watchlist',
      rute: '/watchlist',
      warna: AppColors.watchlist,
      keterangan: 'Film, series, buku, komik',
    ),
    MenuItemData(
      icon: Icons.two_wheeler,
      label: 'Kendaraan',
      rute: '/vehicle',
      warna: AppColors.vehicle,
      keterangan: 'Pajak, servis, dan bensin',
    ),
    MenuItemData(
      icon: Icons.badge_outlined,
      label: 'Dokumen',
      rute: '/documents',
      warna: AppColors.document,
      keterangan: 'KTP, SIM, paspor, kartu',
    ),
  ];

  @override
  Widget build(BuildContext context) => const MenuList(items: _isi);
}

/// muat. Tidak pernah memotong maupun memindahkan teks ke baris berikutnya.
class _Menyusut extends StatelessWidget {
  const _Menyusut({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: child,
    );
  }
}

class _AchievementsRow extends ConsumerWidget {
  const _AchievementsRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Badge "Workout 30 Hari" harus berarti 30 hari latihan. Hari istirahat
    // menyambung streak, tapi tidak boleh ikut mengisi lencananya.
    final workoutStreak =
        ref.watch(workoutStreakProvider).value?.activeInCurrent ?? 0;
    final deadlineStreak =
        ref.watch(deadlineStreakProvider).value?.current ?? 0;
    final achievements = computeAchievements(
      workoutStreak: workoutStreak,
      deadlineStreak: deadlineStreak,
    );

    if (achievements.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          for (final achievement in achievements)
            Chip(
              avatar: Icon(
                achievement.icon,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
              label: Text(achievement.label),
            ),
        ],
      ),
    );
  }
}

/// Pindah ke tab lain, bukan menumpuk halamannya di atas Beranda.
///
/// Kalau di-push, bar bawah tetap menunjuk Beranda padahal kamu sudah ada di
/// Jadwal, dan tombol kembali jadi satu-satunya jalan keluar — dua hal yang
/// tidak terjadi kalau kamu menekan tabnya langsung.
void _keTab(BuildContext context, int tab) {
  StatefulNavigationShell.of(context).goBranch(tab);
}

/// Satu kartu berisi baris-baris bergaris, bukan kartu per baris.
class _KartuDaftar extends StatelessWidget {
  const _KartuDaftar({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final (i, anak) in children.indexed) ...[
            if (i > 0) const Divider(height: 1, indent: AppSpacing.md),
            anak,
          ],
        ],
      ),
    );
  }
}

/// Baris dua kolom: keterangan di kiri, nilai di kanan.
class _Baris extends StatelessWidget {
  const _Baris({
    required this.judul,
    this.keterangan,
    this.kanan,
    this.warnaKanan,
    this.depan,
    this.onTap,
  });

  final String judul;
  final String? keterangan;
  final String? kanan;
  final Color? warnaKanan;
  final String? depan;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isi = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 13,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (depan != null)
            SizedBox(
              width: 52,
              child: Text(
                depan!,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.45,
                  color: colorScheme.onSurfaceVariant,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  judul,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
                if (keterangan != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    keterangan!,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (kanan != null) ...[
            const SizedBox(width: AppSpacing.sm),
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Text(
                kanan!,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: warnaKanan ?? colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ],
      ),
    );
    return onTap == null ? isi : InkWell(onTap: onTap, child: isi);
  }
}

/// Keadaan kosong di dalam kartu daftar — datar, tanpa ikon dalam lingkaran
/// dan tanpa seruan penyemangat.
class _BarisKosong extends StatelessWidget {
  const _BarisKosong(this.teks, {this.onTap});

  final String teks;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final redup = Theme.of(context).colorScheme.onSurfaceVariant;
    final isi = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 14,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(teks, style: TextStyle(fontSize: 13.5, color: redup)),
          ),
          if (onTap != null) Icon(Icons.chevron_right, size: 18, color: redup),
        ],
      ),
    );
    return onTap == null ? isi : InkWell(onTap: onTap, child: isi);
  }
}

/// "Kapan" dalam bahasa sehari-hari: Hari ini 23.59, Besok, 3 hari lagi.
(String, bool) _tenggat(DateTime deadline) {
  final sekarang = DateTime.now();
  final hari = DateTime(
    deadline.year,
    deadline.month,
    deadline.day,
  ).difference(DateTime(sekarang.year, sekarang.month, sekarang.day)).inDays;
  if (deadline.isBefore(sekarang)) return ('Terlambat', true);
  if (hari == 0) {
    return ('Hari ini ${DateFormat('HH.mm').format(deadline)}', true);
  }
  if (hari == 1) return ('Besok', true);
  if (hari < 7) return ('$hari hari lagi', false);
  return (DateFormat('d MMM', 'id_ID').format(deadline), false);
}

/// Jadwal kuliah dan tenggat terdekat dalam satu kartu: keduanya menjawab
/// pertanyaan yang sama — apa yang harus kulakukan hari ini.
class _KartuHariIni extends ConsumerWidget {
  const _KartuHariIni();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schedules = ref.watch(todaySchedulesProvider);
    final deadlines = ref.watch(upcomingDeadlinesProvider);
    void keJadwal() => _keTab(context, kTabJadwal);
    void keTugas() => _keTab(context, kTabTugas);

    final baris = <Widget>[
      ...schedules.when(
        data: (items) => items.isEmpty
            ? [_BarisKosong('Tidak ada kuliah hari ini.', onTap: keJadwal)]
            : [
                for (final ClassSchedule s in items)
                  _Baris(
                    depan: s.timeRangeLabel.split('-').first.trim(),
                    judul: s.courseName,
                    keterangan: [s.timeRangeLabel, ?s.room].join(' · '),
                    onTap: keJadwal,
                  ),
              ],
        loading: () => [
          const Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: LinearProgressIndicator(),
          ),
        ],
        error: (error, _) => [const _BarisKosong('Jadwal gagal dimuat.')],
      ),
      ...deadlines.when(
        data: (items) => items.isEmpty
            ? [
                _BarisKosong(
                  'Tidak ada tenggat dalam waktu dekat.',
                  onTap: keTugas,
                ),
              ]
            : [
                for (final AcademicTask t in items.take(4))
                  _barisTugas(t, keTugas),
              ],
        loading: () => const <Widget>[],
        error: (error, _) => [const _BarisKosong('Tugas gagal dimuat.')],
      ),
    ];
    return _KartuDaftar(children: baris);
  }

  Widget _barisTugas(AcademicTask t, VoidCallback onTap) {
    final (kapan, mendesak) = _tenggat(t.deadline);
    return _Baris(
      judul: t.title,
      keterangan: t.courseName,
      kanan: kapan,
      warnaKanan: mendesak ? AppColors.priorityHigh : null,
      onTap: onTap,
    );
  }
}

/// Latihan dan asupan hari ini, dua baris dalam satu kartu.
class _KartuBadan extends ConsumerWidget {
  const _KartuBadan();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final session = ref.watch(todayWorkoutSessionProvider);
    final todayAsync = ref.watch(todayNutritionProvider);
    final profile = ref.watch(bodyProfileProvider).value;
    final weight = ref.watch(currentWeightProvider).value;
    final targets = (profile == null || weight == null)
        ? null
        : calculateCalories(
            profile: profile,
            weightKg: weight,
            now: DateTime.now(),
          );

    final Widget barisLatihan = session.when(
      data: (data) => _Baris(
        judul: 'Latihan',
        keterangan: data == null
            ? 'Belum ada sesi hari ini'
            : '${data.exercises.length} gerakan tercatat${data.notes != null ? ' · ${data.notes}' : ''}',
        kanan: data == null ? 'Mulai' : 'Selesai',
        warnaKanan: data == null ? colorScheme.primary : AppColors.statusDone,
        onTap: () => _keTab(context, kTabWorkout),
      ),
      loading: () => const Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: LinearProgressIndicator(),
      ),
      error: (error, _) => const _BarisKosong('Latihan gagal dimuat.'),
    );

    final Widget barisAsupan = todayAsync.when(
      data: (today) {
        final lewat = targets != null && today.calories > targets.goalKcal;
        final air = '${(today.waterMl / 1000).toStringAsFixed(1)} L air';
        return InkWell(
          // Nutrisi bukan akar tab, jadi halamannya memang di-push.
          onTap: () => context.push('/workout/nutrition'),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              13,
              AppSpacing.md,
              14,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Asupan',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '${today.calories.round()}',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: lewat
                                  ? AppColors.priorityHigh
                                  : colorScheme.onSurface,
                            ),
                          ),
                          TextSpan(
                            text: targets == null
                                ? ' kkal'
                                : ' / ${targets.goalKcal} kkal',
                          ),
                        ],
                      ),
                      style: TextStyle(
                        fontSize: 12.5,
                        color: colorScheme.onSurfaceVariant,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                if (targets != null) ...[
                  const SizedBox(height: 10),
                  LinearProgressIndicator(
                    value: (today.calories / targets.goalKcal).clamp(0.0, 1.0),
                    minHeight: 5,
                    color: lewat
                        ? AppColors.priorityHigh
                        : colorScheme.onSurface,
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  today.kosong
                      ? 'Belum ada catatan makan · $air'
                      : 'Protein ${today.proteinG.round()} g · Karbo ${today.carbsG.round()} g · '
                            'Lemak ${today.fatG.round()} g · $air',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (error, _) => const _BarisKosong('Asupan gagal dimuat.'),
    );

    return _KartuDaftar(children: [barisLatihan, barisAsupan]);
  }
}

/// Ringkasan anggaran. Yang ditonjolkan jatah harian, bukan total pengeluaran —
/// "boleh habis berapa hari ini" lebih menentukan keputusanmu siang ini
/// daripada "sudah habis berapa bulan ini".
class _FinanceCard extends ConsumerWidget {
  const _FinanceCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final summaryAsync = ref.watch(financeSummaryProvider);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _keTab(context, kTabKeuangan),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: summaryAsync.when(
            data: (summary) {
              final jatah = summary.jatahHarian;
              final kebobolan = (summary.sisaBudget ?? 0) <= 0;

              if (jatah == null) {
                return Row(
                  children: [
                    Expanded(
                      child: Text(
                        summary.kosong
                            ? 'Belum ada catatan keuangan'
                            : 'Keluar ${formatRupiah(summary.pengeluaran)} periode ini',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_right, size: 20),
                  ],
                );
              }

              return Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        kebobolan ? 'Lewat anggaran' : 'Jatah hari ini',
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        kebobolan
                            ? formatRupiah(summary.sisaBudget!.abs())
                            : formatRupiah(jatah),
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          height: 1.1,
                          letterSpacing: -0.6,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          color: kebobolan
                              ? AppColors.priorityHigh
                              : colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    '${summary.sisaHari} hari lagi',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right, size: 20),
                ],
              );
            },
            loading: () => const SizedBox(
              height: 40,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (error, _) => Row(
              children: [
                Icon(Icons.error_outline, size: 18, color: colorScheme.error),
                const SizedBox(width: AppSpacing.sm),
                const Expanded(
                  child: Text(
                    'Gagal memuat keuangan',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
