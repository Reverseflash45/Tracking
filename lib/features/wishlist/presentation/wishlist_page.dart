import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/offline/pending_writes.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/hero_header.dart';
import '../../finance/data/finance_repository.dart';
import '../../finance/domain/transaction.dart';
import '../data/wishlist_repository.dart';
import '../domain/wishlist.dart';

const _color = AppColors.finance;

final _rupiah = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
final _tanggal = DateFormat('d MMM y', 'id_ID');
final _bulanTahun = DateFormat('MMMM y', 'id_ID');

class WishlistPage extends ConsumerWidget {
  const WishlistPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plansAsync = ref.watch(wishlistPlanProvider);
    final items = ref.watch(wishlistProvider).value ?? const <WishlistItem>[];
    final ringkasan = summarizeWishlist(items);
    final surplus = ref.watch(surplusBulananProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _bukaForm(context, ref),
        backgroundColor: _color,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Barang'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(wishlistProvider);
          ref.invalidate(transactionsProvider);
        },
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            HeroHeader(
              title: 'Wishlist',
              subtitle: 'Barang yang ingin kamu punya',
              color: _color,
              leading: HeroIconButton(
                icon: Icons.arrow_back,
                tooltip: 'Kembali',
                onPressed: () => context.pop(),
              ),
              stats: [
                HeroStatData(
                  icon: Icons.favorite_outline,
                  value: '${ringkasan.jumlahAktif}',
                  label: 'Diinginkan',
                ),
                HeroStatData(
                  icon: Icons.savings_outlined,
                  value: _ringkas(ringkasan.totalTersisih),
                  label: 'Tersisih',
                ),
                HeroStatData(
                  icon: Icons.trending_flat,
                  value: _ringkas(ringkasan.totalKurang),
                  label: 'Masih Kurang',
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 96),
              child: plansAsync.when(
                data: (plans) => plans.isEmpty
                    ? const EmptyState(
                        icon: Icons.favorite_outline,
                        title: 'Belum ada barang',
                        subtitle: 'Catat yang kamu incar. Karena app ini tahu '
                            'pemasukan dan pengeluaranmu, dia bisa memperkirakan '
                            'kapan barangnya terjangkau.',
                        color: _color,
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _SurplusCard(surplus: surplus, ringkasan: ringkasan),
                          const SizedBox(height: AppSpacing.md),
                          for (final plan in plans)
                            Padding(
                              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                              child: _WishCard(plan: plan),
                            ),
                        ],
                      ),
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, _) => EmptyState(
                  icon: Icons.error_outline,
                  title: 'Gagal memuat wishlist',
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
}

/// Angka ringkas untuk kotak statistik yang sempit: 1,2jt / 450rb.
String _ringkas(double nilai) {
  if (nilai >= 1000000) return '${(nilai / 1000000).toStringAsFixed(1)}jt';
  if (nilai >= 1000) return '${(nilai / 1000).round()}rb';
  return nilai.round().toString();
}

Future<void> _bukaForm(BuildContext context, WidgetRef ref, {WishlistItem? item}) async {
  final tersimpan = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _WishSheet(item: item),
  );
  if (tersimpan == true) ref.invalidate(wishlistProvider);
}

class _SurplusCard extends StatelessWidget {
  const _SurplusCard({required this.surplus, required this.ringkasan});

  final double surplus;
  final WishlistSummary ringkasan;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final negatif = surplus <= 0;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  negatif ? Icons.trending_down : Icons.trending_up,
                  size: 18,
                  color: negatif ? colorScheme.error : _color,
                ),
                const SizedBox(width: AppSpacing.sm),
                const Expanded(
                  child: Text(
                    'Sisa uang per bulan',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                  ),
                ),
                Text(
                  _rupiah.format(surplus),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: negatif ? colorScheme.error : _color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              negatif
                  ? 'Dari $kBulanRiwayatSurplus bulan terakhir, pengeluaranmu '
                      'menyamai atau melebihi pemasukan. Selama begitu, perkiraan '
                      'waktu tidak bisa dihitung — bukan karena datanya kurang, '
                      'tapi karena tabungannya memang tidak bertambah.'
                  : 'Rata-rata $kBulanRiwayatSurplus bulan terakhir, tidak termasuk '
                      'bulan berjalan yang belum selesai. Inilah yang dipakai '
                      'memperkirakan kapan tiap barang terjangkau.',
              style: TextStyle(fontSize: 11.5, height: 1.45, color: colorScheme.onSurfaceVariant),
            ),
            if (ringkasan.tanpaHarga > 0) ...[
              const SizedBox(height: 6),
              Text(
                '${ringkasan.tanpaHarga} barang belum diisi harganya, jadi belum '
                'ikut dihitung di total mana pun.',
                style: TextStyle(fontSize: 11.5, height: 1.45, color: colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WishCard extends ConsumerWidget {
  const _WishCard({required this.plan});

  final WishlistPlan plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final item = plan.item;
    final persen = item.persen;

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
      confirmDismiss: (_) => showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Hapus dari wishlist?'),
          content: Text('"${item.name}" akan dihapus.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hapus')),
          ],
        ),
      ),
      onDismissed: (_) async {
        await ref.read(wishlistRepositoryProvider).deleteItem(item.id);
        ref.invalidate(wishlistProvider);
      },
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _bukaForm(context, ref, item: item),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(iconUntuk(item), size: 17, color: _color),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14.5,
                              decoration: item.dibeli ? TextDecoration.lineThrough : null,
                              color: item.dibeli ? colorScheme.onSurfaceVariant : null,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            [
                              item.adaHarga ? _rupiah.format(item.price) : 'Harga belum diisi',
                              item.priority.label,
                              if (item.targetDate != null)
                                'target ${_tanggal.format(item.targetDate!)}',
                            ].join('  ·  '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11.5, color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    if (item.url != null && item.url!.trim().isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.open_in_new, size: 17),
                        tooltip: 'Buka link',
                        onPressed: () => _bukaLink(context, item.url!),
                      ),
                  ],
                ),
                if (!item.dibeli && persen != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Text(
                        _rupiah.format(item.saved),
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                      ),
                      Text(
                        ' tersisih',
                        style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                      ),
                      const Spacer(),
                      Text(
                        '${(persen * 100).round()}%',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: persen,
                      minHeight: 7,
                      backgroundColor: colorScheme.surfaceContainerHighest,
                      valueColor: const AlwaysStoppedAnimation(_color),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _catatan(plan),
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.4,
                    color: plan.telat ? colorScheme.error : colorScheme.onSurfaceVariant,
                  ),
                ),
                if (!item.dibeli) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: () => _nabung(context, ref, item),
                        style: TextButton.styleFrom(
                          foregroundColor: _color,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Nabung', style: TextStyle(fontSize: 12)),
                      ),
                      const SizedBox(width: 4),
                      TextButton.icon(
                        onPressed: () => _tandaiDibeli(context, ref, item),
                        style: TextButton.styleFrom(
                          foregroundColor: _color,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.shopping_bag_outlined, size: 16),
                        label: const Text('Sudah dibeli', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Satu kalimat yang menjawab "kapan aku bisa beli ini".
  static String _catatan(WishlistPlan plan) {
    final item = plan.item;

    if (item.dibeli) {
      return 'Dibeli ${_tanggal.format(item.boughtOn!)}.';
    }
    if (!item.adaHarga) {
      return 'Isi harganya supaya perkiraan waktunya bisa dihitung.';
    }
    if (item.lunas) {
      return 'Dananya sudah cukup — tinggal dibeli.';
    }
    if (plan.tidakAkanTerkumpul) {
      return 'Dengan pola pengeluaran sekarang, ini tidak akan terkumpul. '
          'Kurang ${_rupiah.format(item.kurang)}.';
    }

    final tiba = plan.perkiraan;
    if (tiba == null) {
      return 'Kurang ${_rupiah.format(item.kurang)} — lebih dari '
          '${kMaxBulanPerkiraan ~/ 12} tahun dengan laju sekarang, jadi '
          'perkiraan tanggalnya tidak ditampilkan.';
    }

    final dasar = 'Kurang ${_rupiah.format(item.kurang)} — perkiraan terjangkau '
        '${_bulanTahun.format(tiba)}.';
    return plan.telat
        ? '$dasar Lewat dari targetmu ${_tanggal.format(item.targetDate!)}.'
        : dasar;
  }
}

Future<void> _bukaLink(BuildContext context, String url) async {
  final bersih = url.trim();
  final uri = Uri.tryParse(bersih.startsWith('http') ? bersih : 'https://$bersih');
  final berhasil = uri == null
      ? false
      : await launchUrl(uri, mode: LaunchMode.externalApplication);

  if (!berhasil && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Link-nya tidak bisa dibuka')),
    );
  }
}

Future<void> _nabung(BuildContext context, WidgetRef ref, WishlistItem item) async {
  final tambahan = await showModalBottomSheet<double>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _NabungSheet(item: item),
  );
  if (tambahan == null) return;

  // Nilai akhir yang dikirim, bukan selisihnya: menekan tombol dua kali karena
  // jaringan lambat tidak boleh menambah tabungan dua kali.
  await ref.read(wishlistRepositoryProvider).setSaved(item.id, item.saved + tambahan);
  ref.invalidate(wishlistProvider);
}

Future<void> _tandaiDibeli(BuildContext context, WidgetRef ref, WishlistItem item) async {
  final hasil = await showModalBottomSheet<({double harga, bool catat})>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _BeliSheet(item: item),
  );
  if (hasil == null) return;

  final repo = ref.read(wishlistRepositoryProvider);
  await repo.setBought(item.id, DateTime.now());

  if (hasil.catat) {
    final userId = ref.read(currentUserProvider)?.id;
    if (userId != null) {
      await ref.read(financeRepositoryProvider).addTransaction(
            userId,
            Transaction(
              id: '',
              occurredOn: DateTime.now(),
              kind: TxKind.pengeluaran,
              category: item.category,
              amount: hasil.harga,
              product: item.name,
              note: 'Dari wishlist',
            ),
            queue: ref.read(pendingWriteQueueProvider),
          );
      ref.invalidate(transactionsProvider);
    }
  }

  ref.invalidate(wishlistProvider);
}

class _NabungSheet extends StatefulWidget {
  const _NabungSheet({required this.item});

  final WishlistItem item;

  @override
  State<_NabungSheet> createState() => _NabungSheetState();
}

class _NabungSheetState extends State<_NabungSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _kirim() {
    final angka = double.tryParse(_controller.text.trim().replaceAll(RegExp(r'[.,\s]'), ''));
    if (angka == null || angka <= 0) return;
    Navigator.pop(context, angka);
  }

  @override
  Widget build(BuildContext context) {
    final kurang = widget.item.kurang;

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        top: AppSpacing.md,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Nabung untuk ${widget.item.name}',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Jumlah',
              prefixText: 'Rp ',
              helperText: kurang == null ? null : 'Kurang ${_rupiah.format(kurang)}',
            ),
            onSubmitted: (_) => _kirim(),
          ),
          if (kurang != null && kurang > 0) ...[
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context, kurang),
                child: Text('Lunasi ${_rupiah.format(kurang)}'),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: _kirim,
            style: FilledButton.styleFrom(
              backgroundColor: _color,
              minimumSize: const Size.fromHeight(48),
            ),
            child: const Text('Tambah'),
          ),
        ],
      ),
    );
  }
}

class _BeliSheet extends StatefulWidget {
  const _BeliSheet({required this.item});

  final WishlistItem item;

  @override
  State<_BeliSheet> createState() => _BeliSheetState();
}

class _BeliSheetState extends State<_BeliSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.item.price?.round().toString() ?? '',
  );
  bool _catat = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        top: AppSpacing.md,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Sudah beli ${widget.item.name}?',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Harga yang benar-benar dibayar',
              prefixText: 'Rp ',
              helperText: 'Kalau dapat diskon, isi harga aslinya di sini',
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            value: _catat,
            activeColor: _color,
            title: const Text('Catat sebagai pengeluaran', style: TextStyle(fontSize: 13.5)),
            subtitle: Text(
              'Masuk kategori ${widget.item.category.label}',
              style: TextStyle(fontSize: 11.5, color: colorScheme.onSurfaceVariant),
            ),
            onChanged: (value) => setState(() => _catat = value ?? true),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: () {
              final angka =
                  double.tryParse(_controller.text.trim().replaceAll(RegExp(r'[.,\s]'), ''));
              if (_catat && (angka == null || angka <= 0)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Isi harganya dulu supaya bisa dicatat')),
                );
                return;
              }
              Navigator.pop(context, (harga: angka ?? 0, catat: _catat));
            },
            style: FilledButton.styleFrom(
              backgroundColor: _color,
              minimumSize: const Size.fromHeight(48),
            ),
            child: const Text('Tandai sudah dibeli'),
          ),
        ],
      ),
    );
  }
}

class _WishSheet extends ConsumerStatefulWidget {
  const _WishSheet({this.item});

  final WishlistItem? item;

  @override
  ConsumerState<_WishSheet> createState() => _WishSheetState();
}

class _WishSheetState extends ConsumerState<_WishSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  late final TextEditingController _urlController;
  late final TextEditingController _noteController;

  late TxCategory _category;
  late WishPriority _priority;
  DateTime? _targetDate;
  bool _saving = false;

  bool get _isEdit => widget.item != null;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _nameController = TextEditingController(text: item?.name ?? '');
    _priceController = TextEditingController(text: item?.price?.round().toString() ?? '');
    _urlController = TextEditingController(text: item?.url ?? '');
    _noteController = TextEditingController(text: item?.note ?? '');
    _category = item?.category ?? TxCategory.belanja;
    _priority = item?.priority ?? WishPriority.sedang;
    _targetDate = item?.targetDate;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _urlController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _simpan() async {
    if (!_formKey.currentState!.validate()) return;

    final userId = ref.read(currentUserProvider)?.id;
    if (userId == null) return;

    setState(() => _saving = true);
    try {
      final url = _urlController.text.trim();
      final note = _noteController.text.trim();

      await ref.read(wishlistRepositoryProvider).saveItem(
            userId: userId,
            id: widget.item?.id,
            name: _nameController.text.trim(),
            // Kosong tetap null, bukan nol: barang tanpa harga sengaja tidak
            // ikut menghitung total apa pun.
            price: double.tryParse(
              _priceController.text.trim().replaceAll(RegExp(r'[.,\s]'), ''),
            ),
            category: _category,
            priority: _priority,
            url: url.isEmpty ? null : url,
            note: note.isEmpty ? null : note,
            targetDate: _targetDate,
          );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pengeluaran = TxCategory.values.where((c) => c.kind == TxKind.pengeluaran);

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        top: AppSpacing.md,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.md,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _isEdit ? 'Edit Barang' : 'Barang Baru',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _nameController,
                autofocus: !_isEdit,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nama barang',
                  hintText: 'Misal: Keyboard mekanik',
                  prefixIcon: Icon(Icons.label_outline),
                ),
                validator: (value) =>
                    (value == null || value.trim().isEmpty) ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Harga',
                  prefixText: 'Rp ',
                  helperText: 'Boleh dikosongkan kalau belum tahu',
                  prefixIcon: Icon(Icons.sell_outlined),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<TxCategory>(
                initialValue: _category,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Kategori',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: [
                  for (final category in pengeluaran)
                    DropdownMenuItem(value: category, child: Text(category.label)),
                ],
                onChanged: (value) => setState(() => _category = value ?? _category),
              ),
              const SizedBox(height: AppSpacing.md),
              const Text('Prioritas', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: AppSpacing.sm),
              SegmentedButton<WishPriority>(
                segments: [
                  for (final priority in WishPriority.values)
                    ButtonSegment(value: priority, label: Text(priority.label)),
                ],
                selected: {_priority},
                showSelectedIcon: false,
                onSelectionChanged: (value) => setState(() => _priority = value.first),
              ),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton.icon(
                onPressed: () async {
                  final sekarang = DateTime.now();
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _targetDate ?? sekarang,
                    firstDate: sekarang,
                    lastDate: sekarang.add(const Duration(days: 1825)),
                  );
                  if (picked != null) setState(() => _targetDate = picked);
                },
                icon: const Icon(Icons.event_outlined, size: 18),
                label: Text(
                  _targetDate == null
                      ? 'Kapan ingin punya (opsional)'
                      : 'Target ${_tanggal.format(_targetDate!)}',
                ),
              ),
              if (_targetDate != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => setState(() => _targetDate = null),
                    child: const Text('Hapus target', style: TextStyle(fontSize: 12)),
                  ),
                ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _urlController,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'Link toko (opsional)',
                  prefixIcon: Icon(Icons.link),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _noteController,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Catatan (opsional)',
                  hintText: 'Warna, ukuran, alasan ingin',
                  prefixIcon: Icon(Icons.notes),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: _saving ? null : _simpan,
                style: FilledButton.styleFrom(
                  backgroundColor: _color,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Simpan'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
