import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/ocr/text_scanner.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/daftar_bergaris.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/hero_header.dart';
import '../../../core/widgets/section_header.dart';
import '../data/finance_repository.dart';
import '../domain/finance_stats.dart';
import '../domain/receipt_parser.dart';
import '../domain/transaction.dart';
import 'transaction_sheet.dart';

const _color = AppColors.finance;
final _dayFormat = DateFormat('d MMM', 'id_ID');
final _rangeFormat = DateFormat('d MMM', 'id_ID');

class FinancePage extends ConsumerWidget {
  const FinancePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(financeSummaryProvider);
    final transactions =
        ref.watch(transactionsProvider).value ?? const <Transaction>[];
    final summary = summaryAsync.value;

    return Scaffold(
      floatingActionButton: _FabMenu(
        onManual: () => showTransactionSheet(context),
        onScan: () => _scanReceipt(context, ref),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(transactionsProvider);
          ref.invalidate(financeSettingsProvider);
        },
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            HeroHeader(
              title: 'Keuangan',
              subtitle: summary == null
                  ? 'Memuat...'
                  : '${_rangeFormat.format(summary.start)} - '
                        '${_rangeFormat.format(summary.end)}',
              color: _color,
              // Tanpa tombol kembali: ini akar tab, bukan halaman yang dibuka
              // dari halaman lain.
              trailing: HeroIconButton(
                icon: Icons.tune,
                tooltip: 'Atur anggaran',
                onPressed: () => _showBudgetSheet(context, ref),
              ),
              stats: [
                HeroStatData(
                  icon: Icons.arrow_downward,
                  value: formatRupiahRingkas(summary?.pemasukan ?? 0),
                  label: 'Masuk',
                ),
                HeroStatData(
                  icon: Icons.arrow_upward,
                  value: formatRupiahRingkas(summary?.pengeluaran ?? 0),
                  label: 'Keluar',
                ),
                HeroStatData(
                  icon: Icons.account_balance_wallet_outlined,
                  value: formatRupiahRingkas(summary?.selisih ?? 0),
                  label: 'Selisih',
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.md,
                96,
              ),
              child: summaryAsync.when(
                data: (s) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _BudgetCard(
                      summary: s,
                      onSetup: () => _showBudgetSheet(context, ref),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Card(
                      margin: EdgeInsets.zero,
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        onTap: () => context.push('/finance/recurring'),
                        dense: true,
                        leading: Icon(
                          Icons.event_repeat,
                          size: 20,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        title: const Text(
                          'Pengeluaran rutin',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: const Text(
                          'Kos, internet, langganan — disisihkan dari jatah harian',
                          style: TextStyle(fontSize: 12),
                        ),
                        trailing: const Icon(Icons.chevron_right, size: 20),
                      ),
                    ),
                    if (s.perKategori.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.lg),
                      const SectionHeader(
                        title: 'Ke mana uangnya',
                        icon: Icons.pie_chart_outline,
                        color: _color,
                      ),
                      _CategoryBreakdown(summary: s),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    const SectionHeader(
                      title: 'Riwayat',
                      icon: Icons.receipt_long_outlined,
                      color: _color,
                    ),
                    if (transactions.isEmpty)
                      EmptyState(
                        icon: Icons.savings_outlined,
                        title: 'Belum ada catatan',
                        subtitle: textScanSupported
                            ? 'Tekan + untuk mencatat, atau foto struknya langsung'
                            : 'Tekan + untuk mencatat pengeluaran pertamamu',
                        color: _color,
                      )
                    else
                      DaftarBergaris(
                        indentGaris: 56,
                        children: [
                          for (final tx in transactions) _TxTile(tx: tx),
                        ],
                      ),
                  ],
                ),
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, _) => EmptyState(
                  icon: Icons.error_outline,
                  title: 'Gagal memuat',
                  subtitle: '$error',
                  color: _color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _scanReceipt(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);

    final sumber = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined, color: _color),
              title: const Text('Foto struk sekarang'),
              onTap: () => Navigator.pop(context, true),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: _color),
              title: const Text('Pilih dari galeri'),
              onTap: () => Navigator.pop(context, false),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
    if (sumber == null || !context.mounted) return;

    final hasil = await scanTextFromPhoto(fromCamera: sumber);
    if (!context.mounted) return;

    if (hasil.gagal) {
      // Membatalkan pilihan foto bukan error; jangan diteriaki.
      if (hasil.error != 'Batal') {
        messenger.showSnackBar(SnackBar(content: Text(hasil.error!)));
      }
      return;
    }

    // Tebakannya selalu lewat form dulu, tidak pernah langsung tersimpan.
    await showTransactionSheet(context, guess: parseReceipt(hasil.text));
  }

  Future<void> _showBudgetSheet(BuildContext context, WidgetRef ref) async {
    final current =
        ref.read(financeSettingsProvider).value ?? const FinanceSettings();
    final budgetController = TextEditingController(
      text: current.monthlyBudget == null
          ? ''
          : current.monthlyBudget!.round().toString(),
    );
    var payday = current.paydayDay;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            MediaQuery.of(context).viewInsets.bottom + AppSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Atur Anggaran',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: budgetController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Anggaran per bulan',
                  prefixText: 'Rp ',
                  helperText: 'Dipakai menghitung jatah harianmu',
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Tanggal uang bulanan datang',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Kalau kirimanmu datang tanggal 5, periode anggaranmu dihitung '
                'dari tanggal 5 ke tanggal 4 — bukan per tanggal 1.',
                style: TextStyle(
                  fontSize: 11,
                  height: 1.4,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ChoiceChip(
                    label: const Text('Tanggal 1'),
                    selected: payday == null,
                    onSelected: (_) => setSheetState(() => payday = null),
                  ),
                  for (final day in [5, 10, 15, 20, 25])
                    ChoiceChip(
                      label: Text('$day'),
                      selected: payday == day,
                      onSelected: (_) => setSheetState(() => payday = day),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: () async {
                  final userId = ref.read(currentUserProvider)?.id;
                  if (userId == null) return;

                  await ref
                      .read(financeRepositoryProvider)
                      .saveSettings(
                        userId,
                        FinanceSettings(
                          monthlyBudget: parseRupiah(budgetController.text),
                          paydayDay: payday,
                        ),
                      );
                  ref.invalidate(financeSettingsProvider);
                  if (context.mounted) Navigator.pop(context);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: _color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Simpan'),
              ),
            ],
          ),
        ),
      ),
    );

    budgetController.dispose();
  }
}

/// Tombol tambah dengan dua pilihan. Foto struk ditaruh di sini, bukan di
/// dalam form, supaya jadi jalur pertama — bukan opsi tersembunyi.
class _FabMenu extends StatelessWidget {
  const _FabMenu({required this.onManual, required this.onScan});

  final VoidCallback onManual;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (textScanSupported) ...[
          FloatingActionButton.small(
            heroTag: 'scan',
            onPressed: onScan,
            backgroundColor: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest,
            tooltip: 'Foto struk',
            child: const Icon(Icons.document_scanner_outlined),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        FloatingActionButton.extended(
          heroTag: 'manual',
          onPressed: onManual,
          icon: const Icon(Icons.add),
          label: const Text('Catat'),
        ),
      ],
    );
  }
}

class _BudgetCard extends StatelessWidget {
  const _BudgetCard({required this.summary, required this.onSetup});

  final FinanceSummary summary;
  final VoidCallback onSetup;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final jatah = summary.jatahHarian;

    if (jatah == null) {
      return Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          onTap: onSetup,
          leading: Icon(
            Icons.savings_outlined,
            color: colorScheme.onSurfaceVariant,
          ),
          title: const Text(
            'Atur anggaran bulanan',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          subtitle: const Text(
            'Supaya app bisa hitung jatah harianmu',
            style: TextStyle(fontSize: 12),
          ),
          trailing: const Icon(Icons.chevron_right),
        ),
      );
    }

    final persen = summary.persenTerpakai ?? 0;
    final kebobolan = (summary.sisaBudget ?? 0) <= 0;
    // Warna hanya muncul saat ada yang perlu diperhatikan. Hijau untuk
    // "aman" dulu membuat layar selalu berwarna, sehingga merah saat
    // kebobolan tidak lagi terasa berbeda.
    final warna = kebobolan
        ? AppColors.priorityHigh
        : (persen > 80 ? AppColors.priorityMedium : colorScheme.onSurface);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      kebobolan ? 'Lewat anggaran' : 'Jatah per hari',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      kebobolan
                          ? formatRupiah(summary.sisaBudget!.abs())
                          : formatRupiah(jatah),
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: warna,
                        height: 1.1,
                        letterSpacing: -0.8,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${summary.sisaHari} hari lagi',
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      // Saat lewat anggaran, "sisa" yang negatif cuma
                      // mengulang angka besar di kiri; yang berguna justru
                      // patokannya.
                      kebobolan
                          ? 'Anggaran ${formatRupiahRingkas(summary.budget!)}'
                          : 'Sisa ${formatRupiahRingkas(summary.sisaBudget ?? 0)}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            LinearProgressIndicator(
              value: (persen / 100).clamp(0, 1),
              minHeight: 6,
              color: warna,
            ),
            const SizedBox(height: 6),
            Text(
              '${formatRupiah(summary.pengeluaran)} dari '
              '${formatRupiah(summary.budget!)} terpakai (${persen.round()}%)',
              style: TextStyle(
                fontSize: 11,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            // Uang yang sudah dipesan harus disebut, bukan cuma diam-diam
            // dipotong dari jatah harian — kalau tidak, angkanya terlihat
            // terlalu kecil tanpa sebab yang jelas.
            if (summary.rutinBelumJatuhTempo > 0) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.lock_clock,
                    size: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      '${formatRupiah(summary.rutinBelumJatuhTempo)} disisihkan '
                      'untuk tagihan rutin yang belum jatuh tempo',
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.35,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CategoryBreakdown extends StatelessWidget {
  const _CategoryBreakdown({required this.summary});

  final FinanceSummary summary;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final terbesar = summary.perKategori.first.total;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Column(
          children: [
            for (final item in summary.perKategori)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: 7,
                ),
                child: Row(
                  children: [
                    Icon(
                      item.category.icon,
                      size: 17,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 112,
                      child: Text(
                        item.category.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Expanded(
                      child: LinearProgressIndicator(
                        value: terbesar == 0 ? 0 : item.total / terbesar,
                        minHeight: 5,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      formatRupiahRingkas(item.total),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TxTile extends ConsumerWidget {
  const _TxTile({required this.tx});

  final Transaction tx;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final masuk = tx.kind == TxKind.pemasukan;

    return Dismissible(
      key: ValueKey(tx.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: colorScheme.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Icon(Icons.delete_outline, color: colorScheme.onErrorContainer),
      ),
      confirmDismiss: (_) => showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Hapus catatan?'),
          content: Text('${formatRupiah(tx.amount)} akan dihapus.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Hapus'),
            ),
          ],
        ),
      ),
      onDismissed: (_) async {
        await ref.read(financeRepositoryProvider).deleteTransaction(tx.id);
        ref.invalidate(transactionsProvider);
      },
      child: ListTile(
        onTap: () => showTransactionSheet(context, existing: tx),
        leading: SizedBox(
          width: 24,
          child: Icon(
            tx.category.icon,
            size: 20,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        horizontalTitleGap: 16,
        minVerticalPadding: 10,
        title: Row(
          children: [
            // Nama produk paling depan kalau ada — "Martabak telor" lebih
            // memberi tahu daripada "ShopeeFood" waktu menyisir riwayat.
            Flexible(
              child: Text(
                tx.product?.isNotEmpty == true
                    ? tx.product!
                    : (tx.merchant?.isNotEmpty == true
                          ? tx.merchant!
                          : tx.category.label),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
            if (tx.placeKind != null) ...[
              const SizedBox(width: 5),
              Icon(
                tx.placeKind!.icon,
                size: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
            // Catatan hasil OCR ditandai: angkanya lebih mungkin meleset
            // daripada yang kamu ketik sendiri.
            if (tx.fromReceipt) ...[
              const SizedBox(width: 5),
              Icon(
                Icons.document_scanner_outlined,
                size: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ],
        ),
        subtitle: Text(
          [
            _dayFormat.format(tx.occurredOn),
            // Nama toko turun ke baris kedua kalau judulnya sudah dipakai
            // nama produk, supaya keduanya tetap terbaca.
            if (tx.product?.isNotEmpty == true &&
                tx.merchant?.isNotEmpty == true)
              tx.merchant!,
            if (tx.note?.isNotEmpty == true) tx.note!,
          ].join(' · '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
        ),
        trailing: Text(
          '${masuk ? '+' : '-'}${formatRupiahRingkas(tx.amount)}',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            fontFeatures: const [FontFeature.tabularFigures()],
            color: masuk ? AppColors.statusDone : colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}
