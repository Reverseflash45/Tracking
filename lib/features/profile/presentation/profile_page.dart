import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/notifications/notification_service.dart';
import '../../../core/notifications/notification_settings_controller.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/widgets/hero_header.dart';
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
                  title: 'Rekap',
                  icon: Icons.auto_awesome,
                  color: AppColors.profile,
                ),
                Card(
                  child: ListTile(
                    onTap: () => context.push('/profile/wrapped'),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.profile.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.auto_awesome, size: 18, color: AppColors.profile),
                    ),
                    title: const Text(
                      'Wrapped',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: const Text('Rekap mingguan, bulanan, dan tahunanmu'),
                    trailing: const Icon(Icons.chevron_right),
                  ),
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
              'Pengingat deadline',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: const Text('Diingatkan H-7, H-3, H-1, dan hari-H'),
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
}
