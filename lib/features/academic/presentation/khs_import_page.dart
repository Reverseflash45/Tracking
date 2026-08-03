import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ocr/text_scanner.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/hero_header.dart';
import '../../../core/widgets/save_bar.dart';
import '../data/academic_repository.dart';
import '../domain/grade.dart';
import '../domain/khs_parser.dart';
import 'academic_providers.dart';
import 'grade_providers.dart';

const _color = AppColors.academic;

class KhsImportPage extends ConsumerStatefulWidget {
  const KhsImportPage({super.key});

  @override
  ConsumerState<KhsImportPage> createState() => _KhsImportPageState();
}

class _KhsImportPageState extends ConsumerState<KhsImportPage> {
  List<KhsEntry> _entries = [];
  final Set<int> _selected = {};

  final _semesterController = TextEditingController();
  GradeScale? _skalaTertebak;
  String? _rawText;
  bool _scanning = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _semesterController.dispose();
    super.dispose();
  }

  Future<void> _scan({required bool fromCamera}) async {
    setState(() {
      _scanning = true;
      _error = null;
    });

    final hasil = await scanTextFromPhoto(fromCamera: fromCamera);
    if (!mounted) return;

    if (hasil.gagal) {
      setState(() {
        _scanning = false;
        _error = hasil.error == 'Batal' ? null : hasil.error;
      });
      return;
    }

    final entries = parseKhs(hasil.text);
    final semester = findSemester(hasil.text);

    setState(() {
      _scanning = false;
      _rawText = hasil.text;
      _entries = entries;
      _skalaTertebak = tebakSkala(entries);
      // Baris yang nilainya belum terbaca tidak ikut tercentang: yang tersimpan
      // harus yang sudah pasti.
      _selected
        ..clear()
        ..addAll([
          for (var i = 0; i < entries.length; i++)
            if (entries[i].terbaca) i,
        ]);
      // Semester yang sudah kamu ketik tidak ditimpa tebakan.
      if (semester != null && _semesterController.text.trim().isEmpty) {
        _semesterController.text = semester;
      }
      if (entries.isEmpty) {
        _error = 'Tidak ada baris nilai yang terbaca. Pastikan kolom sks, '
            'nilai, dan bobot terlihat jelas di foto.';
      }
    });
  }

  /// Baris yang nilainya atau sks-nya belum lengkap.
  int get _perluDiisi => _entries.where((e) => e.perluDiisi).length;

  Future<void> _edit(int index) async {
    final hasil = await showModalBottomSheet<KhsEntry>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _EditEntrySheet(entry: _entries[index]),
    );
    if (hasil == null) return;
    setState(() {
      _entries[index] = hasil;
      // Baru saja diperbaiki tangan, jadi sudah pasti — langsung ikut tersimpan
      // tanpa perlu dicentang lagi.
      if (hasil.terbaca) _selected.add(index);
    });
  }

  Future<void> _save() async {
    final userId = ref.read(currentUserProvider)?.id;
    if (userId == null) return;

    final dipilih = _selected.toList()..sort();
    if (dipilih.isEmpty) return;

    setState(() => _saving = true);
    try {
      final repo = ref.read(academicRepositoryProvider);
      final semester = _semesterController.text.trim();

      for (final index in dipilih) {
        final entry = _entries[index];
        final huruf = entry.huruf;
        // Baris tanpa huruf tidak bisa dicentang, tapi dijaga di sini juga:
        // menyimpan nilai kosong akan menimpa nilai lama dengan ketiadaan.
        if (huruf == null) continue;

        // ensureCourse mencocokkan nama lebih dulu, jadi mata kuliah yang sudah
        // ada dari jadwal ikut terisi nilainya alih-alih dibuat kembar.
        final courseId = await repo.ensureCourse(userId: userId, name: entry.courseName);

        await repo.updateCourseAkademik(
          id: courseId,
          sks: entry.sks,
          semester: semester.isEmpty ? null : semester,
          // Sks yang tidak terbaca dari foto tidak boleh menghapus sks yang
          // sudah pernah kamu isi sendiri.
          pertahankanSksLama: true,
        );
        await repo.setCourseFinalLetter(courseId, huruf);
      }

      ref.invalidate(coursesProvider);
      ref.invalidate(gradeComponentsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${dipilih.length} nilai disimpan')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Gagal menyimpan: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final scale = ref.watch(gradeScaleProvider);

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          HeroHeader.sub(
            title: 'Import dari Foto KHS',
            subtitle: 'Foto kartu hasil studi, nilainya terisi otomatis',
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
                if (!textScanSupported)
                  const EmptyState(
                    icon: Icons.phone_android,
                    title: 'Hanya bisa di HP',
                    subtitle: 'Membaca teks dari foto butuh kamera dan '
                        'pemroses on-device.',
                    color: _color,
                  )
                else ...[
                  Card(
                    color: _color.withValues(alpha: 0.08),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline, size: 18, color: _color),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              'Format KHS berbeda tiap kampus, jadi ini tebakan. '
                              'Baris yang huruf mutunya tidak terbaca sengaja '
                              'dilewati daripada dikarang, dan huruf mutu yang '
                              'tidak cocok dengan bobotnya ditandai — bukan '
                              'diperbaiki diam-diam. Periksa dulu sebelum '
                              'menyimpan.',
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.45,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _scanning ? null : () => _scan(fromCamera: true),
                          style: FilledButton.styleFrom(
                            backgroundColor: _color,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                          ),
                          icon: _scanning
                              ? const SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.photo_camera_outlined, size: 18),
                          label: Text(_scanning ? 'Membaca...' : 'Foto KHS'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _scanning ? null : () => _scan(fromCamera: false),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _color,
                            side: const BorderSide(color: _color),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                          ),
                          icon: const Icon(Icons.photo_library_outlined, size: 18),
                          label: const Text('Dari Galeri'),
                        ),
                      ),
                    ],
                  ),
                ],

                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Card(
                    color: colorScheme.errorContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.error_outline,
                              size: 18, color: colorScheme.onErrorContainer),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              _error!,
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.4,
                                color: colorScheme.onErrorContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                if (_entries.isNotEmpty && _skalaTertebak != null && _skalaTertebak != scale) ...[
                  const SizedBox(height: AppSpacing.md),
                  Card(
                    color: _color.withValues(alpha: 0.10),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'KHS ini memakai skala ${_skalaTertebak!.label}',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Setelanmu sekarang ${scale.label}. Skala menentukan '
                            'bobot tiap huruf, jadi IPK-mu akan salah kalau tidak '
                            'cocok.',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.4,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          FilledButton.tonal(
                            onPressed: () =>
                                ref.read(gradeScaleProvider.notifier).set(_skalaTertebak!),
                            child: Text('Ganti ke ${_skalaTertebak!.label}'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                if (_entries.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  TextField(
                    controller: _semesterController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Semester',
                      hintText: '2026/2027 Ganjil',
                      helperText: 'Dipakai untuk mengelompokkan semua nilai ini',
                      prefixIcon: Icon(Icons.calendar_month_outlined),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${_entries.length} baris terbaca',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                            ),
                            if (_perluDiisi > 0)
                              Text(
                                '$_perluDiisi masih perlu kamu isi',
                                style: TextStyle(fontSize: 12, color: colorScheme.error),
                              ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () => setState(() {
                          if (_selected.length == _entries.length) {
                            _selected.clear();
                          } else {
                            _selected
                              ..clear()
                              ..addAll(List.generate(_entries.length, (i) => i));
                          }
                        }),
                        style: TextButton.styleFrom(foregroundColor: _color),
                        child: Text(
                          _selected.length == _entries.length ? 'Lepas semua' : 'Pilih semua',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  for (var i = 0; i < _entries.length; i++)
                    _EntryTile(
                      entry: _entries[i],
                      selected: _selected.contains(i),
                      onToggle: () => setState(() {
                        if (!_selected.remove(i)) _selected.add(i);
                      }),
                      onEdit: () => _edit(i),
                    ),
                ],

                if (_rawText != null && _rawText!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: Text(
                      'Lihat teks yang terbaca',
                      style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
                    ),
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _rawText!,
                          style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _entries.isEmpty
          ? null
          : SaveBar(
              color: _color,
              saving: _saving,
              onPressed: _save,
              label: _selected.isEmpty
                  ? 'Pilih minimal satu'
                  : 'Simpan ${_selected.length} Nilai',
            ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({
    required this.entry,
    required this.selected,
    required this.onToggle,
    required this.onEdit,
  });

  final KhsEntry entry;
  final bool selected;
  final VoidCallback onToggle;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final belumTerbaca = !entry.terbaca;
    final warna = belumTerbaca ? colorScheme.error : _color;

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        // Baris yang nilainya belum terbaca tidak bisa dicentang — yang bisa
        // dilakukan cuma memperbaikinya, jadi ketukannya langsung ke sana.
        onTap: belumTerbaca ? onEdit : onToggle,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              Checkbox(
                value: selected,
                onChanged: belumTerbaca ? null : (_) => onToggle(),
                activeColor: _color,
              ),
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  color: warna.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  entry.huruf ?? '?',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: warna,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      entry.courseName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        entry.sks == null
                            ? 'sks belum terbaca'
                            : '${entry.sks} sks${entry.sksDihitung ? ' (dihitung)' : ''}',
                        if (entry.bobot != null) 'bobot ${_angkaRapi(entry.bobot!)}',
                        if (entry.dariBobot) 'nilai dari bobot',
                      ].join(' · '),
                      style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                    ),
                    if (belumTerbaca) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Nilainya tidak terbaca — ketuk untuk mengisi',
                        style: TextStyle(fontSize: 11, color: colorScheme.error),
                      ),
                    ] else if (entry.sks == null) ...[
                      const SizedBox(height: 2),
                      Text(
                        // Nilainya tetap tersimpan; yang tidak bisa cuma ikut
                        // menghitung IPK, karena IPK ditimbang sks.
                        'Isi sks-nya supaya ikut menghitung IPK',
                        style: TextStyle(fontSize: 11, color: colorScheme.error),
                      ),
                    ] else if (entry.janggal) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Huruf dan bobotnya tidak cocok — periksa dulu',
                        style: TextStyle(fontSize: 11, color: colorScheme.error),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18),
                tooltip: 'Perbaiki',
                onPressed: onEdit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bobot ditulis tanpa desimal kalau memang bulat: KHS menulis "8", bukan
/// "8.00", dan menampilkannya berbeda dari sumbernya bikin ragu.
String _angkaRapi(double nilai) =>
    nilai == nilai.roundToDouble() ? nilai.round().toString() : nilai.toStringAsFixed(2);

class _EditEntrySheet extends StatefulWidget {
  const _EditEntrySheet({required this.entry});

  final KhsEntry entry;

  @override
  State<_EditEntrySheet> createState() => _EditEntrySheetState();
}

class _EditEntrySheetState extends State<_EditEntrySheet> {
  late final TextEditingController _nameController =
      TextEditingController(text: widget.entry.courseName);
  late final TextEditingController _sksController =
      TextEditingController(text: widget.entry.sks?.toString() ?? '');

  late String? _huruf = widget.entry.huruf;

  @override
  void initState() {
    super.initState();
    // Mengisi sks bisa membuka jalan menghitung hurufnya dari kolom bobot.
    _sksController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _sksController.dispose();
    super.dispose();
  }

  /// Huruf yang bisa dihitung dari bobot dan sks yang sedang diketik.
  ///
  /// Hanya ditawarkan kalau hurufnya memang belum ada — kalau sudah terbaca,
  /// yang tertulis di KHS lebih berhak daripada hitungan.
  String? get _saranHuruf {
    if (_huruf != null) return null;
    final bobot = widget.entry.bobot;
    final sks = int.tryParse(_sksController.text.trim());
    if (bobot == null || sks == null || sks <= 0) return null;
    return hurufDariKolomBobot(sks: sks, bobot: bobot);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        MediaQuery.of(context).viewInsets.bottom + AppSpacing.md,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Perbaiki Nilai',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Mata kuliah'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _sksController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'SKS'),
            ),
            const SizedBox(height: AppSpacing.md),
            const Text('Huruf mutu', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            if (_huruf == null) ...[
              const SizedBox(height: 4),
              Text(
                'Tidak terbaca dari foto. Lihat KHS aslinya untuk baris ini.',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
            if (_saranHuruf case final saran?) ...[
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: () => setState(() => _huruf = saran),
                icon: const Icon(Icons.calculate_outlined, size: 17),
                label: Text(
                  'Pakai $saran — dari bobot '
                  '${_angkaRapi(widget.entry.bobot!)} ÷ ${_sksController.text.trim()} sks',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final huruf in semuaHuruf)
                  ChoiceChip(
                    label: Text(huruf),
                    selected: _huruf == huruf,
                    onSelected: (_) => setState(() => _huruf = huruf),
                    selectedColor: _color.withValues(alpha: 0.18),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _huruf == huruf
                          ? _color
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: () {
                final nama = _nameController.text.trim();
                if (nama.isEmpty) return;
                if (_huruf == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Pilih dulu huruf mutunya')),
                  );
                  return;
                }
                Navigator.pop(
                  context,
                  widget.entry.copyWith(
                    courseName: nama,
                    huruf: _huruf,
                    sks: int.tryParse(_sksController.text.trim()),
                  ),
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: _color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Simpan Perubahan'),
            ),
          ],
        ),
      ),
    );
  }
}
