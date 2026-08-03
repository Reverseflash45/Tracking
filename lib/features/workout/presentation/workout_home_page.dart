import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/hero_header.dart';
import '../../../core/widgets/menu_list.dart';
import '../../../core/widgets/section_header.dart';
import '../data/models/workout_session.dart';
import '../data/rest_day_repository.dart';
import 'rest_day_card.dart';
import 'workout_providers.dart';

/// Halaman utama Workout: pintu masuk ke semua alat, bukan tempat menumpuk
/// catatan.
///
/// Riwayat dipindah ke halamannya sendiri. Setahun latihan itu bisa 400 baris,
/// dan menaruhnya di bawah tombol-tombol utama membuat semua alat lain
/// tenggelam — kamu harus menggulir melewati ratusan sesi cuma untuk membuka
/// Nutrisi.
class WorkoutHomePage extends ConsumerWidget {
  const WorkoutHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(workoutSessionsProvider).value ?? const <WorkoutSession>[];
    final restDays = ref.watch(restDaysProvider).value ?? const <RestDay>[];
    final streak = ref.watch(workoutStreakProvider).value;

    final now = DateTime.now();
    final bulanIni = sessions
        .where((s) => s.sessionDate.year == now.year && s.sessionDate.month == now.month)
        .length;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/workout/new');
          ref.invalidate(workoutSessionsProvider);
        },
        backgroundColor: AppColors.workout,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Workout'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(workoutSessionsProvider);
          ref.invalidate(restDaysProvider);
        },
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            HeroHeader(
              title: 'Workout',
              subtitle: 'Riwayat latihan dan perkembanganmu',
              color: AppColors.workout,
              trailing: HeroIconButton(
                icon: Icons.show_chart,
                tooltip: 'Lihat progress',
                onPressed: () => context.push('/workout/progress'),
              ),
              stats: [
                HeroStatData(
                  icon: Icons.local_fire_department,
                  value: '${streak?.current ?? 0}',
                  label: 'Streak Aktif',
                ),
                HeroStatData(
                  icon: Icons.emoji_events_outlined,
                  value: '${streak?.best ?? 0}',
                  label: 'Streak Terbaik',
                ),
                HeroStatData(
                  icon: Icons.calendar_month_outlined,
                  value: '$bulanIni',
                  label: 'Bulan Ini',
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.md,
                96,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const RestDayCard(),
                  const SizedBox(height: AppSpacing.lg),

                  // Dikelompokkan menurut apa yang kamu buka, bukan dijejer
                  // delapan ubin seragam. Sebelumnya "Nutrisi", "Tidur", dan
                  // "Kalkulator Kalori" berdiri sederet dengan "Lari" dan
                  // "Muscle Builder" — semuanya berwarna sama, berukuran sama,
                  // tanpa memberi tahu mana yang catatan harian dan mana yang
                  // alat sekali pakai.
                  const SectionHeader(
                    title: 'Latihan',
                    icon: Icons.fitness_center_outlined,
                    color: AppColors.workout,
                  ),
                  MenuList(
                    items: [
                      MenuItemData(
                        icon: Icons.history,
                        label: 'Riwayat Latihan',
                        rute: '/workout/history',
                        warna: AppColors.workout,
                        keterangan: _keteranganRiwayat(sessions.length + restDays.length),
                      ),
                      const MenuItemData(
                        icon: Icons.directions_run,
                        label: 'Lari',
                        rute: '/workout/run',
                        warna: AppColors.workout,
                      ),
                      const MenuItemData(
                        icon: Icons.videocam_outlined,
                        label: 'Latihan Terpandu',
                        rute: '/workout/live',
                        warna: AppColors.workout,
                        keterangan: 'Dipandu hitungan dan waktu istirahat',
                      ),
                      const MenuItemData(
                        icon: Icons.sports_gymnastics,
                        label: 'Muscle Builder',
                        rute: '/workout/muscle',
                        warna: AppColors.workout,
                        keterangan: 'Panduan latihan per kelompok otot',
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  const SectionHeader(
                    title: 'Catatan Harian',
                    icon: Icons.event_repeat_outlined,
                  ),
                  const MenuList(
                    items: [
                      MenuItemData(
                        icon: Icons.restaurant_menu,
                        label: 'Nutrisi',
                        rute: '/workout/nutrition',
                        warna: AppColors.priorityMedium,
                        keterangan: 'Makan, minum, dan kalori hari ini',
                      ),
                      MenuItemData(
                        icon: Icons.bedtime_outlined,
                        label: 'Tidur',
                        rute: '/workout/sleep',
                        warna: AppColors.academic,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  const SectionHeader(
                    title: 'Badan',
                    icon: Icons.accessibility_new,
                  ),
                  const MenuList(
                    items: [
                      MenuItemData(
                        icon: Icons.insights,
                        label: 'Progres',
                        rute: '/workout/stats',
                        warna: AppColors.dashboard,
                        keterangan: 'Grafik berat badan, nutrisi, dan latihan',
                      ),
                      MenuItemData(
                        icon: Icons.accessibility_new,
                        label: 'Profil Tubuh',
                        rute: '/workout/body',
                        warna: AppColors.dashboard,
                        keterangan: 'Tinggi, berat, target',
                      ),
                      MenuItemData(
                        icon: Icons.local_fire_department,
                        label: 'Kalkulator Kalori',
                        rute: '/workout/calories',
                        warna: AppColors.dashboard,
                        keterangan: 'Kebutuhan kalori dan makro harian',
                      ),
                      MenuItemData(
                        icon: Icons.photo_camera_outlined,
                        label: 'Foto Progres',
                        rute: '/workout/photos',
                        warna: AppColors.dashboard,
                      ),
                    ],
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

/// Angka catatan ditaruh sebagai keterangan baris, bukan sebagai kartu
/// tersendiri. Jumlahnya berguna untuk tahu ada isinya atau belum, tapi tidak
/// cukup penting untuk memakan satu blok utuh di layar.
String _keteranganRiwayat(int jumlah) =>
    jumlah == 0 ? 'Belum ada catatan' : '$jumlah catatan tersimpan';
