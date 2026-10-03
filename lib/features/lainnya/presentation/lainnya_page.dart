import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/hero_header.dart';
import '../../../core/widgets/menu_list.dart';
import '../../../core/widgets/section_header.dart';
import '../../profile/data/profile_repository.dart';

/// Tab Lainnya: profil di atas, lalu semua fitur yang tidak punya tab sendiri.
///
/// Dikelompokkan menurut apa yang sedang kamu urus, bukan menurut abjad —
/// orang yang mencari "Tagihan rutin" berpikir soal uang, bukan soal huruf T.
class LainnyaPage extends StatelessWidget {
  const LainnyaPage({super.key});

  static const _uang = [
    MenuItemData(
      icon: Icons.account_balance_wallet_rounded,
      label: 'Keuangan',
      rute: '/finance',
      warna: AppColors.finance,
      keterangan: 'Pemasukan, pengeluaran, anggaran bulanan',
    ),
    MenuItemData(
      icon: Icons.event_repeat_rounded,
      label: 'Tagihan rutin',
      rute: '/finance/recurring',
      warna: AppColors.finance,
    ),
    MenuItemData(
      icon: Icons.favorite_rounded,
      label: 'Wishlist',
      rute: '/wishlist',
      warna: AppColors.watchlist,
    ),
  ];

  static const _hidup = [
    MenuItemData(
      icon: Icons.schedule_rounded,
      label: 'Rutinitas',
      rute: '/routine',
      warna: AppColors.dashboard,
      keterangan: 'Jadwal harianmu di luar kuliah',
    ),
    MenuItemData(
      icon: Icons.restart_alt_rounded,
      label: 'Rutinitas berkala',
      rute: '/routine/berkala',
      warna: AppColors.dashboard,
      keterangan: 'Absen akun, ganti sprei — tiap beberapa hari',
    ),
    MenuItemData(
      icon: Icons.monitor_heart_rounded,
      label: 'Kesehatan',
      rute: '/kesehatan',
      warna: AppColors.workout,
      keterangan: 'Langkah, tidur, dan detak dari jam tangan',
    ),
    MenuItemData(
      icon: Icons.sticky_note_2_rounded,
      label: 'Catatan',
      rute: '/notes',
      warna: AppColors.note,
    ),
    MenuItemData(
      icon: Icons.flag_rounded,
      label: 'Target',
      rute: '/goals',
      warna: AppColors.deadline,
    ),
  ];

  static const _barang = [
    MenuItemData(
      icon: Icons.two_wheeler_rounded,
      label: 'Kendaraan',
      rute: '/vehicle',
      warna: AppColors.vehicle,
      keterangan: 'Servis, pajak, dan odometer',
    ),
    MenuItemData(
      icon: Icons.badge_rounded,
      label: 'Dokumen',
      rute: '/documents',
      warna: AppColors.document,
      keterangan: 'KTP, SIM, paspor, dan masa berlakunya',
    ),
    MenuItemData(
      icon: Icons.movie_rounded,
      label: 'Watchlist',
      rute: '/watchlist',
      warna: AppColors.watchlist,
    ),
  ];

  static const _rekap = [
    MenuItemData(
      icon: Icons.auto_awesome,
      label: 'Wrapped',
      rute: '/profile/wrapped',
      warna: AppColors.profile,
      keterangan: 'Rekap mingguan, bulanan, dan tahunanmu',
    ),
    MenuItemData(
      icon: Icons.insights,
      label: 'Pola',
      rute: '/profile/insight',
      warna: AppColors.dashboard,
      keterangan: 'Hubungan antara olahraga dan tugasmu',
    ),
    MenuItemData(
      icon: Icons.help_outline,
      label: 'Tanya data',
      rute: '/profile/tanya',
      warna: AppColors.dashboard,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: const [
          HeroHeader(
            title: 'Lainnya',
            subtitle: 'Profil dan semua fitur lainnya',
            color: AppColors.lainnya,
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _KartuProfil(),
                SizedBox(height: AppSpacing.md),
                SectionHeader(
                  title: 'Uang',
                  icon: Icons.payments_outlined,
                  color: AppColors.finance,
                ),
                MenuList(items: _uang),
                SizedBox(height: AppSpacing.md),
                SectionHeader(
                  title: 'Sehari-hari',
                  icon: Icons.wb_sunny_outlined,
                  color: AppColors.dashboard,
                ),
                MenuList(items: _hidup),
                SizedBox(height: AppSpacing.md),
                SectionHeader(
                  title: 'Barang & dokumen',
                  icon: Icons.inventory_2_outlined,
                  color: AppColors.vehicle,
                ),
                MenuList(items: _barang),
                SizedBox(height: AppSpacing.md),
                SectionHeader(
                  title: 'Rekap',
                  icon: Icons.auto_awesome_outlined,
                  color: AppColors.profile,
                ),
                MenuList(items: _rekap),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Kartu identitas. Seluruh kartu membuka Profil — setelan tampilan,
/// notifikasi, dan cadangan data ada di sana.
class _KartuProfil extends ConsumerWidget {
  const _KartuProfil();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final user = ref.watch(currentUserProvider);
    final profile = ref.watch(profileProvider).value;

    final nama = (profile?.fullName?.trim().isNotEmpty ?? false)
        ? profile!.fullName!.trim()
        : 'Mahasiswa';
    final avatarUrl = profile?.avatarUrl;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/profile'),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: AppColors.profile,
                backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                child: avatarUrl == null
                    ? Text(
                        nama[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nama,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16.5),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user?.email ?? '-',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Profil, tampilan, notifikasi, cadangan data',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
