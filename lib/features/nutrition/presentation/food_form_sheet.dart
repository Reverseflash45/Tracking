import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ocr/barcode_scanner.dart';
import '../../../core/offline/pending_writes.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../data/food_database.dart';
import '../data/nutrition_repository.dart';
import '../domain/daily_nutrition.dart';
import '../domain/food_log.dart';

const _color = AppColors.deadline;

/// Sheet catat makanan. Kalau [existing] diisi, sheet berjalan dalam mode edit
/// dan menimpa catatan itu alih-alih membuat yang baru.
Future<void> showFoodFormSheet(BuildContext context, {Meal? meal, FoodLog? existing}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _FoodFormSheet(meal: meal, existing: existing),
  );
}

class _FoodFormSheet extends ConsumerStatefulWidget {
  const _FoodFormSheet({this.meal, this.existing});

  final Meal? meal;
  final FoodLog? existing;

  @override
  ConsumerState<_FoodFormSheet> createState() => _FoodFormSheetState();
}

class _FoodFormSheetState extends ConsumerState<_FoodFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _caloriesController = TextEditingController();
  final _proteinController = TextEditingController();
  final _carbsController = TextEditingController();
  final _fatController = TextEditingController();
  final _servingController = TextEditingController();
  final _fiberController = TextEditingController();
  final _sugarController = TextEditingController();
  final _sodiumController = TextEditingController();

  late Meal _meal = widget.existing?.meal ?? widget.meal ?? Meal.guessFor(DateTime.now());
  bool _showDetail = false;
  bool _saving = false;
  bool _memindai = false;

  /// Baca barcode kemasan lalu isi form dari basis data terbuka.
  ///
  /// Hasilnya selalu masuk form untuk kamu periksa, tidak pernah langsung
  /// tersimpan — datanya sumbangan orang banyak, jadi bisa saja keliru atau
  /// takaran sajinya beda dengan kemasan yang kamu pegang.
  Future<void> _scanBarcode() async {
    final hasil = await scanBarcodeFromPhoto();
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    if (hasil.gagal) {
      if (hasil.error != 'Batal') {
        messenger.showSnackBar(SnackBar(content: Text(hasil.error!)));
      }
      return;
    }

    setState(() => _memindai = true);
    try {
      final produk = await lookupBarcode(hasil.code!);
      if (!mounted) return;

      if (produk == null) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Produk ini belum ada di basis data. Isi manual saja '
                '— catatannya tetap tersimpan seperti biasa.'),
            duration: Duration(seconds: 5),
          ),
        );
        return;
      }

      // Kalau takaran sajinya tercantum, itu yang dipakai. Kalau tidak, 100 g
      // sebagai titik awal yang jelas asalnya, bukan tebakan porsi.
      final gram = produk.servingGrams ?? 100;
      final gizi = produk.per100g.untukGram(gram);

      setState(() {
        _nameController.text = produk.judul;
        _caloriesController.text = _trim(gizi.calories);
        _proteinController.text = _trim(gizi.proteinG);
        _carbsController.text = _trim(gizi.carbsG);
        _fatController.text = _trim(gizi.fatG);
        _servingController.text = _trim(gram);
        _fiberController.text = gizi.fiberG == null ? '' : _trim(gizi.fiberG!);
        _sugarController.text = gizi.sugarG == null ? '' : _trim(gizi.sugarG!);
        _sodiumController.text = gizi.sodiumMg == null ? '' : _trim(gizi.sodiumMg!);
        _showDetail = true;
      });

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Terisi untuk ${_trim(gram)} g'
            '${produk.servingGrams == null ? ' (takaran saji tidak tercantum)' : ''}. '
            'Periksa dulu sebelum simpan.',
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    } on FoodLookupException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _memindai = false);
    }
  }

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing == null) return;

    _nameController.text = existing.name;
    _caloriesController.text = _trim(existing.calories);
    _proteinController.text = _trim(existing.proteinG);
    _carbsController.text = _trim(existing.carbsG);
    _fatController.text = _trim(existing.fatG);
    _servingController.text = existing.servingGrams == null ? '' : _trim(existing.servingGrams!);
    _fiberController.text = existing.fiberG == null ? '' : _trim(existing.fiberG!);
    _sugarController.text = existing.sugarG == null ? '' : _trim(existing.sugarG!);
    _sodiumController.text = existing.sodiumMg == null ? '' : _trim(existing.sodiumMg!);

    // Detail dibuka sejak awal kalau memang ada isinya, supaya angka yang
    // tersembunyi tidak diam-diam ikut tersimpan tanpa sempat dilihat.
    _showDetail = existing.servingGrams != null ||
        existing.fiberG != null ||
        existing.sugarG != null ||
        existing.sodiumMg != null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    _servingController.dispose();
    _fiberController.dispose();
    _sugarController.dispose();
    _sodiumController.dispose();
    super.dispose();
  }

  void _applyFrequent(FrequentFood food) {
    setState(() {
      _nameController.text = food.name;
      _caloriesController.text = _trim(food.calories);
      _proteinController.text = _trim(food.proteinG);
      _carbsController.text = _trim(food.carbsG);
      _fatController.text = _trim(food.fatG);
      _servingController.text = food.servingGrams == null ? '' : _trim(food.servingGrams!);
      _fiberController.text = food.fiberG == null ? '' : _trim(food.fiberG!);
      _sugarController.text = food.sugarG == null ? '' : _trim(food.sugarG!);
      _sodiumController.text = food.sodiumMg == null ? '' : _trim(food.sodiumMg!);
    });
  }

  static String _trim(double value) =>
      value == value.roundToDouble() ? value.round().toString() : value.toString();

  static double? _parse(String raw) {
    final text = raw.trim().replaceAll(',', '.');
    return text.isEmpty ? null : double.tryParse(text);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final userId = ref.read(currentUserProvider)?.id;
    if (userId == null) return;

    setState(() => _saving = true);
    try {
      final repository = ref.read(nutritionRepositoryProvider);
      final now = DateTime.now();
      final food = FoodLog(
        id: widget.existing?.id ?? '',
        loggedOn: widget.existing?.loggedOn ?? now,
        loggedAt: widget.existing?.loggedAt ?? now,
        name: _nameController.text.trim(),
        meal: _meal,
        calories: _parse(_caloriesController.text) ?? 0,
        proteinG: _parse(_proteinController.text) ?? 0,
        carbsG: _parse(_carbsController.text) ?? 0,
        fatG: _parse(_fatController.text) ?? 0,
        servingGrams: _parse(_servingController.text),
        fiberG: _parse(_fiberController.text),
        sugarG: _parse(_sugarController.text),
        sodiumMg: _parse(_sodiumController.text),
      );

      var terkirim = true;
      if (_isEdit) {
        // Mengubah tetap butuh sinyal — antrean hanya untuk catatan baru.
        await repository.updateFood(id: widget.existing!.id, food: food);
      } else {
        terkirim = await repository.addFood(
          userId: userId,
          food: food,
          queue: ref.read(pendingWriteQueueProvider),
        );
      }

      ref.invalidate(foodLogsProvider);
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
    final frequent = ref.watch(frequentFoodsProvider).value ?? const <FrequentFood>[];

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
                      _isEdit ? Icons.edit_outlined : Icons.restaurant,
                      size: 20,
                      color: _color,
                    ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    _isEdit ? 'Edit Makanan' : 'Catat Makanan',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              // Scan barcode juga menimpa seluruh isi form, jadi ikut aturan
              // yang sama dengan pintasan di bawahnya.
              if (!_isEdit && barcodeScanSupported) ...[
                const SizedBox(height: AppSpacing.md),
                OutlinedButton.icon(
                  onPressed: _memindai ? null : _scanBarcode,
                  style: OutlinedButton.styleFrom(foregroundColor: _color),
                  icon: _memindai
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.qr_code_scanner, size: 20),
                  label: Text(
                    _memindai ? 'Mencari...' : 'Scan barcode kemasan',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
              // Pintasan "sering dicatat" menimpa seluruh isi form, jadi hanya
              // masuk akal saat mencatat baru — bukan saat mengoreksi satu entri.
              if (!_isEdit && frequent.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Sering dicatat',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  height: 34,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: frequent.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 4),
                    itemBuilder: (context, index) {
                      final food = frequent[index];
                      return ActionChip(
                        label: Text('${food.name} · ${food.calories.round()} kkal'),
                        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        onPressed: () => _applyFrequent(food),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _nameController,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Nama makanan',
                  hintText: 'Misal: Nasi goreng',
                  prefixIcon: Icon(Icons.fastfood_outlined),
                ),
                validator: (value) =>
                    (value == null || value.trim().isEmpty) ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  for (final meal in Meal.values)
                    ChoiceChip(
                      label: Text(meal.label),
                      selected: _meal == meal,
                      onSelected: (_) => setState(() => _meal = meal),
                      selectedColor: _color.withValues(alpha: 0.18),
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _meal == meal
                            ? _color
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _caloriesController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Kalori (kkal)',
                  prefixIcon: Icon(Icons.local_fire_department_outlined),
                ),
                validator: (value) {
                  final parsed = _parse(value ?? '');
                  if (parsed == null) return 'Kalori wajib diisi';
                  if (parsed < 0) return 'Tidak boleh negatif';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _macroField(_proteinController, 'Protein (g)')),
                  const SizedBox(width: 8),
                  Expanded(child: _macroField(_carbsController, 'Karbo (g)')),
                  const SizedBox(width: 8),
                  Expanded(child: _macroField(_fatController, 'Lemak (g)')),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() => _showDetail = !_showDetail),
                  style: TextButton.styleFrom(
                    foregroundColor: _color,
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: Icon(_showDetail ? Icons.expand_less : Icons.expand_more, size: 20),
                  label: Text(
                    _showDetail ? 'Sembunyikan detail' : 'Detail lain (opsional)',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              if (_showDetail) ...[
                Row(
                  children: [
                    Expanded(child: _macroField(_servingController, 'Berat (g)')),
                    const SizedBox(width: 8),
                    Expanded(child: _macroField(_fiberController, 'Serat (g)')),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _macroField(_sugarController, 'Gula (g)')),
                    const SizedBox(width: 8),
                    Expanded(child: _macroField(_sodiumController, 'Natrium (mg)')),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed: _saving ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: _color,
                  foregroundColor: Colors.white,
                ),
                icon: _saving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check),
                label: Text(
                  _saving ? 'Menyimpan...' : (_isEdit ? 'Simpan Perubahan' : 'Simpan'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _macroField(TextEditingController controller, String label) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label),
      validator: (value) {
        final text = (value ?? '').trim();
        if (text.isEmpty) return null;
        final parsed = _parse(text);
        if (parsed == null) return 'Angka';
        if (parsed < 0) return 'Negatif';
        return null;
      },
    );
  }
}
