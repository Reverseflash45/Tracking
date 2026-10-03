import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/hero_header.dart';
import '../../../core/widgets/section_header.dart';
import '../data/cadangan_lokal.dart';
import '../data/export_repository.dart';
import '../domain/cadangan.dart';
import '../domain/export_file.dart';

const _color = AppColors.profile;
final _waktu = DateFormat('d MMM y, HH.mm', 'id_ID');

String _ukuran(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

/// Cadangan otomatis, ekspor manual, dan memulihkan dari berkas cadangan.
class CadanganPage extends ConsumerStatefulWidget {
  const CadanganPage({super.key});

  @override
  ConsumerState<CadanganPage> createState() => _CadanganPageState();
}

class _CadanganPageState extends ConsumerState<CadanganPage> {
  bool _sibuk = false;
  String? _status;

  void _pesan(String teks) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(teks)));
  }

  Future<void> _cadangkanSekarang() async {
    setState(() {
      _sibuk = true;
      _status = 'Mengambil data...';
    });
    try {
      final email = ref.read(currentUserProvider)?.email;
      final hasil = await ref.read(exportRepositoryProvider).buildExport(email: email);
      await ref.read(cadanganLokalProvider).simpan(hasil.json, DateTime.now());
      ref.invalidate(daftarCadanganProvider);
      _pesan('${hasil.totalRows} baris dicadangkan di HP');
    } catch (e) {
      _pesan('Gagal mencadangkan: $e');
    } finally {
      if (mounted) {
        setState(() {
          _sibuk = false;
          _status = null;
        });
      }
    }
  }

  Future<void> _bagikan(BerkasCadangan berkas) async {
    try {
      await shareExport(
        json: await berkas.file.readAsString(),
        fileName: berkas.nama,
        subject: 'Cadangan data Tracking',
      );
    } catch (e) {
      _pesan('Gagal membagikan: $e');
    }
  }

  Future<void> _hapus(BerkasCadangan berkas) async {
    try {
      await berkas.file.delete();
      ref.invalidate(daftarCadanganProvider);
    } catch (e) {
      _pesan('Gagal menghapus: $e');
    }
  }

  Future<void> _pulihkanDariBerkasLain() async {
    final PlatformFile? dipilih;
    try {
      // Bukan FileType.custom(json): sebagian pengelola berkas tidak mengenali
      // jenis JSON dan menyembunyikan berkasnya. Isinya diperiksa sesudahnya.
      dipilih = await FilePicker.pickFile(dialogTitle: 'Pilih berkas cadangan');
    } catch (e) {
      _pesan('Gagal membuka berkas: $e');
      return;
    }
    if (dipilih == null) return;
    try {
      await _pulihkan(await dipilih.xFile.readAsString());
    } catch (e) {
      _pesan('Berkas tidak bisa dibaca: $e');
    }
  }

  Future<void> _pulihkan(String isi) async {
    final userId = ref.read(currentUserProvider)?.id;
    if (userId == null) return;

    final RencanaPulihkan rencana;
    try {
      // Cadangan bisa beberapa MB; dibaca di isolate lain supaya layar tidak
      // macet.
      final json = await compute(jsonDecode, isi);
      rencana = siapkanPulihkan(json, userId: userId);
    } on CadanganTidakSah catch (e) {
      _pesan(e.pesan);
      return;
    } on FormatException {
      _pesan('Berkas ini bukan cadangan Tracking.');
      return;
    }
    if (!mounted) return;

    if (rencana.totalBaris == 0) {
      _pesan('Cadangan ini kosong.');
      return;
    }

    final lanjut = await showDialog<bool>(
      context: context,
      builder: (context) => _KonfirmasiPulihkan(
        rencana: rencana,
        emailSekarang: ref.read(currentUserProvider)?.email,
      ),
    );
    if (lanjut != true || !mounted) return;

    setState(() {
      _sibuk = true;
      _status = 'Memulihkan...';
    });
    try {
      final hasil = await ref.read(exportRepositoryProvider).pulihkan(
        rencana,
        onProgress: (tabel, selesai, total) {
          if (mounted) {
            setState(() => _status = 'Memulihkan ${labelTabel(tabel).toLowerCase()} '
                '($selesai/$total)');
          }
        },
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => _HasilPulihkanDialog(hasil: hasil),
      );
    } catch (e) {
      _pesan('Gagal memulihkan: $e');
    } finally {
      if (mounted) {
        setState(() {
          _sibuk = false;
          _status = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final daftar = ref.watch(daftarCadanganProvider);
    final otomatis = ref.watch(cadanganOtomatisAktifProvider).value ?? true;

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          HeroHeader.sub(
            title: 'Cadangan data',
            subtitle: 'Salinan seluruh catatanmu, untuk jaga-jaga',
            color: _color,
            leading: HeroIconButton(
              icon: Icons.arrow_back,
              tooltip: 'Kembali',
              onPressed: () => context.pop(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: SwitchListTile(
                    value: otomatis,
                    onChanged: (v) async {
                      await ref.read(cadanganLokalProvider).setAktif(v);
                      ref.invalidate(cadanganOtomatisAktifProvider);
                    },
                    activeThumbColor: _color,
                    title: const Text(
                      'Cadangan otomatis mingguan',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    subtitle: const Text(
                      'Disimpan di HP, $kSisakanCadangan terakhir. Tetap ada '
                      'walau server Supabase bermasalah.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                FilledButton.icon(
                  onPressed: _sibuk ? null : _cadangkanSekarang,
                  style: FilledButton.styleFrom(
                    backgroundColor: _color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  icon: _sibuk
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.backup_outlined, size: 18),
                  label: Text(_status ?? 'Cadangkan sekarang'),
                ),
                const SizedBox(height: AppSpacing.lg),
                const SectionHeader(
                  title: 'Tersimpan di HP',
                  icon: Icons.folder_outlined,
                  color: _color,
                ),
                daftar.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => Text('Gagal membaca daftar: $e'),
                  data: (list) => list.isEmpty
                      ? Card(
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: Text(
                              'Belum ada. Cadangan pertama dibuat otomatis saat '
                              'app dibuka sambil online, atau tekan tombol di atas.',
                              style: TextStyle(fontSize: 12.5, color: colorScheme.onSurfaceVariant),
                            ),
                          ),
                        )
                      : Card(
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            children: [
                              for (final berkas in list)
                                ListTile(
                                  leading: const Icon(Icons.description_outlined, color: _color),
                                  title: Text(
                                    _waktu.format(berkas.dibuat),
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                                  ),
                                  subtitle: Text(_ukuran(berkas.ukuran), style: const TextStyle(fontSize: 12)),
                                  trailing: PopupMenuButton<String>(
                                    enabled: !_sibuk,
                                    tooltip: 'Pilihan',
                                    onSelected: (aksi) async {
                                      switch (aksi) {
                                        case 'simpan':
                                          await _bagikan(berkas);
                                        case 'pulihkan':
                                          await _pulihkan(await berkas.file.readAsString());
                                        case 'hapus':
                                          await _hapus(berkas);
                                      }
                                    },
                                    itemBuilder: (context) => const [
                                      PopupMenuItem(
                                        value: 'simpan',
                                        child: Text('Simpan ke Drive / folder lain'),
                                      ),
                                      PopupMenuItem(value: 'pulihkan', child: Text('Pulihkan')),
                                      PopupMenuItem(value: 'hapus', child: Text('Hapus')),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Folder ini ikut terhapus kalau app di-uninstall. Simpan salinan '
                  'ke Google Drive sesekali lewat menu titik tiga.',
                  style: TextStyle(fontSize: 11.5, height: 1.4, color: colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: AppSpacing.lg),
                const SectionHeader(
                  title: 'Pulihkan',
                  icon: Icons.settings_backup_restore,
                  color: _color,
                ),
                OutlinedButton.icon(
                  onPressed: _sibuk ? null : _pulihkanDariBerkasLain,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _color,
                    side: const BorderSide(color: _color),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  icon: const Icon(Icons.file_open_outlined, size: 18),
                  label: const Text('Pilih berkas cadangan...'),
                ),
                const SizedBox(height: 6),
                Text(
                  'Memulihkan menggabungkan isi cadangan ke datamu sekarang: baris '
                  'di cadangan ditulis ulang, data yang lebih baru tidak dihapus. '
                  'Foto (progres, lampiran dokumen) tidak ikut dalam cadangan.',
                  style: TextStyle(fontSize: 11.5, height: 1.4, color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _KonfirmasiPulihkan extends StatelessWidget {
  const _KonfirmasiPulihkan({required this.rencana, required this.emailSekarang});

  final RencanaPulihkan rencana;
  final String? emailSekarang;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final akunLain = rencana.email != null &&
        emailSekarang != null &&
        rencana.email!.toLowerCase() != emailSekarang!.toLowerCase();

    return AlertDialog(
      title: const Text('Pulihkan cadangan?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (rencana.exportedAt != null)
              Text(
                'Dibuat ${_waktu.format(rencana.exportedAt!)}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            const SizedBox(height: 8),
            for (final entry in rencana.perTabel.entries)
              Text('${labelTabel(entry.key)}: ${entry.value.length}', style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 10),
            Text(
              'Total ${rencana.totalBaris} baris. Catatan yang sama ditimpa versi '
              'cadangan; yang lebih baru tetap ada.',
              style: TextStyle(fontSize: 12.5, color: colorScheme.onSurfaceVariant),
            ),
            if (akunLain) ...[
              const SizedBox(height: 10),
              Text(
                'Cadangan ini dari akun ${rencana.email}. Isinya akan menjadi '
                'milik akun yang sedang login.',
                style: TextStyle(fontSize: 12.5, color: colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(backgroundColor: _color, foregroundColor: Colors.white),
          child: const Text('Pulihkan'),
        ),
      ],
    );
  }
}

class _HasilPulihkanDialog extends StatelessWidget {
  const _HasilPulihkanDialog({required this.hasil});

  final HasilPulihkan hasil;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Selesai'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${hasil.totalDipulihkan} baris dipulihkan.'),
            if (hasil.totalGagal > 0) ...[
              const SizedBox(height: 8),
              Text(
                '${hasil.totalGagal} baris dilewati karena bentrok dengan data yang '
                'sudah ada:',
                style: TextStyle(color: colorScheme.error),
              ),
              for (final entry in hasil.gagal.entries)
                Text('${labelTabel(entry.key)}: ${entry.value}', style: const TextStyle(fontSize: 13)),
            ],
            const SizedBox(height: 10),
            Text(
              'Tutup lalu buka lagi app supaya semua halaman memuat data yang '
              'dipulihkan.',
              style: TextStyle(fontSize: 12.5, color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          style: FilledButton.styleFrom(backgroundColor: _color, foregroundColor: Colors.white),
          child: const Text('Oke'),
        ),
      ],
    );
  }
}
