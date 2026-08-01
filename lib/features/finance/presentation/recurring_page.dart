import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/hero_header.dart';
import '../data/finance_repository.dart';
import '../domain/finance_stats.dart';
import '../domain/receipt_parser.dart' show parseRupiah;
import '../domain/transaction.dart';

const _color = AppColors.finance;

/// Daftar pengeluaran yang datang tiap bulan.
///
/// Bukan pencatat otomatis: app tidak akan membuat transaksi sendiri di
/// tanggal jatuh tempo. Yang dilakukan cuma memesan uangnya lebih dulu supaya
/// jatah harianmu tidak menghitung uang kos sebagai uang jajan.
class RecurringPage extends ConsumerWidget {
  const RecurringPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(recurringExpensesProvider).value ?? const <RecurringExpense>[];
    final summary = ref.watch(financeSummaryProvider).value;

    final aktif = items.where((e) => e.active).toList();
    final totalBulanan = aktif.fold<double>(0, (sum, e) => sum + e.amount);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showForm(context, ref),
        backgroundColor: _color,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Tambah'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(recurringExpensesProvider),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            HeroHeader(
              title: 'Pengeluaran Rutin',
              subtitle: 'Kos, internet, langganan',
              color: _color,
              leading: HeroIconButton(
                icon: Icons.arrow_back,
                tooltip: 'Kembali',
                onPressed: () => context.pop(),
              ),
              stats: [
                HeroStatData(
                  icon: Icons.event_repeat,
                  value: '${aktif.length}',
                  label: 'Aktif',
                ),
                HeroStatData(
                  icon: Icons.calendar_month_outlined,
                  value: formatRupiahRingkas(totalBulanan),
                  label: 'Per Bulan',
                ),
                HeroStatData(
                  icon: Icons.lock_clock,
                  value: formatRupiahRingkas(summary?.rutinBelumJatuhTempo ?? 0),
                  label: 'Belum Jatuh Tempo',
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _Penjelasan(),
                  const SizedBox(height: AppSpacing.md),
                  if (items.isEmpty)
                    const EmptyState(
                      icon: Icons.event_repeat,
                      title: 'Belum ada pengeluaran rutin',
                      subtitle: 'Tambahkan kos, internet, atau langganan supaya '
                          'jatah harianmu tidak menghitung uang yang sudah dipesan',
                      color: _color,
                    )
                  else
                    for (final item in items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: _RecurringTile(item: item),
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

class _Penjelasan extends StatelessWidget {
  const _Penjelasan();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, size: 16, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Yang belum lewat tanggalnya dipotong dari jatah harian, jadi '
                'angkanya tidak lagi menghitung uang kos sebagai uang jajan. '
                'App tidak mencatatkan transaksinya sendiri — kamu tetap yang '
                'mencatat waktu benar-benar membayar.',
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.45,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecurringTile extends ConsumerWidget {
  const _RecurringTile({required this.item});

  final RecurringExpense item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        decoration: BoxDecoration(
          color: colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(AppTheme.radius),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Icon(Icons.delete_outline, color: colorScheme.onErrorContainer),
      ),
      onDismissed: (_) async {
        await ref.read(financeRepositoryProvider).deleteRecurring(item.id);
        ref.invalidate(recurringExpensesProvider);
      },
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          onTap: () => _showForm(context, ref, existing: item),
          dense: true,
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _color.withValues(alpha: item.active ? 0.12 : 0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              item.category.icon,
              size: 16,
              color: item.active ? _color : colorScheme.onSurfaceVariant,
            ),
          ),
          title: Text(
            item.name,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              decoration: item.active ? null : TextDecoration.lineThrough,
              color: item.active ? null : colorScheme.onSurfaceVariant,
            ),
          ),
          subtitle: Text(
            'Tiap tanggal ${item.dueDay}  ·  ${item.category.label}'
            '${item.active ? '' : '  ·  nonaktif'}',
            style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
          ),
          trailing: Text(
            formatRupiah(item.amount),
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: item.active ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _showForm(
  BuildContext context,
  WidgetRef ref, {
  RecurringExpense? existing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _RecurringSheet(existing: existing),
  );
}

class _RecurringSheet extends ConsumerStatefulWidget {
  const _RecurringSheet({this.existing});

  final RecurringExpense? existing;

  @override
  ConsumerState<_RecurringSheet> createState() => _RecurringSheetState();
}

class _RecurringSheetState extends ConsumerState<_RecurringSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;

  late TxCategory _category;
  late int _dueDay;
  late bool _active;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _amountController = TextEditingController(
      text: existing == null ? '' : existing.amount.round().toString(),
    );
    _category = existing?.category ?? TxCategory.lainnya;
    _dueDay = existing?.dueDay ?? 1;
    _active = existing?.active ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final userId = ref.read(currentUserProvider)?.id;
    if (userId == null) return;

    setState(() => _saving = true);
    try {
      await ref.read(financeRepositoryProvider).saveRecurring(
            userId,
            RecurringExpense(
              id: widget.existing?.id ?? '',
              name: _nameController.text.trim(),
              amount: parseRupiah(_amountController.text) ?? 0,
              category: _category,
              dueDay: _dueDay,
              active: _active,
            ),
          );
      ref.invalidate(recurringExpensesProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Gagal menyimpan: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final categories = TxCategory.forKind(TxKind.pengeluaran);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        MediaQuery.of(context).viewInsets.bottom + AppSpacing.md,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.existing == null ? 'Pengeluaran Rutin' : 'Edit Pengeluaran Rutin',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _nameController,
                autofocus: widget.existing == null,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nama',
                  hintText: 'Misal: Kos, Internet, Spotify',
                ),
                validator: (value) =>
                    (value == null || value.trim().isEmpty) ? 'Isi namanya' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Nominal per bulan',
                  prefixText: 'Rp ',
                ),
                validator: (value) {
                  final parsed = parseRupiah(value ?? '');
                  if (parsed == null || parsed <= 0) return 'Isi nominalnya';
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Jatuh tempo tiap tanggal',
                style: TextStyle(fontSize: 11.5, color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 6),
              // Dibatasi 28 supaya tidak ada bulan yang kehilangan tanggalnya
              // di Februari.
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (var day = 1; day <= 28; day++)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Center(
                          child: ChoiceChip(
                            label: Text('$day'),
                            selected: _dueDay == day,
                            onSelected: (_) => setState(() => _dueDay = day),
                            visualDensity: VisualDensity.compact,
                            selectedColor: _color.withValues(alpha: 0.18),
                            labelStyle: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: _dueDay == day ? _color : colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final category in categories)
                    ChoiceChip(
                      avatar: Icon(
                        category.icon,
                        size: 15,
                        color: _category == category ? _color : colorScheme.onSurfaceVariant,
                      ),
                      label: Text(category.label),
                      selected: _category == category,
                      onSelected: (_) => setState(() => _category = category),
                      selectedColor: _color.withValues(alpha: 0.18),
                      labelStyle: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: _category == category ? _color : colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _active,
                onChanged: (value) => setState(() => _active = value),
                title: const Text('Masih aktif', style: TextStyle(fontSize: 13)),
                subtitle: Text(
                  'Dimatikan kalau langganannya berhenti — datanya tetap tersimpan',
                  style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton.icon(
                onPressed: _saving ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: _color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: _saving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check),
                label: Text(_saving ? 'Menyimpan...' : 'Simpan'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
