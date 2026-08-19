import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/hero_header.dart';
import '../../../core/widgets/save_bar.dart';
import '../data/note_repository.dart';
import '../domain/note.dart';

const _color = AppColors.note;
final _lengkap = DateFormat('d MMM y, HH:mm', 'id_ID');

/// Menulis satu catatan.
class NoteEditorPage extends ConsumerStatefulWidget {
  const NoteEditorPage({super.key, this.noteId});

  /// Null berarti catatan baru.
  final String? noteId;

  @override
  ConsumerState<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends ConsumerState<NoteEditorPage> {
  final _judul = TextEditingController();
  final _isi = TextEditingController();

  /// Id catatan yang sedang ditulis. Berubah dari null ke id sungguhan begitu
  /// catatan baru tersimpan sekali, supaya menyimpan dua kali tidak melahirkan
  /// dua catatan yang isinya sama.
  String? _id;

  String _judulTersimpan = '';
  String _isiTersimpan = '';
  bool _menyimpan = false;
  bool _terisi = false;
  DateTime? _diubah;

  bool get _berubah =>
      _judul.text != _judulTersimpan || _isi.text != _isiTersimpan;

  @override
  void initState() {
    super.initState();
    _id = widget.noteId;
    if (_id != null) {
      final note = _cari(ref.read(notesProvider).value);
      if (note != null) _isikan(note);
    }
  }

  @override
  void dispose() {
    _judul.dispose();
    _isi.dispose();
    super.dispose();
  }

  Note? _cari(List<Note>? catatan) {
    if (catatan == null) return null;
    for (final note in catatan) {
      if (note.id == widget.noteId) return note;
    }
    return null;
  }

  void _isikan(Note note) {
    _judul.text = note.title ?? '';
    _isi.text = note.body;
    _judulTersimpan = _judul.text;
    _isiTersimpan = _isi.text;
    _diubah = note.updatedAt;
    _terisi = true;
  }

  Future<bool> _simpan() async {
    final userId = ref.read(currentUserProvider)?.id;
    if (userId == null) return false;

    final judul = _judul.text;
    final isi = _isi.text;

    // Catatan kosong tidak disimpan. Membuka form lalu berubah pikiran adalah
    // hal biasa, dan itu tidak seharusnya meninggalkan baris kosong di daftar.
    if (judul.trim().isEmpty && isi.trim().isEmpty) {
      if (_id == null) return true;
    }

    setState(() => _menyimpan = true);
    try {
      final repo = ref.read(noteRepositoryProvider);
      if (_id case final id?) {
        await repo.perbarui(id: id, title: judul, body: isi);
      } else {
        _id = await repo.buat(userId: userId, title: judul, body: isi);
      }
      ref.invalidate(notesProvider);

      if (mounted) {
        setState(() {
          _judulTersimpan = judul;
          _isiTersimpan = isi;
          _diubah = DateTime.now();
          _menyimpan = false;
        });
      }
      return true;
    } catch (error) {
      if (!mounted) return false;
      setState(() => _menyimpan = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Gagal menyimpan: $error')));
      return false;
    }
  }

  /// Ditanyakan saat keluar dengan perubahan yang belum tersimpan.
  ///
  /// Catatan ditulis sambil lalu, dan tombol kembali di Android satu ketukan
  /// dari mana saja — tanpa penjaga ini satu ketukan salah menghapus semua yang
  /// baru saja diketik.
  Future<void> _keluar() async {
    if (!_berubah) {
      if (mounted) context.pop();
      return;
    }

    final pilihan = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Simpan catatan?'),
        content: const Text('Ada perubahan yang belum disimpan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'batal'),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'buang'),
            child: const Text('Buang'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'simpan'),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    if (!mounted || pilihan == null || pilihan == 'batal') return;
    if (pilihan == 'buang') {
      context.pop();
      return;
    }
    if (await _simpan() && mounted) context.pop();
  }

  Future<void> _hapus() async {
    final id = _id;
    if (id == null) {
      if (mounted) context.pop();
      return;
    }

    final yakin = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus catatan?'),
        content: const Text('Catatan ini akan dihapus.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hapus')),
        ],
      ),
    );
    if (yakin != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(noteRepositoryProvider).hapus(id);
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('Gagal menghapus: $error')));
      return;
    }
    ref.invalidate(notesProvider);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Kalau halaman dibuka langsung tanpa lewat daftar, datanya baru tiba
    // belakangan.
    if (widget.noteId != null) {
      ref.listen(notesProvider, (previous, next) {
        if (_terisi) return;
        final note = _cari(next.value);
        if (note != null) setState(() => _isikan(note));
      });
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _keluar();
      },
      child: Scaffold(
        body: Column(
          children: [
            HeroHeader.sub(
              title: widget.noteId == null ? 'Catatan Baru' : 'Catatan',
              subtitle: _diubah == null
                  ? 'Judul boleh dikosongkan'
                  : 'Diubah ${_lengkap.format(_diubah!)}',
              color: _color,
              leading: HeroIconButton(
                icon: Icons.arrow_back,
                tooltip: 'Kembali',
                onPressed: _keluar,
              ),
              trailing: HeroIconButton(
                icon: Icons.delete_outline,
                tooltip: 'Hapus catatan',
                onPressed: _hapus,
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _judul,
                      textCapitalization: TextCapitalization.sentences,
                      onChanged: (_) => setState(() {}),
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                      decoration: InputDecoration(
                        hintText: 'Judul (opsional)',
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                        hintStyle: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                    Divider(height: 1, color: colorScheme.outlineVariant),
                    // Isinya memenuhi sisa layar, bukan kotak setinggi empat
                    // baris. Ini satu-satunya tempat di app yang isinya memang
                    // tidak punya panjang yang diharapkan.
                    Expanded(
                      child: TextField(
                        controller: _isi,
                        textCapitalization: TextCapitalization.sentences,
                        onChanged: (_) => setState(() {}),
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        keyboardType: TextInputType.multiline,
                        style: const TextStyle(fontSize: 15, height: 1.5),
                        decoration: const InputDecoration(
                          hintText: 'Tulis apa saja...',
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: SaveBar(
          color: _color,
          saving: _menyimpan,
          label: _berubah ? 'Simpan' : 'Tersimpan',
          onPressed: _berubah ? _simpan : () => context.pop(),
        ),
      ),
    );
  }
}
