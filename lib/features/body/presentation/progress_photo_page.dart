import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/hero_header.dart';
import '../data/body_repository.dart';
import '../data/progress_photo_repository.dart';

const _color = AppColors.workout;
final _dateFormat = DateFormat('d MMM y', 'id_ID');

/// Foto progres badan, dengan mode banding dua foto.
///
/// Grafik berat badan cuma bilang angkanya turun. Dua foto berdampingan
/// menunjukkan hal yang tidak bisa ditunjukkan angka mana pun — dan itu yang
/// bikin orang bertahan waktu timbangannya sedang mandek.
class ProgressPhotoPage extends ConsumerStatefulWidget {
  const ProgressPhotoPage({super.key});

  @override
  ConsumerState<ProgressPhotoPage> createState() => _ProgressPhotoPageState();
}

class _ProgressPhotoPageState extends ConsumerState<ProgressPhotoPage> {
  bool _modeBanding = false;
  final Set<String> _dipilih = {};
  bool _mengunggah = false;

  Future<void> _tambah({required bool dariKamera}) async {
    final userId = ref.read(currentUserProvider)?.id;
    if (userId == null) return;

    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: dariKamera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 1440,
      imageQuality: 85,
    );
    if (file == null || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _mengunggah = true);
    try {
      // Berat terakhir yang tercatat ikut disimpan supaya fotonya punya angka
      // pendamping tanpa perlu mengetik ulang.
      final berat = ref.read(currentWeightProvider).value;
      await ref.read(progressPhotoRepositoryProvider).addPhoto(
            userId: userId,
            file: file,
            takenOn: DateTime.now(),
            weightKg: berat,
          );
      ref.invalidate(progressPhotosProvider);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Gagal mengunggah: $e')));
    } finally {
      if (mounted) setState(() => _mengunggah = false);
    }
  }

  Future<void> _pilihSumber() async {
    final dariKamera = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined, color: _color),
              title: const Text('Foto sekarang'),
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
    if (dariKamera != null) await _tambah(dariKamera: dariKamera);
  }

  void _toggleBanding() {
    setState(() {
      _modeBanding = !_modeBanding;
      _dipilih.clear();
    });
  }

  void _pilih(ProgressPhoto photo) {
    setState(() {
      if (_dipilih.contains(photo.id)) {
        _dipilih.remove(photo.id);
      } else {
        // Dibatasi dua: membandingkan tiga foto berdampingan di layar HP
        // membuat semuanya terlalu kecil untuk dilihat bedanya.
        if (_dipilih.length >= 2) _dipilih.remove(_dipilih.first);
        _dipilih.add(photo.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final photos = ref.watch(progressPhotosProvider).value ?? const <ProgressPhoto>[];
    final terpilih = photos.where((p) => _dipilih.contains(p.id)).toList()
      ..sort((a, b) => a.takenOn.compareTo(b.takenOn));

    return Scaffold(
      floatingActionButton: _modeBanding
          ? null
          : FloatingActionButton.extended(
              onPressed: _mengunggah ? null : _pilihSumber,
              backgroundColor: _color,
              foregroundColor: Colors.white,
              icon: _mengunggah
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.add_a_photo_outlined),
              label: Text(_mengunggah ? 'Mengunggah...' : 'Foto'),
            ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(progressPhotosProvider),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            HeroHeader(
              title: 'Foto Progres',
              subtitle: _modeBanding
                  ? 'Pilih dua foto untuk dibandingkan'
                  : '${photos.length} foto tersimpan',
              color: _color,
              leading: HeroIconButton(
                icon: Icons.arrow_back,
                tooltip: 'Kembali',
                onPressed: () => context.pop(),
              ),
              trailing: photos.length < 2
                  ? null
                  : HeroIconButton(
                      icon: _modeBanding ? Icons.close : Icons.compare_arrows,
                      tooltip: _modeBanding ? 'Selesai' : 'Bandingkan',
                      onPressed: _toggleBanding,
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                96,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _CatatanPrivasi(),
                  const SizedBox(height: AppSpacing.md),
                  if (_modeBanding && terpilih.length == 2) ...[
                    _Perbandingan(kiri: terpilih.first, kanan: terpilih.last),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  if (photos.isEmpty)
                    const EmptyState(
                      icon: Icons.photo_camera_outlined,
                      title: 'Belum ada foto',
                      subtitle: 'Ambil satu tiap bulan di pose dan pencahayaan '
                          'yang sama supaya bedanya benar-benar kelihatan',
                      color: _color,
                    )
                  else
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 6,
                        mainAxisSpacing: 6,
                        childAspectRatio: 0.72,
                      ),
                      itemCount: photos.length,
                      itemBuilder: (context, index) {
                        final photo = photos[index];
                        return _PhotoTile(
                          photo: photo,
                          dipilih: _dipilih.contains(photo.id),
                          modeBanding: _modeBanding,
                          onTap: () => _modeBanding
                              ? _pilih(photo)
                              : _bukaDetail(context, ref, photo),
                        );
                      },
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

class _CatatanPrivasi extends StatelessWidget {
  const _CatatanPrivasi();

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
            Icon(Icons.lock_outline, size: 16, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Foto di sini disimpan di ruang privat — beda dari foto profil '
                'yang bisa dilihat lewat tautan. Hanya akunmu yang bisa '
                'membukanya.',
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

class _PhotoTile extends ConsumerWidget {
  const _PhotoTile({
    required this.photo,
    required this.dipilih,
    required this.modeBanding,
    required this.onTap,
  });

  final ProgressPhoto photo;
  final bool dipilih;
  final bool modeBanding;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: dipilih ? Border.all(color: _color, width: 3) : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _PhotoImage(storagePath: photo.storagePath),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                color: Colors.black.withValues(alpha: 0.55),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _dateFormat.format(photo.takenOn),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (photo.weightKg != null)
                      Text(
                        '${photo.weightKg!.toStringAsFixed(1)} kg',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (modeBanding)
              Positioned(
                top: 4,
                right: 4,
                child: Icon(
                  dipilih ? Icons.check_circle : Icons.circle_outlined,
                  size: 18,
                  color: dipilih ? _color : colorScheme.surface,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Gambar dari tautan bertanda tangan.
class _PhotoImage extends ConsumerWidget {
  const _PhotoImage({required this.storagePath});

  final String storagePath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final url = ref.watch(signedPhotoUrlProvider(storagePath));

    return url.when(
      data: (value) => Image.network(
        value,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) => Container(
          color: colorScheme.surfaceContainerHighest,
          child: Icon(Icons.broken_image_outlined,
              size: 20, color: colorScheme.onSurfaceVariant),
        ),
      ),
      loading: () => Container(color: colorScheme.surfaceContainerHighest),
      error: (error, stack) => Container(
        color: colorScheme.surfaceContainerHighest,
        child: Icon(Icons.cloud_off, size: 20, color: colorScheme.onSurfaceVariant),
      ),
    );
  }
}

class _Perbandingan extends StatelessWidget {
  const _Perbandingan({required this.kiri, required this.kanan});

  final ProgressPhoto kiri;
  final ProgressPhoto kanan;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final jarakHari = kanan.takenOn.difference(kiri.takenOn).inDays;

    final beratKiri = kiri.weightKg;
    final beratKanan = kanan.weightKg;
    final selisihBerat =
        (beratKiri != null && beratKanan != null) ? beratKanan - beratKiri : null;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _SisiBanding(photo: kiri, label: 'Sebelum')),
                const SizedBox(width: 6),
                Expanded(child: _SisiBanding(photo: kanan, label: 'Sesudah')),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              [
                'Selisih $jarakHari hari',
                if (selisihBerat != null)
                  '${selisihBerat >= 0 ? '+' : ''}'
                      '${selisihBerat.toStringAsFixed(1)} kg',
              ].join('  ·  '),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SisiBanding extends StatelessWidget {
  const _SisiBanding({required this.photo, required this.label});

  final ProgressPhoto photo;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        AspectRatio(
          aspectRatio: 0.72,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: _PhotoImage(storagePath: photo.storagePath),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _dateFormat.format(photo.takenOn),
          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600),
        ),
        if (photo.weightKg != null)
          Text(
            '${photo.weightKg!.toStringAsFixed(1)} kg',
            style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant),
          ),
      ],
    );
  }
}

Future<void> _bukaDetail(
  BuildContext context,
  WidgetRef ref,
  ProgressPhoto photo,
) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.6,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _PhotoImage(storagePath: photo.storagePath),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              [
                _dateFormat.format(photo.takenOn),
                if (photo.weightKg != null)
                  '${photo.weightKg!.toStringAsFixed(1)} kg',
              ].join('  ·  '),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            const SizedBox(height: AppSpacing.sm),
            Consumer(
              builder: (context, ref, _) => TextButton.icon(
                onPressed: () async {
                  final navigator = Navigator.of(context);
                  await ref
                      .read(progressPhotoRepositoryProvider)
                      .deletePhoto(photo);
                  ref.invalidate(progressPhotosProvider);
                  navigator.pop();
                },
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Hapus foto'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
