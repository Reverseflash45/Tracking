// Sapaan di puncak Beranda: salam, tanggal, dan foto profil.
part of 'dashboard_page.dart';

/// Tanggal, sapaan, dan satu kalimat yang merangkum hari ini — bukan tiga
/// angka tanpa konteks.
class _Sapaan extends ConsumerWidget {
  const _Sapaan();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final user = ref.watch(currentUserProvider);
    final profile = ref.watch(profileProvider).value;
    final fullName = profile?.fullName;
    final nama = (fullName != null && fullName.trim().isNotEmpty)
        ? fullName.trim().split(' ').first
        : (user?.email?.split('@').first ?? 'Mahasiswa');
    final avatarUrl = profile?.avatarUrl;

    final jam = DateTime.now().hour;
    final salam = jam < 11
        ? 'Selamat pagi'
        : jam < 15
        ? 'Selamat siang'
        : jam < 19
        ? 'Selamat sore'
        : 'Selamat malam';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _dayFormat.format(DateTime.now()),
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  '$salam, $nama',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 26,
                    height: 1.15,
                    letterSpacing: -0.8,
                  ),
                ),
              ),
            ],
          ),
        ),
        HeroIconButton(
          icon: Icons.search,
          tooltip: 'Cari',
          onPressed: () => context.push('/search'),
        ),
        const SizedBox(width: 2),
        Semantics(
          button: true,
          label: 'Buka profil',
          child: InkWell(
            onTap: () => context.push('/profile'),
            customBorder: const CircleBorder(),
            child: CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.dashboard,
              backgroundImage: avatarUrl != null
                  ? NetworkImage(avatarUrl)
                  : null,
              child: avatarUrl == null
                  ? Text(
                      nama.isNotEmpty ? nama[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    )
                  : null,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Kartu sorotan: satu hal terpenting sekarang
// ---------------------------------------------------------------------------

enum _JenisSorotan { berlangsung, berikutnya, tenggat, bebas }
