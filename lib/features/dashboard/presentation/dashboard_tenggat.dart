// Rutinitas berkala yang jatuh tempo dan daftar tenggat tugas.
part of 'dashboard_page.dart';

/// Rutinitas berkala yang jatuh tempo hari ini atau sudah telat, lengkap
/// dengan tombol "Sudah". Tidak tampil sama sekali kalau tidak ada — Beranda
/// tidak perlu satu kartu lagi yang bilang "semua aman".
class _BerkalaJatuhTempo extends ConsumerWidget {
  const _BerkalaJatuhTempo();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final perlu = [
      for (final r in ref.watch(berkalaProvider).value ?? const <RutinitasBerkala>[])
        if (r.perluDikerjakan(now)) r,
    ];
    if (perlu.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, item) in perlu.take(3).indexed) ...[
            if (i > 0) const SizedBox(height: AppSpacing.sm),
            KartuBerkala(
              item: item,
              onTap: () => context.push('/routine/berkala'),
              onSelesai: () => tandaiBerkalaSelesai(context, item),
            ),
          ],
          if (perlu.length > 3)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => context.push('/routine/berkala'),
                child: Text('${perlu.length - 3} lainnya'),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tenggat
// ---------------------------------------------------------------------------

/// Empat tenggat terdekat. Tanggalnya jadi blok di kiri seperti kalender
/// meja; yang mepet (hari ini, besok, atau lewat) diwarnai koral.
class _DaftarTenggat extends ConsumerWidget {
  const _DaftarTenggat();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tugasAsync = ref.watch(tasksProvider);
    return tugasAsync.when(
      data: (semua) {
        final belum = semua.where((t) => !t.isDone).toList()
          ..sort((a, b) => a.deadline.compareTo(b.deadline));
        if (belum.isEmpty) {
          return const _KartuKosong(
            ikon: Icons.celebration_outlined,
            teks: 'Semua tugas beres. Nikmati waktumu.',
          );
        }
        return Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (final (i, t) in belum.take(4).indexed) ...[
                if (i > 0) const Divider(height: 1, indent: 72),
                _BarisTenggat(t),
              ],
            ],
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: LinearProgressIndicator(),
      ),
      error: (error, _) => const _KartuKosong(
        ikon: Icons.error_outline,
        teks: 'Tugas gagal dimuat.',
      ),
    );
  }
}

class _BarisTenggat extends StatelessWidget {
  const _BarisTenggat(this.t);

  final AcademicTask t;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final sekarang = DateTime.now();
    final hari = DateTime(
      t.deadline.year,
      t.deadline.month,
      t.deadline.day,
    ).difference(DateTime(sekarang.year, sekarang.month, sekarang.day)).inDays;
    final telat = t.tenggatLokal.isBefore(sekarang);
    final mepet = telat || hari <= 1;
    final kapan = telat
        ? 'Terlambat'
        : hari == 0
        ? 'Hari ini ${DateFormat('HH.mm').format(t.deadline)}'
        : hari == 1
        ? 'Besok'
        : '$hari hari lagi';

    final warnaBlok = mepet ? AppColors.deadline : colorScheme.onSurface;

    return InkWell(
      onTap: () => context.push('/academic/tasks/${t.id}'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 48,
              decoration: BoxDecoration(
                color: mepet
                    ? AppColors.deadline.withValues(alpha: 0.12)
                    : colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('MMM', 'id_ID').format(t.deadline).toUpperCase(),
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      color: warnaBlok,
                    ),
                  ),
                  Text(
                    '${t.deadline.day}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                      color: warnaBlok,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    t.courseName ?? 'Tugas pribadi',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              kapan,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: mepet
                    ? AppColors.deadline
                    : colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
