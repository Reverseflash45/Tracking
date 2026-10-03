// Pintasan ke fitur lain, pencapaian, dan lembar catat cepat.
part of 'dashboard_page.dart';

/// Pintasan ke fitur yang paling sering dibuka, sebagai deretan ubin berwarna
/// yang bisa digeser — seperti pintasan di aplikasi dompet atau ojek daring.
/// Daftar lengkapnya ada di tab Lainnya; "Semua" di judulnya membawa ke sana.
class _PintasanLainnya extends StatelessWidget {
  const _PintasanLainnya();

  static const _isi = [
    MenuItemData(
      icon: Icons.account_balance_wallet_rounded,
      label: 'Keuangan',
      rute: '/finance',
      warna: AppColors.finance,
    ),
    MenuItemData(
      icon: Icons.schedule_rounded,
      label: 'Rutinitas',
      rute: '/routine',
      warna: AppColors.dashboard,
    ),
    MenuItemData(
      icon: Icons.event_repeat_rounded,
      label: 'Berkala',
      rute: '/routine/berkala',
      warna: AppColors.dashboard,
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
    MenuItemData(
      icon: Icons.favorite_rounded,
      label: 'Wishlist',
      rute: '/wishlist',
      warna: AppColors.finance,
    ),
    MenuItemData(
      icon: Icons.movie_rounded,
      label: 'Watchlist',
      rute: '/watchlist',
      warna: AppColors.watchlist,
    ),
    MenuItemData(
      icon: Icons.two_wheeler_rounded,
      label: 'Kendaraan',
      rute: '/vehicle',
      warna: AppColors.vehicle,
    ),
    MenuItemData(
      icon: Icons.badge_rounded,
      label: 'Dokumen',
      rute: '/documents',
      warna: AppColors.document,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: _isi.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final item = _isi[i];
          final warna = item.warna ?? AppColors.dashboard;
          return Material(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(18),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => context.push(item.rute),
              child: Container(
                width: 84,
                decoration: BoxDecoration(
                  border: Border.all(color: colorScheme.outlineVariant),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: warna.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(item.icon, color: warna, size: 22),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Lencana
// ---------------------------------------------------------------------------

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
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          for (final achievement in achievements)
            Chip(
              avatar: Icon(
                achievement.icon,
                size: 18,
                color: AppColors.workout,
              ),
              label: Text(achievement.label),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Catat cepat
// ---------------------------------------------------------------------------

/// Satu pintu untuk empat catatan yang paling sering: tidak perlu pindah tab
/// dulu hanya untuk mencatat jajan atau tugas yang baru diumumkan dosen.
Future<void> _bukaCatatCepat(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheet) {
      Future<void> pilih(Future<void> Function() aksi) async {
        Navigator.pop(sheet);
        await aksi();
      }

      final isi = [
        (
          'Tugas',
          'Tenggat baru',
          Icons.assignment_rounded,
          AppColors.deadline,
          () => pilih(() async {
            await context.push('/academic/tasks/new');
            ref.invalidate(tasksProvider);
          }),
        ),
        (
          'Pengeluaran',
          'Jajan, ongkos, tagihan',
          Icons.payments_rounded,
          AppColors.finance,
          () => pilih(() => showTransactionSheet(context)),
        ),
        (
          'Makan',
          'Kalori & makro',
          Icons.restaurant_rounded,
          _warnaAsupan,
          () => pilih(() => showFoodFormSheet(context)),
        ),
        (
          'Latihan',
          'Sesi workout',
          Icons.fitness_center_rounded,
          AppColors.workout,
          () => pilih(() async {
            await context.push('/workout/new');
            ref.invalidate(workoutSessionsProvider);
          }),
        ),
      ];

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 4, bottom: 12),
                child: Text(
                  'Catat cepat',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                ),
              ),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.55,
                children: [
                  for (final (judul, sub, ikon, warna, aksi) in isi)
                    Material(
                      color: warna.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(18),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: aksi,
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: warna,
                                  borderRadius: BorderRadius.circular(11),
                                ),
                                child: Icon(
                                  ikon,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                judul,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                sub,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(
                                    sheet,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}
