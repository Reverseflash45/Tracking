import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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

const _tabs = [
  _TabData(
    icon: Icons.dashboard_outlined,
    selectedIcon: Icons.dashboard,
    label: 'Dashboard',
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
    icon: Icons.person_outline,
    selectedIcon: Icons.person,
    label: 'Profil',
    color: AppColors.profile,
  ),
];

/// Rangka app sekaligus tempat antrean offline dikirim ulang.
///
/// Pengirimannya dipicu saat app dibuka dan saat kembali dari latar belakang —
/// dua saat yang paling mungkin bersamaan dengan sinyal baru kembali ada,
/// tanpa perlu mendengarkan status jaringan terus-menerus.
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _kirimAntrean());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _kirimAntrean();
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
