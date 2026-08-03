import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/academic/data/recurring_task_generator.dart';
import '../offline/pending_writes.dart';
import '../theme/app_colors.dart';

class _TabData {
  const _TabData({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final Color color;
}

/// Urutan tab, dipakai kartu ringkasan di Beranda untuk pindah ke bagiannya.
///
/// Angkanya harus sama persis dengan urutan `branches` di app_router.dart.
///
/// Lima, bukan enam. Material membatasi bar bawah di 3–5 tujuan, dan alasannya
/// bukan estetika: di bawah itu tiap tujuan kehilangan lebar sentuh dan
/// labelnya mulai terpotong. Yang dikeluarkan Profil — dia berisi setelan,
/// rekap, dan ekspor, hal-hal yang dibuka sesekali, bukan tiap hari seperti
/// empat lainnya. Jalan masuknya pindah ke foto profil di Beranda, tempat
/// orang memang mencarinya.
const int kTabBeranda = 0;
const int kTabJadwal = 1;
const int kTabTugas = 2;
const int kTabWorkout = 3;
const int kTabKeuangan = 4;

const _tabs = [
  _TabData(
    icon: Icons.dashboard_outlined,
    selectedIcon: Icons.dashboard,
    // "Beranda", bukan "Dashboard": dengan enam tab, label terpanjang yang
    // menentukan apakah semuanya masih terbaca di layar 360dp.
    label: 'Beranda',
    color: AppColors.dashboard,
  ),
  _TabData(
    icon: Icons.event_note_outlined,
    selectedIcon: Icons.event_note,
    label: 'Jadwal',
    color: AppColors.academic,
  ),
  _TabData(
    icon: Icons.checklist_outlined,
    selectedIcon: Icons.checklist,
    label: 'Tugas',
    color: AppColors.deadline,
  ),
  _TabData(
    icon: Icons.fitness_center_outlined,
    selectedIcon: Icons.fitness_center,
    label: 'Workout',
    color: AppColors.workout,
  ),
  _TabData(
    icon: Icons.account_balance_wallet_outlined,
    selectedIcon: Icons.account_balance_wallet,
    // "Keuangan", sama persis dengan judul halaman yang dituju. Dulu "Uang"
    // karena enam tab tidak menyisakan lebar; dengan lima tab ruangnya ada,
    // dan label yang berbeda dari judul tujuannya membuat orang ragu apakah
    // dia sudah sampai di tempat yang benar.
    label: 'Keuangan',
    color: AppColors.finance,
  ),
];

/// Rangka app sekaligus tempat kerja latar dipicu.
///
/// Dua hal berjalan di sini: antrean tulis offline dikirim ulang, dan tugas
/// berulang dibuat untuk minggu-minggu ke depan. Keduanya dipicu saat app
/// dibuka dan saat kembali dari latar belakang — dua saat yang paling mungkin
/// bersamaan dengan sinyal baru kembali ada, tanpa perlu mendengarkan status
/// jaringan terus-menerus.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _kerjaLatar());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _kerjaLatar();
  }

  Future<void> _kerjaLatar() async {
    await _kirimAntrean();
    if (!mounted) return;
    // Setelah antrean, bukan sebelum: tugas berulang dibuat lewat jaringan, dan
    // percuma mencobanya kalau tulisan yang tertunda saja belum bisa terkirim.
    await ref.read(recurringTaskGeneratorProvider).jalankan();
  }

  Future<void> _kirimAntrean() async {
    final hasil = await ref.read(pendingWriteQueueProvider).flush();
    if (hasil.terkirim > 0 && mounted) {
      ref.invalidate(pendingWritesProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final navigationShell = widget.navigationShell;
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: (index) => navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          ),
          destinations: [
            for (final tab in _tabs)
              NavigationDestination(
                icon: Icon(tab.icon),
                selectedIcon: Icon(tab.selectedIcon, color: tab.color),
                label: tab.label,
              ),
          ],
        ),
      ),
    );
  }
}
