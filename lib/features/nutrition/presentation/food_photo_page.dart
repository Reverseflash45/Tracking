import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/offline/pending_writes.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/hero_header.dart';
import '../data/food_photo_repository.dart';
import '../data/nutrition_repository.dart';
import '../domain/food_log.dart';
import '../domain/food_photo.dart';

const _color = AppColors.deadline;

/// Sisi terpanjang foto yang dikirim. Cukup untuk mengenali isi piring, dan
/// tiap piksel ekstra ditagih sebagai token gambar.
const double _kSisiMaks = 1024;

/// Langkah tombol − / + pada berat.
const double _kLangkahGram = 10;

/// Foto makanan → taksiran kalori dan makro per komponen piring.
///
/// Tidak ada yang tersimpan sebelum kamu menekan Simpan: tiap item bisa
/// dicentang, dan beratnya bisa dikoreksi — kalori dan makronya ikut
/// menyesuaikan, karena berat memang bagian yang paling sering meleset.
class FoodPhotoPage extends ConsumerStatefulWidget {
  const FoodPhotoPage({super.key, this.meal});

  final Meal? meal;

  @override
  ConsumerState<FoodPhotoPage> createState() => _FoodPhotoPageState();
}

class _FoodPhotoPageState extends ConsumerState<FoodPhotoPage> {
  final _keterangan = TextEditingController();

  late Meal _meal = widget.meal ?? Meal.guessFor(DateTime.now());

  Uint8List? _foto;
  String _jenis = 'image/jpeg';
  bool _menganalisis = false;
  bool _menyimpan = false;
  String? _galat;

  HasilFotoMakanan? _hasil;

  /// Versi yang sudah dikoreksi, sejajar dengan [_hasil].items.
  List<TebakanMakanan> _items = const [];
  Set<int> _dipilih = {};

  @override
  void dispose() {
    _keterangan.dispose();
    super.dispose();
  }

  Future<void> _ambil(ImageSource sumber) async {
    final file = await ImagePicker().pickImage(
      source: sumber,
      maxWidth: _kSisiMaks,
      maxHeight: _kSisiMaks,
      imageQuality: 80,
    );
    if (file == null) return;

    final bytes = await file.readAsBytes();
    final jenis = jenisGambar(bytes);
    if (!mounted) return;
    if (jenis == null) {
      setState(() => _galat = 'Format fotonya tidak didukung. Pakai JPEG atau PNG.');
      return;
    }

    setState(() {
      _foto = bytes;
      _jenis = jenis;
      _hasil = null;
      _items = const [];
      _dipilih = {};
      _galat = null;
    });
    await _analisis();
  }

  Future<void> _analisis() async {
    final foto = _foto;
    if (foto == null) return;

    setState(() {
      _menganalisis = true;
      _galat = null;
    });
    try {
      final hasil = await ref
          .read(foodPhotoRepositoryProvider)
          .taksir(foto, mediaType: _jenis, keterangan: _keterangan.text);
      if (!mounted) return;
      setState(() {
        _hasil = hasil;
        _items = [...hasil.items];
        _dipilih = {for (var i = 0; i < hasil.items.length; i++) i};
      });
    } on FotoMakananException catch (e) {
      if (mounted) setState(() => _galat = e.message);
    } catch (e) {
      if (mounted) setState(() => _galat = 'Gagal menganalisis: $e');
    } finally {
      if (mounted) setState(() => _menganalisis = false);
    }
  }

  void _ubahGram(int i, double gram) {
    setState(() {
      _items = [
        for (var j = 0; j < _items.length; j++)
          j == i ? _items[j].denganGram(gram.clamp(0, 5000).toDouble()) : _items[j],
      ];
    });
  }

  Future<void> _ketikGram(int i) async {
    final controller = TextEditingController(text: _items[i].gram.round().toString());
    final hasil = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Berat ${_items[i].nama}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(suffixText: 'g'),
          onSubmitted: (v) => Navigator.pop(context, double.tryParse(v.replaceAll(',', '.'))),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              double.tryParse(controller.text.replaceAll(',', '.')),
            ),
            child: const Text('Pakai'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (hasil != null) _ubahGram(i, hasil);
  }

  Future<void> _simpan() async {
    final userId = ref.read(currentUserProvider)?.id;
    if (userId == null || _dipilih.isEmpty) return;

    setState(() => _menyimpan = true);
    final repo = ref.read(nutritionRepositoryProvider);
    final queue = ref.read(pendingWriteQueueProvider);
    final now = DateTime.now();
    var tertunda = 0;
    try {
      for (final i in _dipilih.toList()..sort()) {
        final terkirim = await repo.addFood(
          userId: userId,
          food: _items[i].keFoodLog(_meal, now),
          queue: queue,
        );
        if (!terkirim) tertunda++;
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _menyimpan = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menyimpan: $e')));
      return;
    }

    ref.invalidate(foodLogsProvider);
    ref.invalidate(pendingWritesProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          tertunda > 0
              ? '${_dipilih.length} makanan tersimpan di HP — dikirim begitu ada sinyal.'
              : '${_dipilih.length} makanan dicatat ke ${_meal.label.toLowerCase()}.',
        ),
      ),
    );
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foto = _foto;
    final hasil = _hasil;
    final total = totalTebakan([for (final i in _dipilih) _items[i]]);

    return Scaffold(
      bottomNavigationBar: hasil == null || hasil.items.isEmpty
          ? null
          : BilahSimpanTebakan(
              meal: _meal,
              onMeal: (m) => setState(() => _meal = m),
              jumlah: _dipilih.length,
              kalori: total.kalori,
              menyimpan: _menyimpan,
              onSimpan: _simpan,
            ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          HeroHeader.sub(
            title: 'Foto makanan',
            subtitle: 'Taksiran kalori dan makro dari foto',
            color: _color,
            leading: HeroIconButton(
              icon: Icons.arrow_back,
              tooltip: 'Kembali',
              onPressed: () => context.pop(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (foto != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.memory(foto, height: 220, fit: BoxFit.cover),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                TextField(
                  controller: _keterangan,
                  textCapitalization: TextCapitalization.sentences,
                  maxLength: 300,
                  decoration: const InputDecoration(
                    labelText: 'Keterangan (opsional)',
                    hintText: 'Misal: nasi setengah porsi, ayamnya paha',
                    helperText: 'Membantu kalau ada yang tidak terlihat di foto',
                    counterText: '',
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _menganalisis ? null : () => _ambil(ImageSource.camera),
                        style: FilledButton.styleFrom(backgroundColor: _color),
                        icon: const Icon(Icons.photo_camera_outlined, size: 18),
                        label: Text(foto == null ? 'Ambil foto' : 'Foto ulang'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _menganalisis ? null : () => _ambil(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_outlined, size: 18),
                        label: const Text('Dari galeri'),
                      ),
                    ),
                  ],
                ),
                if (foto != null && hasil != null && !_menganalisis)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: _analisis,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Analisis ulang dengan keterangan'),
                    ),
                  ),
                const SizedBox(height: AppSpacing.md),
                if (_menganalisis)
                  const _Memuat()
                else if (_galat case final galat?)
                  _Kotak(ikon: Icons.error_outline, warna: colorScheme.error, teks: galat)
                else if (hasil == null)
                  _Kotak(
                    ikon: Icons.info_outline,
                    warna: colorScheme.onSurfaceVariant,
                    teks: 'Foto dari atas dengan seluruh piring terlihat paling mudah '
                        'ditaksir. Ada sendok atau tangan di dekatnya juga membantu '
                        'menebak porsi.',
                  )
                else ...[
                  if (hasil.catatan.isNotEmpty) ...[
                    _Kotak(ikon: Icons.lightbulb_outline, warna: AppColors.priorityMedium, teks: hasil.catatan),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  if (hasil.items.isEmpty)
                    _Kotak(
                      ikon: Icons.no_food_outlined,
                      warna: colorScheme.onSurfaceVariant,
                      teks: 'Tidak ada makanan yang bisa dikenali di foto ini.',
                    )
                  else ...[
                    for (var i = 0; i < _items.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: KartuTebakan(
                          item: _items[i],
                          dipilih: _dipilih.contains(i),
                          onPilih: (v) => setState(() => v ? _dipilih.add(i) : _dipilih.remove(i)),
                          onKurang: () => _ubahGram(i, _items[i].gram - _kLangkahGram),
                          onTambah: () => _ubahGram(i, _items[i].gram + _kLangkahGram),
                          onKetik: () => _ketikGram(i),
                        ),
                      ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Ini perkiraan dari foto. Minyak, santan, dan gula yang larut '
                      'tidak terlihat, jadi angka sebenarnya bisa lebih tinggi. '
                      'Total terpilih: ${total.protein.round()} g protein, '
                      '${total.karbo.round()} g karbo, ${total.lemak.round()} g lemak.',
                      style: TextStyle(fontSize: 11.5, height: 1.4, color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Satu item tebakan. Publik supaya tata letaknya bisa digambar langsung di
/// test tampilan tanpa memanggil server.
class KartuTebakan extends StatelessWidget {
  const KartuTebakan({
    super.key,
    required this.item,
    required this.dipilih,
    required this.onPilih,
    required this.onKurang,
    required this.onTambah,
    required this.onKetik,
  });

  final TebakanMakanan item;
  final bool dipilih;
  final ValueChanged<bool> onPilih;
  final VoidCallback onKurang;
  final VoidCallback onTambah;
  final VoidCallback onKetik;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final redup = TextStyle(fontSize: 11.5, color: colorScheme.onSurfaceVariant);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, AppSpacing.sm, AppSpacing.sm, AppSpacing.sm),
        child: Row(
          children: [
            Checkbox(value: dipilih, onChanged: (v) => onPilih(v ?? false)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          item.nama,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                      ),
                      if (item.kasar) ...[
                        const SizedBox(width: 6),
                        Tooltip(
                          message: 'Keyakinan ${item.yakin}% — periksa jenis dan beratnya',
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.priorityMedium.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              'kasar',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.priorityMedium,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (item.porsi.isNotEmpty)
                    Text(item.porsi, maxLines: 2, overflow: TextOverflow.ellipsis, style: redup),
                  const SizedBox(height: 2),
                  Text(
                    '${item.kalori.round()} kkal · P ${item.proteinG.round()} · '
                    'K ${item.karboG.round()} · L ${item.lemakG.round()}',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            // Berat: bagian yang paling sering meleset, jadi paling mudah diubah.
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: onKetik,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Text(
                      '${item.gram.round()} g',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Kurangi ${_kLangkahGram.round()} g',
                      visualDensity: VisualDensity.compact,
                      onPressed: item.gram <= _kLangkahGram ? null : onKurang,
                      icon: const Icon(Icons.remove_circle_outline, size: 20),
                    ),
                    IconButton(
                      tooltip: 'Tambah ${_kLangkahGram.round()} g',
                      visualDensity: VisualDensity.compact,
                      onPressed: onTambah,
                      icon: const Icon(Icons.add_circle_outline, size: 20),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Bilah bawah: waktu makan dan tombol simpan. Publik untuk test tampilan.
class BilahSimpanTebakan extends StatelessWidget {
  const BilahSimpanTebakan({
    super.key,
    required this.meal,
    required this.onMeal,
    required this.jumlah,
    required this.kalori,
    required this.menyimpan,
    required this.onSimpan,
  });

  final Meal meal;
  final ValueChanged<Meal> onMeal;
  final int jumlah;
  final double kalori;
  final bool menyimpan;
  final VoidCallback onSimpan;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
        ),
        child: Row(
          children: [
            DropdownButton<Meal>(
              value: meal,
              underline: const SizedBox.shrink(),
              items: [
                for (final m in Meal.values) DropdownMenuItem(value: m, child: Text(m.label)),
              ],
              onChanged: (m) {
                if (m != null) onMeal(m);
              },
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: FilledButton(
                onPressed: menyimpan || jumlah == 0 ? null : onSimpan,
                style: FilledButton.styleFrom(backgroundColor: _color),
                child: Text(
                  menyimpan
                      ? 'Menyimpan...'
                      : jumlah == 0
                          ? 'Pilih makanan'
                          : 'Simpan $jumlah · ${kalori.round()} kkal',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Memuat extends StatelessWidget {
  const _Memuat();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          CircularProgressIndicator(),
          SizedBox(height: AppSpacing.md),
          Text('Menaksir isi piring...'),
        ],
      ),
    );
  }
}

class _Kotak extends StatelessWidget {
  const _Kotak({required this.ikon, required this.warna, required this.teks});

  final IconData ikon;
  final Color warna;
  final String teks;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      color: warna.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(ikon, size: 18, color: warna),
            const SizedBox(width: AppSpacing.sm + 4),
            Expanded(child: Text(teks, style: const TextStyle(fontSize: 13, height: 1.4))),
          ],
        ),
      ),
    );
  }
}
