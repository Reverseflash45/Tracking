import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/hero_header.dart';
import '../data/note_repository.dart';
import '../domain/note.dart';

const _color = AppColors.note;
final _tanggal = DateFormat('d MMM y', 'id_ID');
final _jam = DateFormat('HH:mm', 'id_ID');

/// Daftar catatan bebas.
class NotePage extends ConsumerStatefulWidget {
  const NotePage({super.key});

  @override
  ConsumerState<NotePage> createState() => _NotePageState();
}

class _NotePageState extends ConsumerState<NotePage> {
  final _cari = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _cari.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final catatanAsync = ref.watch(notesProvider);
    final semua = urutkanCatatan(catatanAsync.value ?? const []);
    final tampil = cariCatatan(semua, _query);
    final disematkan = semua.where((n) => n.pinned).length;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/notes/new'),
        backgroundColor: _color,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Catatan'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(notesProvider),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            HeroHeader.sub(
              title: 'Catatan',
              subtitle: 'Apa pun yang perlu diingat',
              color: _color,
              leading: HeroIconButton(
                icon: Icons.arrow_back,
                tooltip: 'Kembali',
                onPressed: () => context.pop(),
              ),
              stats: [
                HeroStatData(
                  icon: Icons.sticky_note_2_outlined,
                  value: '${semua.length}',
                  label: 'Catatan',
                ),
                HeroStatData(
                  icon: Icons.push_pin_outlined,
                  value: '$disematkan',
                  label: 'Disematkan',
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: TextField(
                controller: _cari,
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: 'Cari judul atau isi',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close),
                          tooltip: 'Hapus pencarian',
                          onPressed: () {
                            _cari.clear();
                            setState(() => _query = '');
                          },
                        ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, 96),
              child: catatanAsync.when(
                data: (_) {
                  if (tampil.isEmpty) {
                    return EmptyState(
                      icon: _query.isEmpty ? Icons.sticky_note_2_outlined : Icons.search_off,
                      title: _query.isEmpty ? 'Belum ada catatan' : 'Tidak ada yang cocok',
                      subtitle: _query.isEmpty
                          ? 'Password wifi, nomor rekening teman, ide tugas akhir — '
                              'apa pun yang tidak berbentuk tugas'
                          : 'Coba kata lain',
                      color: _color,
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final (i, note) in tampil.indexed) ...[
                        // Garis pemisah tipis begitu bagian yang disematkan
                        // habis, supaya urutannya kebaca sebagai dua kelompok
                        // dan bukan sebagai urutan yang kacau.
                        if (i > 0 && tampil[i - 1].pinned && !note.pinned)
                          Padding(
                            padding: const EdgeInsets.only(
                              top: AppSpacing.xs,
                              bottom: AppSpacing.sm,
                            ),
                            child: Row(
                              children: [
                                Text(
                                  'Lainnya',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(child: Divider(height: 1, color: colorScheme.outlineVariant)),
                              ],
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: _KartuCatatan(note: note),
                        ),
                      ],
                    ],
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, stackTrace) => EmptyState(
                  icon: Icons.error_outline,
                  title: 'Gagal memuat catatan',
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

class _KartuCatatan extends ConsumerWidget {
  const _KartuCatatan({required this.note});

  final Note note;

  /// Jam untuk yang hari ini, tanggal untuk yang lebih lama. Jam pada catatan
  /// bulan lalu tidak memberi tahu apa-apa, dan tanggal pada catatan yang baru
  /// ditulis lima menit lalu juga tidak.
  String _waktu() {
    final kini = DateTime.now();
    final sama = note.updatedAt.year == kini.year &&
        note.updatedAt.month == kini.month &&
        note.updatedAt.day == kini.day;
    return sama ? _jam.format(note.updatedAt) : _tanggal.format(note.updatedAt);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final cuplikan = note.cuplikan;

    return Dismissible(
      key: ValueKey(note.id),
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
          title: const Text('Hapus catatan?'),
          content: Text('"${note.judul}" akan dihapus.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hapus')),
          ],
        ),
      ),
      onDismissed: (_) async {
        final messenger = ScaffoldMessenger.of(context);
        try {
          await ref.read(noteRepositoryProvider).hapus(note.id);
        } catch (error) {
          messenger.showSnackBar(SnackBar(content: Text('Gagal menghapus: $error')));
        }
        ref.invalidate(notesProvider);
      },
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/notes/${note.id}'),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm + 2,
              AppSpacing.xs,
              AppSpacing.sm + 2,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        note.judul,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                      if (cuplikan.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          cuplikan,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.35,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        _waktu(),
                        style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: note.pinned ? 'Lepas sematan' : 'Sematkan ke atas',
                  icon: Icon(
                    note.pinned ? Icons.push_pin : Icons.push_pin_outlined,
                    size: 18,
                    color: note.pinned ? _color : colorScheme.onSurfaceVariant,
                  ),
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      await ref.read(noteRepositoryProvider).sematkan(note.id, !note.pinned);
                    } catch (error) {
                      messenger.showSnackBar(
                        SnackBar(content: Text('Gagal menyematkan: $error')),
                      );
                      return;
                    }
                    ref.invalidate(notesProvider);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
