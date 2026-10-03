// Kartu uang: sisa anggaran dan jatah harian.
part of 'dashboard_page.dart';

/// Yang ditonjolkan jatah harian, bukan total pengeluaran — "boleh habis
/// berapa hari ini" lebih menentukan keputusanmu siang ini.
class _KartuUang extends ConsumerWidget {
  const _KartuUang();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final summaryAsync = ref.watch(financeSummaryProvider);

    return summaryAsync.when(
      data: (summary) {
        final jatah = summary.jatahHarian;
        final budget = summary.budget;
        if (jatah == null || budget == null || budget <= 0) {
          return _KartuKosong(
            ikon: Icons.account_balance_wallet_outlined,
            teks: summary.kosong
                ? 'Belum ada catatan keuangan.'
                : 'Keluar ${formatRupiah(summary.pengeluaran)} periode ini.',
          );
        }
        final kebobolan = (summary.sisaBudget ?? 0) <= 0;
        final rasio = (summary.pengeluaran / budget).clamp(0.0, 1.0);
        final warna = kebobolan
            ? AppColors.priorityHigh
            : rasio > 0.8
            ? AppColors.priorityMedium
            : AppColors.finance;

        return Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => context.push('/finance'),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              kebobolan ? 'Lewat anggaran' : 'Jatah hari ini',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 2),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                formatRupiah(
                                  kebobolan ? summary.sisaBudget!.abs() : jatah,
                                ),
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.8,
                                  color: kebobolan
                                      ? warna
                                      : colorScheme.onSurface,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: warna.withValues(alpha: 0.14),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.account_balance_wallet_rounded,
                          color: warna,
                          size: 21,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: rasio,
                      minHeight: 8,
                      color: warna,
                      backgroundColor: warna.withValues(alpha: 0.15),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        '${formatRupiahRingkas(summary.pengeluaran)} dari '
                        '${formatRupiahRingkas(budget)}',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${summary.sisaHari} hari lagi',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => const SizedBox(
        height: 60,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (error, _) => const _KartuKosong(
        ikon: Icons.error_outline,
        teks: 'Gagal memuat keuangan.',
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pintasan
// ---------------------------------------------------------------------------
