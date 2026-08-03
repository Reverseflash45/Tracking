import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/hero_header.dart';
import '../data/watchlist_repository.dart';
import '../domain/watchlist.dart';

const _color = AppColors.watchlist;

class WatchlistPage extends ConsumerWidget {
  const WatchlistPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tersaring = ref.watch(watchlistTersaringProvider);
    final semua = ref.watch(watchlistProvider).value ?? const <MediaItem>[];
    final ringkasan = summarizeWatchlist(semua, now: DateTime.now());
    final filter = ref.watch(watchFilterProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _bukaForm(context, ref),
        backgroundColor: _color,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Judul'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(watchlistProvider),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            HeroHeader.sub(
              title: 'Watchlist',
              subtitle: 'Tontonan dan bacaanmu',
              color: _color,
              leading: HeroIconButton(
                icon: Icons.arrow_back,
                tooltip: 'Kembali',
                onPressed: () => context.pop(),
              ),
              stats: [
                HeroStatData(
                  icon: Icons.play_circle_outline,
                  value: '${ringkasan.jumlah(WatchStatus.jalan)}',
                  label: 'Sedang Jalan',
                ),
                HeroStatData(
                  icon: Icons.bookmark_border,
                  value: '${ringkasan.jumlah(WatchStatus.rencana)}',
                  label: 'Antre',
                ),
                HeroStatData(
                  icon: Icons.done_all,
                  value: '${ringkasan.selesaiTahunIni}',
                  label: 'Tamat Tahun Ini',
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 96),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _BarisCari(),
                  const SizedBox(height: AppSpacing.sm),
                  const _ChipStatus(),
                  const SizedBox(height: AppSpacing.md),
                  if (ringkasan.rataNilai case final rata?) ...[
                    _KartuNilai(rata: rata, jumlah: ringkasan.jumlahDinilai),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  tersaring.when(
                    data: (items) => items.isEmpty
                        ? _Kosong(adaFilter: !filter.kosong, semuanya: semua.isEmpty)
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (final item in items)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                                  child: _KartuMedia(item: item),
                                ),
                            ],
                          ),
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (error, _) => EmptyState(
                      icon: Icons.error_outline,
                      title: 'Gagal memuat watchlist',
                      subtitle: '$error',
                      color: _color,
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

class _Kosong extends StatelessWidget {
  const _Kosong({required this.adaFilter, required this.semuanya});

  final bool adaFilter;

  /// Daftarnya memang masih kosong, bukan cuma tersaring habis. Bedanya
  /// menentukan apa yang harus kamu lakukan berikutnya.
  final bool semuanya;

  @override
  Widget build(BuildContext context) {
    if (semuanya) {
      return const EmptyState(
        icon: Icons.movie_outlined,
        title: 'Belum ada judul',
        subtitle: 'Catat film, series, anime, buku, atau komik yang kamu '
            'incar. Yang sedang jalan akan selalu muncul paling atas.',
        color: _color,
      );
    }

    return EmptyState(
      icon: Icons.filter_alt_off_outlined,
      title: 'Tidak ada yang cocok',
      subtitle: adaFilter
          ? 'Tidak ada judul yang cocok dengan saringan yang sedang aktif.'
          : 'Tidak ada judul yang cocok.',
      color: _color,
    );
  }
}

class _BarisCari extends ConsumerStatefulWidget {
  const _BarisCari();

  @override
  ConsumerState<_BarisCari> createState() => _BarisCariState();
}

class _BarisCariState extends ConsumerState<_BarisCari> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(watchFilterProvider);
    final adaLanjutan = filter.kind != null || filter.origin != null;

    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            onChanged: (value) => ref.read(watchFilterProvider.notifier).setQuery(value),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Cari judul',
              prefixIcon: const Icon(Icons.search, size: 19),
              suffixIcon: _controller.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      tooltip: 'Hapus',
                      onPressed: () {
                        _controller.clear();
                        ref.read(watchFilterProvider.notifier).setQuery('');
                        setState(() {});
                      },
                    ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        IconButton.filledTonal(
          onPressed: () => _bukaSaringan(context, ref),
          tooltip: 'Saring bentuk & asal',
          icon: Badge(
            isLabelVisible: adaLanjutan,
            backgroundColor: _color,
            child: const Icon(Icons.tune, size: 20),
          ),
        ),
      ],
    );
  }
}

class _ChipStatus extends ConsumerWidget {
  const _ChipStatus();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aktif = ref.watch(watchFilterProvider).status;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _Chip(
            label: 'Semua',
            dipilih: aktif == null,
            onTap: () => ref.read(watchFilterProvider.notifier).setStatus(null),
          ),
          for (final status in WatchStatus.values) ...[
            const SizedBox(width: 6),
            _Chip(
              label: status.label,
              dipilih: aktif == status,
              onTap: () => ref
                  .read(watchFilterProvider.notifier)
                  .setStatus(aktif == status ? null : status),
            ),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.dipilih, required this.onTap});

  final String label;
  final bool dipilih;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: dipilih,
      onSelected: (_) => onTap(),
      selectedColor: _color.withValues(alpha: 0.18),
      showCheckmark: false,
      side: dipilih ? const BorderSide(color: _color) : null,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: dipilih ? FontWeight.w700 : FontWeight.w500,
        color: dipilih ? _color : null,
      ),
    );
  }
}

Future<void> _bukaSaringan(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => const _SheetSaringan(),
  );
}

class _SheetSaringan extends ConsumerWidget {
  const _SheetSaringan();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(watchFilterProvider);
    final notifier = ref.read(watchFilterProvider.notifier);

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Bentuk', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _Chip(
                label: 'Semua',
                dipilih: filter.kind == null,
                onTap: () => notifier.setKind(null),
              ),
              for (final kind in MediaKind.values)
                _Chip(
                  label: kind.label,
                  dipilih: filter.kind == kind,
                  onTap: () => notifier.setKind(filter.kind == kind ? null : kind),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          const Text('Asal', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _Chip(
                label: 'Semua',
                dipilih: filter.origin == null,
                onTap: () => notifier.setOrigin(null),
              ),
              for (final origin in MediaOrigin.values)
                _Chip(
                  label: origin.label,
                  dipilih: filter.origin == origin,
                  onTap: () => notifier.setOrigin(filter.origin == origin ? null : origin),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              TextButton(
                onPressed: () {
                  notifier.setKind(null);
                  notifier.setOrigin(null);
                },
                child: const Text('Bersihkan'),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(backgroundColor: _color),
                child: const Text('Selesai'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _KartuNilai extends StatelessWidget {
  const _KartuNilai({required this.rata, required this.jumlah});

  final double rata;
  final int jumlah;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            const Icon(Icons.star_rate_rounded, color: _color),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Rata-rata nilaimu ${rata.toStringAsFixed(1)}',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    // Jumlahnya selalu disebut: 9,0 dari satu judul bukan
                    // kesimpulan tentang seleramu.
                    'Dari $jumlah judul yang sudah kamu nilai',
                    style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
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

class _KartuMedia extends ConsumerWidget {
  const _KartuMedia({required this.item});

  final MediaItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
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
          title: const Text('Hapus dari watchlist?'),
          content: Text('"${item.title}" akan dihapus.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hapus')),
          ],
        ),
      ),
      onDismissed: (_) async {
        await ref.read(watchlistRepositoryProvider).deleteItem(item.id);
        ref.invalidate(watchlistProvider);
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(item.kind.icon, size: 16, color: _color),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            item.year == null ? item.title : '${item.title} (${item.year})',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${item.origin.label}  ·  ${item.kind.label}  ·  '
                            '${item.status.labelUntuk(item.kind)}',
                            style: TextStyle(fontSize: 11.5, color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    if (item.rating case final nilai?)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '$nilai/$kNilaiMaks',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: _color,
                          ),
                        ),
                      ),
                  ],
                ),
                if (item.progresLabel case final label?) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Text(
                        label,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                      if (persen != null) ...[
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: LinearProgressIndicator(
                              value: persen,
                              minHeight: 6,
                              backgroundColor: colorScheme.surfaceContainerHighest,
                              valueColor: const AlwaysStoppedAnimation(_color),
                            ),
                          ),
                        ),
                      ] else
                        // Tanpa total, tidak ada bilah progres. Menampilkan
                        // bilah kosong akan terbaca seperti "baru mulai",
                        // padahal yang sebenarnya terjadi adalah totalnya
                        // belum kamu isi.
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(left: AppSpacing.sm),
                            child: Text(
                              'total belum diisi',
                              style: TextStyle(
                                fontSize: 11,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
                if (item.note case final catatan? when catatan.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    catatan,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    if (item.kind.berprogres && !item.selesai)
                      _AksiKecil(
                        icon: Icons.add,
                        label: 'Lanjut 1 ${item.kind.satuan}',
                        onTap: () async {
                          final maju = majuSatu(item, now: DateTime.now());
                          await ref.read(watchlistRepositoryProvider).updateProgres(maju);
                          ref.invalidate(watchlistProvider);
                        },
                      ),
                    if (!item.selesai) ...[
                      const SizedBox(width: 6),
                      _AksiKecil(
                        icon: Icons.check,
                        label: 'Tamat',
                        onTap: () => _tandaiSelesai(context, ref, item),
                      ),
                    ],
                    if (item.selesai || item.status == WatchStatus.berhenti) ...[
                      const SizedBox(width: 6),
                      _AksiKecil(
                        icon: Icons.star_border,
                        label: item.dinilai ? 'Ubah nilai' : 'Beri nilai',
                        onTap: () => _beriNilai(context, ref, item),
                      ),
                    ],
                    const Spacer(),
                    if (item.url case final url? when url.trim().isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.open_in_new, size: 17),
                        tooltip: 'Buka tautan',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _bukaTautan(context, url),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AksiKecil extends StatelessWidget {
  const _AksiKecil({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: TextButton.styleFrom(
        foregroundColor: _color,
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 10),
      ),
    );
  }
}

Future<void> _bukaTautan(BuildContext context, String url) async {
  final uri = Uri.tryParse(url.trim());
  if (uri == null) return;

  final berhasil = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!berhasil && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tidak ada aplikasi yang bisa membuka tautan itu')),
    );
  }
}

Future<void> _tandaiSelesai(BuildContext context, WidgetRef ref, MediaItem item) async {
  final now = DateTime.now();
  final selesai = item.copyWith(
    status: WatchStatus.selesai,
    // Progres dilompatkan ke total kalau totalnya diketahui — menandai tamat
    // sambil meninggalkan "Ep 3 / 24" akan bertentangan dengan dirinya sendiri.
    progress: item.total ?? item.progress,
    finishedOn: DateTime(now.year, now.month, now.day),
  );

  await ref.read(watchlistRepositoryProvider).updateProgres(selesai);
  ref.invalidate(watchlistProvider);

  if (!context.mounted) return;
  await _beriNilai(context, ref, selesai);
}

Future<void> _beriNilai(BuildContext context, WidgetRef ref, MediaItem item) async {
  final nilai = await showDialog<int>(
    context: context,
    builder: (context) => _DialogNilai(item: item),
  );
  if (nilai == null) return;

  // Nol dipakai dialognya sebagai "hapus nilai", bukan nilai nol.
  await ref.read(watchlistRepositoryProvider).setRating(item.id, nilai == 0 ? null : nilai);
  ref.invalidate(watchlistProvider);
}

class _DialogNilai extends StatefulWidget {
  const _DialogNilai({required this.item});

  final MediaItem item;

  @override
  State<_DialogNilai> createState() => _DialogNilaiState();
}

class _DialogNilaiState extends State<_DialogNilai> {
  late int _nilai = widget.item.rating ?? 8;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.item.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$_nilai / $kNilaiMaks',
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: _color),
          ),
          Slider(
            value: _nilai.toDouble(),
            min: 1,
            max: kNilaiMaks.toDouble(),
            divisions: kNilaiMaks - 1,
            activeColor: _color,
            label: '$_nilai',
            onChanged: (value) => setState(() => _nilai = value.round()),
          ),
        ],
      ),
      actions: [
        if (widget.item.dinilai)
          TextButton(
            onPressed: () => Navigator.pop(context, 0),
            child: const Text('Hapus nilai'),
          ),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
        FilledButton(
          onPressed: () => Navigator.pop(context, _nilai),
          style: FilledButton.styleFrom(backgroundColor: _color),
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}

Future<void> _bukaForm(BuildContext context, WidgetRef ref, {MediaItem? item}) async {
  final tersimpan = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _SheetMedia(item: item),
  );
  if (tersimpan == true) ref.invalidate(watchlistProvider);
}

class _SheetMedia extends ConsumerStatefulWidget {
  const _SheetMedia({this.item});

  final MediaItem? item;

  @override
  ConsumerState<_SheetMedia> createState() => _SheetMediaState();
}

class _SheetMediaState extends ConsumerState<_SheetMedia> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _yearController;
  late final TextEditingController _progressController;
  late final TextEditingController _totalController;
  late final TextEditingController _urlController;
  late final TextEditingController _noteController;

  late MediaKind _kind;
  late MediaOrigin _origin;
  late WatchStatus _status;
  bool _saving = false;

  bool get _isEdit => widget.item != null;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _titleController = TextEditingController(text: item?.title ?? '');
    _yearController = TextEditingController(text: item?.year?.toString() ?? '');
    _progressController = TextEditingController(
      text: (item?.progress ?? 0) == 0 ? '' : '${item!.progress}',
    );
    _totalController = TextEditingController(text: item?.total?.toString() ?? '');
    _urlController = TextEditingController(text: item?.url ?? '');
    _noteController = TextEditingController(text: item?.note ?? '');
    _kind = item?.kind ?? MediaKind.film;
    _origin = item?.origin ?? MediaOrigin.lainnya;
    _status = item?.status ?? WatchStatus.rencana;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _yearController.dispose();
    _progressController.dispose();
    _totalController.dispose();
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
      final lama = widget.item;

      // Tanggal selesai hanya dibuat saat statusnya baru berubah jadi selesai.
      // Kalau sudah pernah selesai, tanggal aslinya dipertahankan — mengedit
      // catatan tidak boleh memindahkan kapan kamu menamatkannya.
      final selesaiPada = _status == WatchStatus.selesai
          ? (lama?.finishedOn ?? DateTime.now())
          : null;

      await ref.read(watchlistRepositoryProvider).saveItem(
            userId: userId,
            id: lama?.id,
            title: _titleController.text.trim(),
            kind: _kind,
            origin: _origin,
            status: _status,
            year: int.tryParse(_yearController.text.trim()),
            progress: _kind.berprogres
                ? (int.tryParse(_progressController.text.trim()) ?? 0)
                : 0,
            total: _kind.berprogres ? int.tryParse(_totalController.text.trim()) : null,
            rating: lama?.rating,
            url: url.isEmpty ? null : url,
            note: note.isEmpty ? null : note,
            finishedOn: selesaiPada,
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
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
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
                _isEdit ? 'Edit Judul' : 'Judul Baru',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _titleController,
                autofocus: !_isEdit,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Judul',
                  hintText: 'Misal: Frieren',
                  prefixIcon: Icon(Icons.label_outline),
                ),
                validator: (value) =>
                    (value == null || value.trim().isEmpty) ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: AppSpacing.md),
              _Label('Bentuk'),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final kind in MediaKind.values)
                    _Chip(
                      label: kind.label,
                      dipilih: _kind == kind,
                      onTap: () => setState(() => _kind = kind),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              _Label('Asal'),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final origin in MediaOrigin.values)
                    _Chip(
                      label: origin.label,
                      dipilih: _origin == origin,
                      onTap: () => setState(() => _origin = origin),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              _Label('Status'),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final status in WatchStatus.values)
                    _Chip(
                      label: status.labelUntuk(_kind),
                      dipilih: _status == status,
                      onTap: () => setState(() => _status = status),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              if (_kind.berprogres)
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _progressController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Sampai ${_kind.satuan}',
                          prefixIcon: const Icon(Icons.play_arrow_outlined),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: TextFormField(
                        controller: _totalController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Total ${_kind.satuan}',
                          // Dikosongkan saja kalau belum tahu; itu jawaban yang
                          // sah dan bilah progresnya memang tidak akan muncul.
                          hintText: 'boleh kosong',
                          prefixIcon: const Icon(Icons.tag),
                        ),
                      ),
                    ),
                  ],
                ),
              if (_kind.berprogres) const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _yearController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Tahun rilis',
                  hintText: 'opsional',
                  prefixIcon: Icon(Icons.calendar_today_outlined),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _urlController,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'Tautan',
                  hintText: 'MyAnimeList, IMDb, atau tempat nontonnya',
                  prefixIcon: Icon(Icons.link),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _noteController,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Catatan',
                  hintText: 'Rekomendasi dari siapa, kenapa mau ditonton',
                  prefixIcon: Icon(Icons.notes),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed: _saving ? null : _simpan,
                style: FilledButton.styleFrom(backgroundColor: _color),
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(_saving ? 'Menyimpan...' : 'Simpan'),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
