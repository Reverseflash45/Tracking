import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/offline/pending_writes.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../data/finance_repository.dart';
import '../domain/finance_stats.dart';
import '../domain/receipt_parser.dart';
import '../domain/transaction.dart';

const _color = AppColors.finance;
final _dateFormat = DateFormat('d MMMM y', 'id_ID');

/// Buka form transaksi.
///
/// [existing] untuk mengedit, [guess] untuk hasil baca struk yang masih perlu
/// dikonfirmasi.
Future<void> showTransactionSheet(
  BuildContext context, {
  Transaction? existing,
  ReceiptGuess? guess,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _TransactionSheet(existing: existing, guess: guess),
  );
}

class _TransactionSheet extends ConsumerStatefulWidget {
  const _TransactionSheet({this.existing, this.guess});

  final Transaction? existing;
  final ReceiptGuess? guess;

  @override
  ConsumerState<_TransactionSheet> createState() => _TransactionSheetState();
}

class _TransactionSheetState extends ConsumerState<_TransactionSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _merchantController;
  late final TextEditingController _productController;
  late final TextEditingController _noteController;

  late TxKind _kind;
  late TxCategory _category;
  late DateTime _date;
  PlaceKind? _placeKind;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;
  bool get _fromReceipt => widget.guess != null || (widget.existing?.fromReceipt ?? false);

  /// Kandidat nominal hanya relevan saat mengisi catatan baru dari struk.
  List<double> get _candidates =>
      _isEdit ? const [] : (widget.guess?.candidates ?? const []);

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    final guess = widget.guess;

    _kind = existing?.kind ?? TxKind.pengeluaran;
    _category = existing?.category ?? TxCategory.makan;
    _date = existing?.occurredOn ?? guess?.date ?? DateTime.now();
    _placeKind = existing?.placeKind ?? guess?.placeKind;

    _amountController = TextEditingController(
      text: existing != null
          ? existing.amount.round().toString()
          : (guess?.total?.round().toString() ?? ''),
    );
    _merchantController = TextEditingController(
      text: existing?.merchant ?? guess?.merchant ?? '',
    );
    _productController = TextEditingController(
      text: existing?.product ?? guess?.product ?? '',
    );
    _noteController = TextEditingController(text: existing?.note ?? '');
  }

  @override
  void dispose() {
    _amountController.dispose();
    _merchantController.dispose();
    _productController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  String? _bersih(TextEditingController controller) {
    final text = controller.text.trim();
    return text.isEmpty ? null : text;
  }

  void _setKind(TxKind kind) {
    setState(() {
      _kind = kind;
      // Kategori pengeluaran tidak berlaku untuk pemasukan, jadi direset ke
      // pilihan pertama yang sesuai.
      if (_category.kind != kind) _category = TxCategory.forKind(kind).first;
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final userId = ref.read(currentUserProvider)?.id;
    if (userId == null) return;

    setState(() => _saving = true);
    try {
      final repo = ref.read(financeRepositoryProvider);
      final tx = Transaction(
        id: widget.existing?.id ?? '',
        occurredOn: _date,
        kind: _kind,
        category: _category,
        amount: parseRupiah(_amountController.text) ?? 0,
        placeKind: _placeKind,
        merchant: _bersih(_merchantController),
        product: _bersih(_productController),
        note: _bersih(_noteController),
        fromReceipt: _fromReceipt,
      );

      var terkirim = true;
      if (_isEdit) {
        // Mengubah tetap butuh sinyal — antrean hanya untuk catatan baru.
        await repo.updateTransaction(userId, tx);
      } else {
        terkirim = await repo.addTransaction(
          userId,
          tx,
          queue: ref.read(pendingWriteQueueProvider),
        );
      }

      ref.invalidate(transactionsProvider);
      ref.invalidate(pendingWritesProvider);
      if (!mounted) return;
      if (!terkirim) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tersimpan di HP — dikirim otomatis begitu ada sinyal.'),
          ),
        );
      }
      Navigator.of(context).pop();
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
    final categories = TxCategory.forKind(_kind);

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
              Row(
                children: [
                  Icon(
                      _fromReceipt ? Icons.receipt_long : Icons.payments_outlined,
                      size: 20,
                      color: _color,
                    ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    _isEdit
                        ? 'Edit Transaksi'
                        : (_fromReceipt ? 'Periksa Hasil Struk' : 'Catat Transaksi'),
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ],
              ),

              // Hasil OCR bisa meleset. Katakan itu di depan, bukan setelah
              // angkanya terlanjur masuk catatan.
              if (widget.guess != null) ...[
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.priorityMedium.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          size: 16, color: AppColors.priorityMedium),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.guess!.total != null
                              ? 'Ini tebakan dari foto — periksa dulu sebelum simpan.'
                              : _candidates.isEmpty
                                  ? 'Nominalnya tidak ketemu di struk. Isi manual ya.'
                                  : 'Kata "total" tidak terbaca, jadi nominalnya '
                                      'tidak ditebak. Pilih salah satu angka di '
                                      'bawah atau ketik sendiri.',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: AppSpacing.md),
              SegmentedButton<TxKind>(
                segments: const [
                  ButtonSegment(
                    value: TxKind.pengeluaran,
                    label: Text('Keluar'),
                    icon: Icon(Icons.arrow_upward),
                  ),
                  ButtonSegment(
                    value: TxKind.pemasukan,
                    label: Text('Masuk'),
                    icon: Icon(Icons.arrow_downward),
                  ),
                ],
                selected: {_kind},
                onSelectionChanged: (selection) => _setKind(selection.first),
              ),

              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _amountController,
                // Kursor langsung ditaruh di sini kalau nominalnya belum
                // terisi — termasuk waktu pembacaan struk gagal, karena itu
                // justru saat kamu paling butuh mengetik cepat.
                autofocus: !_isEdit && _amountController.text.isEmpty,
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                decoration: const InputDecoration(
                  labelText: 'Nominal',
                  prefixText: 'Rp ',
                  prefixStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                validator: (value) {
                  final parsed = parseRupiah(value ?? '');
                  if (parsed == null || parsed <= 0) return 'Isi nominalnya';
                  return null;
                },
              ),

              // Kalau totalnya tidak ketemu, angka yang memang tertulis di
              // struk ditawarkan untuk dipilih. Menawarkan lebih jujur
              // daripada memilihkan, dan tetap lebih cepat daripada mengetik.
              if (_candidates.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Angka yang terbaca di struk:',
                  style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final value in _candidates)
                      ActionChip(
                        visualDensity: VisualDensity.compact,
                        label: Text(
                          formatRupiah(value),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onPressed: () => setState(() {
                          _amountController.text = value.round().toString();
                        }),
                      ),
                  ],
                ),
              ],

              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final category in categories)
                    ChoiceChip(
                      avatar: Icon(
                        category.icon,
                        size: 16,
                        color: _category == category
                            ? _color
                            : colorScheme.onSurfaceVariant,
                      ),
                      label: Text(category.label),
                      selected: _category == category,
                      onSelected: (_) => setState(() => _category = category),
                      selectedColor: _color.withValues(alpha: 0.18),
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _category == category
                            ? _color
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),

              const SizedBox(height: AppSpacing.md),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Tanggal',
                    prefixIcon: Icon(Icons.calendar_today, size: 20),
                  ),
                  child: Text(_dateFormat.format(_date)),
                ),
              ),

              // Tempat dipecah tiga: jenisnya, nama tokonya, dan barangnya.
              // Satu kolom bebas tidak bisa menjawab "paling sering jajan di
              // resto online atau masak sendiri?" — tiga kolom ini bisa.
              const SizedBox(height: AppSpacing.md),
              Text(
                'Tempat (opsional)',
                style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final place in PlaceKind.values)
                    ChoiceChip(
                      avatar: Icon(
                        place.icon,
                        size: 16,
                        color: _placeKind == place ? _color : colorScheme.onSurfaceVariant,
                      ),
                      label: Text(place.label),
                      selected: _placeKind == place,
                      // Bisa dibatalkan dengan mengetuk ulang — tidak semua
                      // pengeluaran punya tempat (transfer, iuran, parkir).
                      onSelected: (dipilih) =>
                          setState(() => _placeKind = dipilih ? place : null),
                      selectedColor: _color.withValues(alpha: 0.18),
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _placeKind == place ? _color : colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 12),
              TextFormField(
                controller: _merchantController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nama toko (opsional)',
                  hintText: 'Misal: Warung Bu Sri',
                ),
              ),

              const SizedBox(height: 12),
              TextFormField(
                controller: _productController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nama produk (opsional)',
                  hintText: 'Misal: Martabak telor',
                ),
              ),

              const SizedBox(height: 12),
              TextFormField(
                controller: _noteController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Catatan (opsional)'),
              ),

              // Teks mentahnya disediakan supaya kalau tebakannya meleset kamu
              // bisa mengecek sendiri apa yang sebenarnya terbaca.
              if (widget.guess != null && widget.guess!.rawLines.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text(
                    'Lihat teks yang terbaca',
                    style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant),
                  ),
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        widget.guess!.rawLines.join('\n'),
                        style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed: _saving ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: _color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
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
