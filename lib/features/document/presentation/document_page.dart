import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/hero_header.dart';
import '../data/document_repository.dart';
import '../domain/document.dart';

const _color = AppColors.document;
final _tanggalFormat = DateFormat('d MMM y', 'id_ID');

class DocumentPage extends ConsumerWidget {
  const DocumentPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docsAsync = ref.watch(documentsProvider);
    final now = DateTime.now();
    final ringkasan = ringkasDokumen(docsAsync.value ?? const [], now: now);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _bukaForm(context, ref),
        backgroundColor: _color,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Dokumen'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(documentsProvider),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            HeroHeader.sub(
              title: 'Dokumen',
              subtitle: 'Masa berlaku dan nomornya',
              color: _color,
              leading: HeroIconButton(
                icon: Icons.arrow_back,
                tooltip: 'Kembali',
                onPressed: () => context.pop(),
              ),
              stats: [
                HeroStatData(
                  icon: Icons.folder_outlined,
                  value: '${ringkasan.total}',
                  label: 'Tersimpan',
                ),
                HeroStatData(
                  icon: Icons.error_outline,
                  value: '${ringkasan.lewat}',
                  label: 'Kedaluwarsa',
                ),
                HeroStatData(
                  icon: Icons.schedule,
                  value: '${ringkasan.segera}',
                  label: 'Segera Habis',
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 96),
              child: docsAsync.when(
                data: (items) => items.isEmpty
                    ? const EmptyState(
                        icon: Icons.folder_outlined,
                        title: 'Belum ada dokumen',
                        subtitle: 'Catat SIM, paspor, BPJS, dan yang lain. '
                            'Sekali diisi, masa berlakunya diingat '
                            'bertahun-tahun tanpa kamu sentuh lagi.',
                        color: _color,
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (ringkasan.belumDiisi > 0)
                            _Catatan(
                              '${ringkasan.belumDiisi} dokumen belum diisi masa '
                              'berlakunya, jadi hitungan di atas belum lengkap.',
                            ),
                          const _CatatanKeamanan(),
                          for (final doc in items)
                            Padding(
                              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                              child: _KartuDokumen(doc: doc, now: now),
                            ),
                        ],
                      ),
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, _) => EmptyState(
                  icon: Icons.error_outline,
                  title: 'Gagal memuat dokumen',
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

class _Catatan extends StatelessWidget {
  const _Catatan(this.teks, {this.icon = Icons.info_outline});

  final String teks;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(AppTheme.radius),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 15, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                teks,
                style: TextStyle(
                  fontSize: 12,
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

/// Ditulis sekali di atas daftar, bukan disembunyikan di halaman bantuan.
///
/// Halaman ini memuat nomor KTP dan SIM, dan app-nya belum punya kunci sendiri.
/// Menyimpan hal seperti itu tanpa mengatakan batasnya sama saja menjanjikan
/// pengamanan yang tidak ada.
class _CatatanKeamanan extends StatelessWidget {
  const _CatatanKeamanan();

  @override
  Widget build(BuildContext context) {
    return const _Catatan(
      'Nomor ditampilkan tersamar dan baru terbaca penuh kalau ditekan. Tapi '
      'app ini belum punya kunci PIN atau sidik jari — siapa pun yang memegang '
      'HP-mu dalam keadaan terbuka bisa membukanya.',
      icon: Icons.lock_outline,
    );
  }
}

class _KartuDokumen extends ConsumerStatefulWidget {
  const _KartuDokumen({required this.doc, required this.now});

  final Document doc;
  final DateTime now;

  @override
  ConsumerState<_KartuDokumen> createState() => _KartuDokumenState();
}

class _KartuDokumenState extends ConsumerState<_KartuDokumen> {
  bool _terbuka = false;

  @override
  Widget build(BuildContext context) {
    final doc = widget.doc;
    final now = widget.now;
    final colorScheme = Theme.of(context).colorScheme;
    final status = doc.status(now);
    final sisa = doc.sisaHari(now);

    final warna = switch (status) {
      StatusDokumen.lewat => AppColors.priorityHigh,
      StatusDokumen.segera => AppColors.priorityMedium,
      _ => colorScheme.onSurfaceVariant,
    };

    return Dismissible(
      key: ValueKey(doc.id),
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
          title: const Text('Hapus dokumen?'),
          content: Text('"${doc.name}" akan dihapus dari daftar.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hapus')),
          ],
        ),
      ),
      onDismissed: (_) async {
        await ref.read(documentRepositoryProvider).deleteDocument(doc.id);
        ref.invalidate(documentsProvider);
      },
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _bukaForm(context, ref, doc: doc),
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
                      child: Icon(doc.kind.icon, size: 16, color: _color),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            doc.name,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            doc.kind.label,
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      switch (status) {
                        StatusDokumen.lewat => 'lewat ${-sisa!} hari',
                        StatusDokumen.segera => '$sisa hari lagi',
                        StatusDokumen.aman => _tanggalFormat.format(doc.expiresOn!),
                        StatusDokumen.tanpaTempo => 'seumur hidup',
                        StatusDokumen.belumDiisi => 'belum diisi',
                      },
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: warna,
                      ),
                    ),
                  ],
                ),
                if (doc.number case final nomor? when nomor.trim().isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _terbuka ? nomor : nomorTersamar(nomor),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          _terbuka ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          size: 18,
                        ),
                        tooltip: _terbuka ? 'Sembunyikan' : 'Tampilkan',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => setState(() => _terbuka = !_terbuka),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy_outlined, size: 17),
                        tooltip: 'Salin',
                        visualDensity: VisualDensity.compact,
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: nomor.trim()));
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Nomor disalin')),
                          );
                        },
                      ),
                    ],
                  ),
                ],
                if (doc.pasporMepet(now)) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Masa berlakunya tinggal kurang dari $kBulanPasporAman bulan. '
                    'Masih sah di sini, tapi banyak negara menolak paspor '
                    'sependek itu di konter check-in.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: AppColors.priorityMedium,
                    ),
                  ),
                ],
                if (doc.note case final catatan? when catatan.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    catatan,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _bukaForm(BuildContext context, WidgetRef ref, {Document? doc}) async {
  final tersimpan = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _SheetDokumen(doc: doc),
  );
  if (tersimpan == true) ref.invalidate(documentsProvider);
}

class _SheetDokumen extends ConsumerStatefulWidget {
  const _SheetDokumen({this.doc});

  final Document? doc;

  @override
  ConsumerState<_SheetDokumen> createState() => _SheetDokumenState();
}

class _SheetDokumenState extends ConsumerState<_SheetDokumen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _numberController;
  late final TextEditingController _noteController;

  late DocKind _kind;
  DateTime? _terbit;
  DateTime? _tempo;
  late bool _seumurHidup;
  bool _saving = false;

  bool get _isEdit => widget.doc != null;

  @override
  void initState() {
    super.initState();
    final doc = widget.doc;
    _nameController = TextEditingController(text: doc?.name ?? '');
    _numberController = TextEditingController(text: doc?.number ?? '');
    _noteController = TextEditingController(text: doc?.note ?? '');
    _kind = doc?.kind ?? DocKind.sim;
    _terbit = doc?.issuedOn;
    _tempo = doc?.expiresOn;
    _seumurHidup = doc?.noExpiry ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _numberController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pilihTanggal({required bool terbit}) async {
    final sekarang = DateTime.now();
    final awal = (terbit ? _terbit : _tempo) ?? sekarang;

    final hasil = await showDatePicker(
      context: context,
      initialDate: awal,
      firstDate: DateTime(sekarang.year - 30),
      lastDate: DateTime(sekarang.year + 30),
      helpText: terbit ? 'Tanggal terbit' : 'Berlaku sampai',
    );
    if (hasil == null) return;

    setState(() {
      if (terbit) {
        _terbit = hasil;
        // Tanggal kedaluwarsa diisikan otomatis hanya kalau masih kosong.
        // Menimpa tanggal yang sudah kamu ketik sendiri dengan patokan umum
        // akan menghapus koreksi yang justru lebih benar.
        if (_tempo == null && !_seumurHidup) {
          _tempo = perkiraanKedaluwarsa(_kind, hasil);
        }
      } else {
        _tempo = hasil;
      }
    });
  }

  Future<void> _simpan() async {
    if (!_formKey.currentState!.validate()) return;

    final userId = ref.read(currentUserProvider)?.id;
    if (userId == null) return;

    setState(() => _saving = true);
    try {
      final nomor = _numberController.text.trim();
      final catatan = _noteController.text.trim();

      await ref.read(documentRepositoryProvider).saveDocument(
            userId: userId,
            id: widget.doc?.id,
            name: _nameController.text.trim(),
            kind: _kind,
            number: nomor.isEmpty ? null : nomor,
            issuedOn: _terbit,
            expiresOn: _tempo,
            noExpiry: _seumurHidup,
            note: catatan.isEmpty ? null : catatan,
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
    final colorScheme = Theme.of(context).colorScheme;

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
                _isEdit ? 'Edit Dokumen' : 'Dokumen Baru',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<DocKind>(
                initialValue: _kind,
                decoration: const InputDecoration(
                  labelText: 'Jenis',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: [
                  for (final kind in DocKind.values)
                    DropdownMenuItem(
                      value: kind,
                      child: Row(
                        children: [
                          Icon(kind.icon, size: 16),
                          const SizedBox(width: AppSpacing.sm),
                          Text(kind.label),
                        ],
                      ),
                    ),
                ],
                onChanged: (nilai) => setState(() => _kind = nilai ?? _kind),
              ),
              if (_kind.masaBerlakuTahun case final tahun?) ...[
                const SizedBox(height: 6),
                Text(
                  'Umumnya berlaku $tahun tahun. Tanggal kedaluwarsanya diisikan '
                  'otomatis begitu kamu memilih tanggal terbit, dan tetap bisa '
                  'kamu ubah.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _nameController,
                autofocus: !_isEdit,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nama',
                  hintText: 'Misal: SIM C',
                  prefixIcon: Icon(Icons.label_outline),
                ),
                validator: (value) =>
                    (value == null || value.trim().isEmpty) ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _numberController,
                decoration: const InputDecoration(
                  labelText: 'Nomor',
                  hintText: 'boleh kosong',
                  prefixIcon: Icon(Icons.pin_outlined),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _PilihTanggal(
                label: 'Tanggal terbit',
                icon: Icons.event_outlined,
                tanggal: _terbit,
                onTap: () => _pilihTanggal(terbit: true),
                onHapus: _terbit == null ? null : () => setState(() => _terbit = null),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (!_seumurHidup)
                _PilihTanggal(
                  label: 'Berlaku sampai',
                  icon: Icons.event_busy_outlined,
                  tanggal: _tempo,
                  onTap: () => _pilihTanggal(terbit: false),
                  onHapus: _tempo == null ? null : () => setState(() => _tempo = null),
                ),
              CheckboxListTile(
                value: _seumurHidup,
                onChanged: (nilai) => setState(() {
                  _seumurHidup = nilai ?? false;
                  if (_seumurHidup) _tempo = null;
                }),
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text(
                  'Tidak punya masa berlaku',
                  style: TextStyle(fontSize: 14),
                ),
                subtitle: const Text(
                  'KTP dan NPWP, misalnya. Beda dari sekadar belum diisi.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: _noteController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Catatan',
                  hintText: 'Disimpan di mana, syarat perpanjangannya apa',
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

class _PilihTanggal extends StatelessWidget {
  const _PilihTanggal({
    required this.label,
    required this.icon,
    required this.tanggal,
    required this.onTap,
    this.onHapus,
  });

  final String label;
  final IconData icon;
  final DateTime? tanggal;
  final VoidCallback onTap;
  final VoidCallback? onHapus;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radius),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          suffixIcon: onHapus == null
              ? null
              : IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: 'Kosongkan',
                  onPressed: onHapus,
                ),
        ),
        child: Text(
          tanggal == null ? 'Belum diisi' : _tanggalFormat.format(tanggal!),
          style: TextStyle(
            fontSize: 14,
            color: tanggal == null ? colorScheme.onSurfaceVariant : null,
          ),
        ),
      ),
    );
  }
}
