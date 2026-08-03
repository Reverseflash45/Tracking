import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../assistant/domain/preset_answers.dart' show questionCatalog;
import '../../../core/notifications/notification_service.dart';
import '../../../core/notifications/notification_settings_controller.dart';
import '../../../core/notifications/smart_reminders.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/widgets/hero_header.dart';
import '../../../core/widgets/section_header.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/export_repository.dart';
import '../data/profile_repository.dart';
import '../domain/export_file.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  bool _uploadingAvatar = false;
  bool _exporting = false;

  Future<void> _exportData() async {
    setState(() => _exporting = true);
    try {
      final email = ref.read(currentUserProvider)?.email;
      final result = await ref.read(exportRepositoryProvider).buildExport(email: email);
      final fileName = exportFileName(DateTime.now());

      await shareExport(
        json: result.json,
        fileName: fileName,
        subject: 'Cadangan data Tracking',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${result.totalRows} baris data disiapkan')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Gagal menyiapkan cadangan: $e')));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

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
      await ref.read(profileRepositoryProvider).uploadAvatar(
            userId: userId,
            bytes: bytes,
            fileExt: ext,
          );
      ref.invalidate(profileProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Gagal unggah foto: $e')));
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
    final displayName =
        (fullName != null && fullName.trim().isNotEmpty) ? fullName.trim() : 'Mahasiswa';
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';
    final avatarUrl = profile?.avatarUrl;

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
              AppSpacing.md,
              MediaQuery.of(context).padding.top + AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.xl,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: HeroHeader.gradientFor(AppColors.profile),
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
            ),
            child: Column(
              children: [
                GestureDetector(
                  onTap: _uploadingAvatar ? null : _changeAvatar,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CircleAvatar(
                        radius: 44,
                        backgroundColor: Colors.white.withValues(alpha: 0.25),
                        backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                        child: _uploadingAvatar
                            ? const CircularProgressIndicator(color: Colors.white)
                            : (avatarUrl == null
                                ? Text(
                                    initial,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 32,
                                    ),
                                  )
                                : null),
                      ),
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.profile,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  user?.email ?? '-',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13),
                ),
              ],
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
                const SectionHeader(
                  title: 'Koleksi & Pengingat',
                  icon: Icons.inventory_2_outlined,
                  color: AppColors.profile,
                ),
                _MenuTile(
                  icon: Icons.movie_outlined,
                  color: AppColors.watchlist,
                  title: 'Watchlist',
                  subtitle: 'Film, series, anime, buku, dan komik',
                  onTap: () => context.push('/watchlist'),
                ),
                const SizedBox(height: AppSpacing.sm),
                _MenuTile(
                  icon: Icons.two_wheeler,
                  color: AppColors.vehicle,
                  title: 'Kendaraan',
                  subtitle: 'Servis, oli, dan jatuh tempo pajak',
                  onTap: () => context.push('/vehicle'),
                ),
                const SizedBox(height: AppSpacing.sm),
                _MenuTile(
                  icon: Icons.badge_outlined,
                  color: AppColors.document,
                  title: 'Dokumen',
                  subtitle: 'SIM, paspor, BPJS, dan masa berlakunya',
                  onTap: () => context.push('/documents'),
                ),
                const SizedBox(height: AppSpacing.md),
                const SectionHeader(
                  title: 'Rekap',
                  icon: Icons.auto_awesome,
                  color: AppColors.profile,
                ),
                _MenuTile(
                  icon: Icons.auto_awesome,
                  color: AppColors.profile,
                  title: 'Wrapped',
                  subtitle: 'Rekap mingguan, bulanan, dan tahunanmu',
                  onTap: () => context.push('/profile/wrapped'),
                ),
                const SizedBox(height: AppSpacing.sm),
                _MenuTile(
                  icon: Icons.insights,
                  color: AppColors.dashboard,
                  title: 'Pola',
                  subtitle: 'Hubungan antara olahraga dan tugasmu',
                  onTap: () => context.push('/profile/insight'),
                ),
                const SizedBox(height: AppSpacing.sm),
                _MenuTile(
                  icon: Icons.help_outline,
                  color: AppColors.dashboard,
                  title: 'Tanya Data',
                  // Dihitung dari katalog, bukan ditulis manual — angka yang
                  // dipatok akan basi begitu ada pertanyaan baru.
                  subtitle: '${questionCatalog.length} pertanyaan siap pakai '
                      'tentang catatanmu',
                  onTap: () => context.push('/profile/tanya'),
                ),
                const SizedBox(height: AppSpacing.md),
                const SectionHeader(
                  title: 'Data',
                  icon: Icons.backup_outlined,
                  color: AppColors.profile,
                ),
                _MenuTile(
                  icon: Icons.download_outlined,
                  color: AppColors.profile,
                  title: _exporting ? 'Menyiapkan...' : 'Export Data',
                  subtitle: 'Simpan seluruh datamu sebagai satu berkas JSON',
                  busy: _exporting,
                  onTap: _exporting ? null : _exportData,
                ),
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
    this.busy = false,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          // Padding sendiri, bukan ListTile: subjudul dua baris di ListTile
          // menempel ke tepi kartu dan bikin sesak.
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 14,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: busy
                    ? SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: color),
                      )
                    : Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        height: 1.2,
                      ),
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
              if (!busy) ...[
                const SizedBox(width: AppSpacing.sm),
                Icon(Icons.chevron_right, size: 20, color: colorScheme.onSurfaceVariant),
              ],
            ],
          ),
        ),
      ),
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
          subtitle: const Text(
            'Pengingat deadline hanya berjalan di aplikasi Android/iOS',
          ),
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
            title: const Text(
              'Pengingat',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
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
              final picked = await showTimePicker(
                context: context,
                initialTime: settings.jam,
              );
              if (picked != null) await controller.setJam(picked);
            },
          ),
          const Divider(height: 1),
          for (final kind in ReminderKind.values)
            SwitchListTile(
              secondary: SizedBox(width: 34, child: Icon(kind.icon, size: 18)),
              title: Text(kind.label, style: const TextStyle(fontSize: 14)),
              subtitle: Text(_kapanBerbunyi(kind, settings), style: const TextStyle(fontSize: 11.5)),
              dense: true,
              activeThumbColor: AppColors.profile,
              value: settings.jenisAktif.contains(kind),
              // Saklar utama mati berarti tidak ada yang akan berbunyi apa pun
              // pilihannya di sini — jadi jangan biarkan diubah dan menjanjikan
              // sesuatu yang tidak terjadi.
              onChanged:
                  settings.aktif ? (value) => controller.setJenis(kind, value) : null,
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
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Izin notifikasi belum diberikan.')),
                );
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
  static String _kapanBerbunyi(ReminderKind kind, NotificationSettings settings) =>
      switch (kind) {
        ReminderKind.deadline => 'H-7, H-3, H-1, dan hari-H',
        ReminderKind.kelas => '${settings.menitSebelumKelas} menit sebelum kelas dimulai',
        ReminderKind.streak => 'Jam 19.00, kalau hari itu belum ada gerakan',
        ReminderKind.tagihan => 'Sehari sebelum jatuh tempo',
        ReminderKind.dokumen => 'H-60, H-14, dan hari-H sebelum masa berlaku habis',
        ReminderKind.kendaraan => 'Pajak H-30, plat H-60, servis H-7',
        ReminderKind.catatMakan => 'Jam 20.30, kalau belum ada catatan makan',
      };
}
