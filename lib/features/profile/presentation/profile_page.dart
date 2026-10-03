import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../assistant/domain/preset_answers.dart' show questionCatalog;
import '../../../core/security/app_lock.dart';
import '../../../core/crash/crash_reporter.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../core/notifications/notification_settings_controller.dart';
import '../../../core/notifications/smart_reminders.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/update/update_checker.dart';
import '../../../core/update/update_dialog.dart';
import '../../../core/widgets/daftar_bergaris.dart';
import '../../../core/widgets/section_header.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/profile_repository.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  bool _uploadingAvatar = false;
  Future<void> _changeAvatar() async {
    final userId = ref.read(currentUserProvider)?.id;
    if (userId == null) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;

    setState(() => _uploadingAvatar = true);
    try {
      final bytes = await picked.readAsBytes();
      final ext = picked.name.contains('.') ? picked.name.split('.').last : 'jpg';
      await ref
          .read(profileRepositoryProvider)
          .uploadAvatar(userId: userId, bytes: bytes, fileExt: ext);
      ref.invalidate(profileProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal unggah foto: $e')));
      }
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final profile = ref.watch(profileProvider).value;
    final themeMode = ref.watch(themeModeControllerProvider);
    final colorScheme = Theme.of(context).colorScheme;

    final fullName = profile?.fullName;
    final displayName = (fullName != null && fullName.trim().isNotEmpty)
        ? fullName.trim()
        : 'Mahasiswa';
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';
    final avatarUrl = profile?.avatarUrl;

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Kartu identitas di atas latar polos. Dulu blok gradien ungu
          // selebar layar — satu-satunya gradien yang tersisa di app, dan
          // justru di halaman yang paling jarang dibuka.
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.sm,
              MediaQuery.of(context).padding.top + AppSpacing.sm,
              AppSpacing.md,
              0,
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'Kembali',
                  // Kalau halaman ini yang pertama dibuka (mis. dari tautan),
                  // tidak ada yang bisa dilepas — pulang ke Beranda.
                  onPressed: () => context.canPop() ? context.pop() : context.go('/'),
                ),
                const SizedBox(width: 4),
                const Text(
                  'Profil',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
            child: Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: _uploadingAvatar ? null : _changeAvatar,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          CircleAvatar(
                            radius: 34,
                            backgroundColor: AppColors.profile,
                            backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                            child: _uploadingAvatar
                                ? const CircularProgressIndicator(color: Colors.white)
                                : (avatarUrl == null
                                      ? Text(
                                          initial,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 26,
                                          ),
                                        )
                                      : null),
                          ),
                          Positioned(
                            right: -4,
                            bottom: -4,
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: colorScheme.onSurface,
                                shape: BoxShape.circle,
                                border: Border.all(color: colorScheme.surface, width: 2),
                              ),
                              child: Icon(Icons.camera_alt, size: 13, color: colorScheme.surface),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 19),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            user?.email ?? '-',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13.5),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Ketuk foto untuk menggantinya',
                            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(
                  title: 'Tampilan',
                  icon: Icons.palette_outlined,
                  color: AppColors.profile,
                ),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: SegmentedButton<ThemeMode>(
                      segments: const [
                        ButtonSegment(
                          value: ThemeMode.system,
                          label: Text('Sistem'),
                          icon: Icon(Icons.brightness_auto),
                        ),
                        ButtonSegment(
                          value: ThemeMode.light,
                          label: Text('Terang'),
                          icon: Icon(Icons.light_mode),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          label: Text('Gelap'),
                          icon: Icon(Icons.dark_mode),
                        ),
                      ],
                      selected: {themeMode},
                      onSelectionChanged: (selection) => ref
                          .read(themeModeControllerProvider.notifier)
                          .setThemeMode(selection.first),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                const SectionHeader(
                  title: 'Notifikasi',
                  icon: Icons.notifications_outlined,
                  color: AppColors.profile,
                ),
                const _NotificationSettingsCard(),
                const SizedBox(height: AppSpacing.md),
                if (kunciDidukung) ...[
                  const SectionHeader(
                    title: 'Keamanan',
                    icon: Icons.lock_outline,
                    color: AppColors.profile,
                  ),
                  const _KartuKunci(),
                  const SizedBox(height: AppSpacing.md),
                ],
                // Watchlist, Kendaraan, dan Dokumen dulu ada di sini. Sekarang
                // tinggal di tab Lainnya: Profil tempat orang mencari setelan
                // dan akun, bukan tempat mencari fitur.
                const SectionHeader(
                  title: 'Rekap',
                  icon: Icons.auto_awesome,
                  color: AppColors.profile,
                ),
                DaftarBergaris(
                  indentGaris: 62,
                  children: [
                    _MenuTile(
                      icon: Icons.auto_awesome,
                      color: AppColors.profile,
                      title: 'Wrapped',
                      subtitle: 'Rekap mingguan, bulanan, dan tahunanmu',
                      onTap: () => context.push('/profile/wrapped'),
                    ),
                    _MenuTile(
                      icon: Icons.insights,
                      color: AppColors.dashboard,
                      title: 'Pola',
                      subtitle: 'Hubungan antara olahraga dan tugasmu',
                      onTap: () => context.push('/profile/insight'),
                    ),
                    _MenuTile(
                      icon: Icons.help_outline,
                      color: AppColors.dashboard,
                      title: 'Tanya data',
                      // Dihitung dari katalog, bukan ditulis manual — angka yang
                      // dipatok akan basi begitu ada pertanyaan baru.
                      subtitle:
                          '${questionCatalog.length} pertanyaan siap pakai '
                          'tentang catatanmu',
                      onTap: () => context.push('/profile/tanya'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                const SectionHeader(
                  title: 'Data',
                  icon: Icons.backup_outlined,
                  color: AppColors.profile,
                ),
                DaftarBergaris(
                  children: [
                    _MenuTile(
                      icon: Icons.backup_outlined,
                      color: AppColors.finance,
                      title: 'Cadangan & pulihkan',
                      subtitle: 'Otomatis tiap minggu, bisa disimpan ke Drive',
                      onTap: () => context.push('/profile/cadangan'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                const SectionHeader(
                  title: 'Tentang',
                  icon: Icons.info_outline,
                  color: AppColors.profile,
                ),
                const _KartuTentang(),
                const SizedBox(height: AppSpacing.md),
                const SectionHeader(
                  title: 'Akun',
                  icon: Icons.person_outline,
                  color: AppColors.profile,
                ),
                Card(
                  child: ListTile(
                    leading: Icon(Icons.logout, color: colorScheme.error),
                    title: Text('Keluar', style: TextStyle(color: colorScheme.error)),
                    onTap: () => ref.read(authControllerProvider.notifier).signOut(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Saklar kunci app dan jedanya.
class _KartuKunci extends ConsumerStatefulWidget {
  const _KartuKunci();

  @override
  ConsumerState<_KartuKunci> createState() => _KartuKunciState();
}

class _KartuKunciState extends ConsumerState<_KartuKunci> {
  bool _sibuk = false;

  Future<void> _ubah(bool aktif) async {
    setState(() => _sibuk = true);
    final galat = await ref.read(kunciProvider.notifier).setAktif(aktif);
    if (!mounted) return;
    setState(() => _sibuk = false);
    if (galat != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(galat)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final kunci = ref.watch(kunciProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            value: kunci.aktif,
            onChanged: _sibuk || !kunci.siap ? null : _ubah,
            activeThumbColor: AppColors.profile,
            secondary: const Icon(Icons.fingerprint, color: AppColors.profile),
            title: const Text('Kunci app', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            subtitle: const Text(
              'Buka dengan sidik jari, wajah, atau PIN layar HP',
              style: TextStyle(fontSize: 12),
            ),
          ),
          if (kunci.aktif)
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Kunci lagi setelah di latar',
                    style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final jeda in kPilihanJeda)
                        ChoiceChip(
                          label: Text(labelJeda(jeda), style: const TextStyle(fontSize: 12)),
                          selected: kunci.jeda == jeda,
                          onSelected: (_) => ref.read(kunciProvider.notifier).setJeda(jeda),
                        ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Versi, cek pembaruan, dan saklar laporan error.
class _KartuTentang extends ConsumerWidget {
  const _KartuTentang();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final versi = ref.watch(versiAppProvider).value;

    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const SizedBox(width: 34, child: Icon(Icons.system_update_alt, size: 18)),
            title: const Text('Cek pembaruan'),
            subtitle: Text(versi == null ? 'Versi terpasang: …' : 'Versi terpasang: $versi'),
            onTap: () => cekUpdateManual(context, ref),
          ),
          const Divider(height: 1),
          ValueListenableBuilder<bool>(
            valueListenable: CrashReporter.instance.aktif,
            builder: (context, aktif, _) => SwitchListTile(
              secondary: const SizedBox(width: 34, child: Icon(Icons.bug_report_outlined, size: 18)),
              title: const Text('Kirim laporan error'),
              subtitle: const Text(
                'Kalau app error, pesan teknis dan letak error-nya di kode dikirim ke '
                'database app ini supaya bisa diperbaiki.',
                style: TextStyle(fontSize: 11.5),
              ),
              activeThumbColor: AppColors.profile,
              value: aktif,
              onChanged: (v) => CrashReporter.instance.setAktif(v),
            ),
          ),
        ],
      ),
    );
  }
}

/// Kartu menu di halaman profil.
///
/// Dijadikan satu widget karena ketiganya harus punya tinggi dan jarak yang
/// sama persis. Sebelumnya ditulis terpisah, dan subjudul yang panjangnya beda
/// membuat kartunya terlihat berdesakan satu sama lain.
class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      child: Padding(
        // Padding sendiri, bukan ListTile: subjudul dua baris di ListTile
        // menempel ke tepi kartu dan bikin sesak.
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, size: 18, color: Colors.white),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, height: 1.2),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.35,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Icon(Icons.chevron_right, size: 20, color: colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

/// Alarm presisi. Izinnya diberikan di layar setelan sistem, jadi saklar ini
/// juga memberi tahu kalau setelannya menyala tapi izinnya belum ada —
/// kalau tidak, kamu mengira alarmnya tepat padahal masih bisa bergeser.
class _SaklarTepatWaktu extends ConsumerStatefulWidget {
  const _SaklarTepatWaktu({required this.settings});

  final NotificationSettings settings;

  @override
  ConsumerState<_SaklarTepatWaktu> createState() => _SaklarTepatWaktuState();
}

class _SaklarTepatWaktuState extends ConsumerState<_SaklarTepatWaktu>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) ref.invalidate(izinAlarmTepatProvider);
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.settings;
    final controller = ref.read(notificationSettingsProvider.notifier);
    final diizinkan = ref.watch(izinAlarmTepatProvider).value ?? true;
    final kurangIzin = settings.tepatWaktu && !diizinkan;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SwitchListTile(
          secondary: const SizedBox(width: 34, child: Icon(Icons.alarm_on_outlined, size: 18)),
          title: const Text('Alarm tepat waktu', style: TextStyle(fontSize: 14)),
          subtitle: const Text(
            'Berbunyi tepat di jamnya. Tanpa ini Android bisa menggesernya beberapa menit.',
            style: TextStyle(fontSize: 11.5),
          ),
          dense: true,
          activeThumbColor: AppColors.profile,
          value: settings.tepatWaktu,
          onChanged: settings.aktif
              ? (value) async {
                  await controller.setTepatWaktu(value);
                  ref.invalidate(izinAlarmTepatProvider);
                }
              : null,
        ),
        if (kurangIzin)
          ListTile(
            dense: true,
            leading: const SizedBox(
              width: 34,
              child: Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.deadline),
            ),
            title: const Text(
              'Izin "Alarm & pengingat" belum diberikan',
              style: TextStyle(fontSize: 13, color: AppColors.deadline),
            ),
            subtitle: const Text(
              'Sampai diizinkan, alarmnya tetap mode biasa. Ketuk untuk membuka setelan.',
              style: TextStyle(fontSize: 11.5),
            ),
            onTap: () => ref.read(notificationServiceProvider).mintaIzinAlarmTepat(),
          ),
      ],
    );
  }
}

class _NotificationSettingsCard extends ConsumerWidget {
  const _NotificationSettingsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(notificationServiceProvider);
    final settings = ref.watch(notificationSettingsProvider);
    final controller = ref.read(notificationSettingsProvider.notifier);
    final colorScheme = Theme.of(context).colorScheme;

    if (!service.supported) {
      return Card(
        child: ListTile(
          leading: Icon(Icons.notifications_off_outlined, color: colorScheme.onSurfaceVariant),
          title: const Text('Tidak tersedia di web'),
          subtitle: const Text('Pengingat deadline hanya berjalan di aplikasi Android/iOS'),
        ),
      );
    }

    return Card(
      child: Column(
        children: [
          SwitchListTile(
            secondary: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.profile.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.alarm, size: 18, color: AppColors.profile),
            ),
            title: const Text('Pengingat', style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: const Text('Saklar utama untuk semua jenis di bawah'),
            activeThumbColor: AppColors.profile,
            value: settings.aktif,
            onChanged: (value) async {
              final hasil = await controller.setAktif(value);
              if (!context.mounted) return;
              // Izin ditolak: beri tahu, karena switch-nya akan kembali mati.
              if (value && !hasil) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Izin notifikasi ditolak. Aktifkan lewat setelan HP.'),
                  ),
                );
              }
            },
          ),
          const Divider(height: 1),
          ListTile(
            enabled: settings.aktif,
            leading: const SizedBox(width: 34, child: Icon(Icons.schedule, size: 18)),
            title: const Text('Jam pengingat'),
            subtitle: const Text('Untuk deadline tugas dan tagihan rutin'),
            trailing: Text(
              settings.jam.format(context),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            onTap: () async {
              final picked = await showTimePicker(context: context, initialTime: settings.jam);
              if (picked != null) await controller.setJam(picked);
            },
          ),
          const Divider(height: 1),
          _SaklarTepatWaktu(settings: settings),
          const Divider(height: 1),
          for (final kind in ReminderKind.values)
            SwitchListTile(
              secondary: SizedBox(width: 34, child: Icon(kind.icon, size: 18)),
              title: Text(kind.label, style: const TextStyle(fontSize: 14)),
              subtitle: Text(
                _kapanBerbunyi(kind, settings),
                style: const TextStyle(fontSize: 11.5),
              ),
              dense: true,
              activeThumbColor: AppColors.profile,
              value: settings.jenisAktif.contains(kind),
              // Saklar utama mati berarti tidak ada yang akan berbunyi apa pun
              // pilihannya di sini — jadi jangan biarkan diubah dan menjanjikan
              // sesuatu yang tidak terjadi.
              onChanged: settings.aktif ? (value) => controller.setJenis(kind, value) : null,
            ),
          if (settings.jenisAktif.contains(ReminderKind.kelas)) ...[
            const Divider(height: 1),
            ListTile(
              enabled: settings.aktif,
              leading: const SizedBox(width: 34, child: Icon(Icons.timer_outlined, size: 18)),
              title: const Text('Jeda sebelum kelas', style: TextStyle(fontSize: 14)),
              dense: true,
              trailing: Text(
                '${settings.menitSebelumKelas} menit',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              onTap: () async {
                final picked = await showDialog<int>(
                  context: context,
                  builder: (context) => SimpleDialog(
                    title: const Text('Ingatkan berapa menit sebelumnya?'),
                    children: [
                      for (final menit in const [10, 15, 30, 45, 60])
                        SimpleDialogOption(
                          onPressed: () => Navigator.pop(context, menit),
                          child: Text('$menit menit'),
                        ),
                    ],
                  ),
                );
                if (picked != null) await controller.setMenitSebelumKelas(picked);
              },
            ),
          ],
          const Divider(height: 1),
          ListTile(
            leading: const SizedBox(width: 34, child: Icon(Icons.send_outlined, size: 18)),
            title: const Text('Tes notifikasi'),
            subtitle: const Text('Kirim satu notifikasi sekarang'),
            onTap: () async {
              // Tanpa izin, show() gagal diam-diam di Android 13+.
              final granted = await service.requestPermission();
              if (!context.mounted) return;
              if (!granted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Izin notifikasi belum diberikan.')));
                return;
              }
              await service.showTestNotification();
            },
          ),
        ],
      ),
    );
  }

  /// Kapan tiap jenis benar-benar berbunyi — supaya saklarnya bisa dipilih
  /// tanpa harus menyalakannya dulu dan menunggu semalam untuk tahu.
  static String _kapanBerbunyi(ReminderKind kind, NotificationSettings settings) => switch (kind) {
    ReminderKind.deadline => 'H-7, H-3, H-1, dan hari-H',
    ReminderKind.kelas => '${settings.menitSebelumKelas} menit sebelum kelas dimulai',
    ReminderKind.streak => 'Jam 19.00, kalau hari itu belum ada gerakan',
    ReminderKind.tagihan => 'Sehari sebelum jatuh tempo',
    ReminderKind.dokumen => 'H-60, H-14, dan hari-H sebelum masa berlaku habis',
    ReminderKind.kendaraan => 'Pajak H-30, plat H-60, servis H-7',
    ReminderKind.catatMakan => 'Jam 20.30, kalau belum ada catatan makan',
    ReminderKind.berkala => 'H-1 dan hari-H, diulang sampai ditandai selesai',
    ReminderKind.rekapMingguan => 'Minggu jam 19.00: latihan, tidur, dan pengeluaran',
  };
}
