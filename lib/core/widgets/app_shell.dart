import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/academic/data/recurring_task_generator.dart';
import '../../features/health/data/health_connect.dart';
import '../../features/nutrition/data/nutrition_repository.dart';
import '../../features/profile/data/cadangan_lokal.dart';
import '../../features/profile/data/export_repository.dart';
import '../../features/sleep/data/sleep_repository.dart';
import '../crash/crash_reporter.dart';
import '../../features/routine/domain/berkala.dart';
import '../notifications/notification_service.dart';
import '../notifications/notification_settings_controller.dart';
import '../notifications/reminder_sync.dart';
import '../notifications/smart_reminders.dart' show kAwalanRute;
import '../offline/pending_writes.dart';
import '../supabase/supabase_client_provider.dart';
import '../update/update_checker.dart';
import '../update/update_dialog.dart';
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
/// labelnya mulai terpotong. Tab terakhir adalah Lainnya: profil di atasnya,
/// lalu semua fitur yang tidak punya tab sendiri, Keuangan salah satunya.
/// Satu tempat yang pasti berisi semuanya lebih mudah diingat daripada fitur
/// yang tersebar di pintasan Beranda dan halaman Profil.
const int kTabBeranda = 0;
const int kTabJadwal = 1;
const int kTabTugas = 2;
const int kTabWorkout = 3;
const int kTabLainnya = 4;

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
    icon: Icons.grid_view_outlined,
    selectedIcon: Icons.grid_view_rounded,
    // Profil, Keuangan, dan semua fitur yang tidak punya tab sendiri. Keuangan
    // dulu menempati tab ini; sekarang dia satu dari banyak isi Lainnya, dan
    // ringkasannya tetap di Beranda.
    label: 'Lainnya',
    color: AppColors.lainnya,
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
  StreamSubscription<NotificationResponse>? _notifikasi;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _notifikasi = responsNotifikasi.listen(_tanggapiNotifikasi);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _kerjaLatar();
      // App dibuka dari notifikasi yang diketuk saat app tertutup.
      final pembuka = await ref.read(notificationServiceProvider).responsPembuka();
      if (pembuka != null) _tanggapiNotifikasi(pembuka);
      await _tawarkanVersiBaru();
    });
  }

  @override
  void dispose() {
    _notifikasi?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    _kerjaLatar();
    // Izin alarm presisi diberikan di layar setelan sistem, jadi satu-satunya
    // saat untuk tahu hasilnya adalah ketika kamu kembali ke app.
    if (ref.read(notificationSettingsProvider).tepatWaktu) {
      ref.invalidate(reminderSyncProvider);
    }
  }

  /// Sekali per pembukaan app, dan dibatasi [kJedaCekUpdate] — bukan tiap
  /// kali kembali dari latar belakang.
  Future<void> _tawarkanVersiBaru() async {
    final checker = ref.read(updateCheckerProvider);
    final rilis = await checker.cekOtomatis();
    if (rilis == null) return;
    final versi = await checker.versiTerpasang();
    if (!mounted) return;
    await tawarkanUpdate(context, ref, rilis, versiSekarang: versi, otomatis: true);
  }

  /// Notifikasi rutinitas berkala yang diketuk membuka halamannya. Tombol
  /// "Sudah" sudah dicatat di antrean; di sini tinggal dikirim dan dimuat
  /// ulang.
  void _tanggapiNotifikasi(NotificationResponse respons) {
    if (!mounted) return;
    // Notifikasi yang membawa rute (rekap mingguan) membuka halamannya.
    final payload = respons.payload;
    if (payload != null && payload.startsWith(kAwalanRute)) {
      context.push(payload.substring(kAwalanRute.length));
      return;
    }
    if (PayloadBerkala.decode(payload) == null) return;
    if (respons.actionId == kAksiSelesai) {
      _kerjaLatar();
    } else {
      context.push('/routine/berkala');
    }
  }

  Future<void> _kerjaLatar() async {
    await _kirimAntrean();
    if (!mounted) return;
    unawaited(CrashReporter.instance.kirim(ref.read(supabaseClientProvider)));
    // Setelah antrean, bukan sebelum: tugas berulang dibuat lewat jaringan, dan
    // percuma mencobanya kalau tulisan yang tertunda saja belum bisa terkirim.
    await ref.read(recurringTaskGeneratorProvider).jalankan();
    if (!mounted) return;
    unawaited(_cadanganOtomatis());
    unawaited(_imporTidur());
  }

  /// Tidur dari jam tangan lewat Health Connect, kalau pernah disambungkan.
  Future<void> _imporTidur() async {
    final userId = ref.read(currentUserProvider)?.id;
    if (userId == null) return;
    try {
      final jumlah = await imporTidurHealthConnect(
        hc: ref.read(healthConnectProvider),
        repo: ref.read(sleepRepositoryProvider),
        userId: userId,
      );
      if (jumlah > 0 && mounted) ref.invalidate(sleepLogsProvider);
    } catch (e) {
      debugPrint('Impor tidur Health Connect gagal: $e');
    }
  }

  /// Seminggu sekali; biasanya langsung selesai tanpa melakukan apa-apa.
  Future<void> _cadanganOtomatis() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final hasil = await ref
        .read(cadanganLokalProvider)
        .jalankanKalauPerlu(ref.read(exportRepositoryProvider), email: user.email);
    if (hasil != null && mounted) ref.invalidate(daftarCadanganProvider);
  }

  Future<void> _kirimAntrean() async {
    final hasil = await ref.read(pendingWriteQueueProvider).flush();
    if (!mounted) return;
    // Jumlahnya juga bisa berubah tanpa ada yang terkirim: tombol "Sudah" di
    // notifikasi menulis ke antrean dari luar app.
    final terakhir = ref.read(pendingWritesProvider).value?.length ?? 0;
    if (hasil.terkirim > 0 || hasil.tersisa != terakhir) {
      ref.invalidate(pendingWritesProvider);
    }
    // Minum dari tombol widget dan makan yang dicatat offline baru ada di
    // server setelah terkirim; muat ulang supaya angkanya tidak tertinggal.
    if (hasil.terkirim > 0) {
      ref.invalidate(waterLogsProvider);
      ref.invalidate(foodLogsProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final navigationShell = widget.navigationShell;
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
        ),
        // Pil di belakang ikon aktif ikut warna tab-nya: tiap bagian punya
        // warna sendiri (Jadwal ungu, Tugas koral, …), dan bar bawah jadi
        // tempat pertama warna itu dikenali.
        child: NavigationBarTheme(
          data: Theme.of(context).navigationBarTheme.copyWith(
            indicatorColor: _tabs[navigationShell.currentIndex].color.withValues(alpha: 0.14),
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
      ),
    );
  }
}
