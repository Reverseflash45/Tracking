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
import '../data/models/class_schedule.dart';
import '../domain/krs_parser.dart';
import 'academic_providers.dart';

const _color = AppColors.academic;

class KrsImportPage extends ConsumerStatefulWidget {
  const KrsImportPage({super.key});

  @override
  ConsumerState<KrsImportPage> createState() => _KrsImportPageState();
}

class _KrsImportPageState extends ConsumerState<KrsImportPage> {
  List<KrsEntry> _entries = [];

  /// Baris yang dicentang untuk disimpan. Semua tercentang secara bawaan;
  /// yang salah baca tinggal dilepas.
  final Set<int> _selected = {};

  String? _rawText;
  bool _scanning = false;
  bool _saving = false;
  String? _error;

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

    final entries = parseKrs(hasil.text);
    setState(() {
      _scanning = false;
      _rawText = hasil.text;
      _entries = entries;
      _selected
        ..clear()
        ..addAll(List.generate(entries.length, (i) => i));
      if (entries.isEmpty) {
        _error = 'Tidak ada baris jadwal yang terbaca. Pastikan kolom hari dan '
            'jam terlihat jelas di foto.';
      }
    });
  }

  Future<void> _edit(int index) async {
    final hasil = await showModalBottomSheet<KrsEntry>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _EditEntrySheet(entry: _entries[index]),
    );
    if (hasil != null) setState(() => _entries[index] = hasil);
  }

  Future<void> _save() async {
    final userId = ref.read(currentUserProvider)?.id;
    if (userId == null) return;

    final dipilih = _selected.toList()..sort();
    if (dipilih.isEmpty) return;

    setState(() => _saving = true);
    try {
      final repo = ref.read(academicRepositoryProvider);

      for (final index in dipilih) {
        final entry = _entries[index];
        final courseId = await repo.ensureCourse(
          userId: userId,
          name: entry.courseName,
          lecturer: entry.lecturer,
          // Kode mata kuliah menempel di mata kuliahnya — sama di kelas mana
          // pun. Pembaca KRS sebenarnya sudah menemukannya sejak dulu; dia
          // harus menemukannya justru untuk bisa membuangnya dari nama.
          code: entry.courseCode,
        );

        await repo.addSchedule(
          userId: userId,
          courseId: courseId,
          dayOfWeek: entry.dayOfWeek,
          // Kolom time di Postgres butuh detik.
          startTime: '${entry.startTime}:00',
          endTime: '${entry.endTime}:00',
          room: entry.room,
          // Kode kelas menempel di jadwalnya: satu mata kuliah bisa dibuka
          // untuk beberapa kelas, dan barisnya di jadwal yang membedakan.
          classCode: entry.classCode,
        );
      }

      ref.invalidate(classSchedulesProvider);
      ref.invalidate(coursesProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${dipilih.length} jadwal ditambahkan')),
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

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          HeroHeader.sub(
            title: 'Import dari Foto KRS',
            subtitle: 'Foto sekali, jadwalnya terisi otomatis',
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
                              'Format KRS berbeda tiap kampus, jadi ini tebakan — '
                              'bukan pembacaan sempurna. Baris yang hari dan '
                              'jamnya tidak jelas sengaja dilewati daripada '
                              'dikarang. Periksa dulu sebelum menyimpan.',
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
                          label: Text(_scanning ? 'Membaca...' : 'Foto KRS'),
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
                                fontSize: 12,
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

                if (_entries.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      Text(
                        '${_entries.length} baris terbaca',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                      const Spacer(),
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
                          _selected.length == _entries.length
                              ? 'Lepas semua'
                              : 'Pilih semua',
                          style: const TextStyle(fontSize: 12),
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
                      style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
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
                          style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
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
              // Pilihan kosong ditangani di dalam _save; SaveBar tidak
              // menerima callback null.
              saving: _saving,
              onPressed: _save,
              label: _selected.isEmpty
                  ? 'Pilih minimal satu'
                  : 'Tambahkan ${_selected.length} Jadwal',
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

  final KrsEntry entry;
  final bool selected;
  final VoidCallback onToggle;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              Checkbox(
                value: selected,
                onChanged: (_) => onToggle(),
                activeColor: _color,
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
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${weekDayName(entry.dayOfWeek)} · '
                      '${entry.startTime}-${entry.endTime}'
                      '${entry.room != null ? ' · ${entry.room}' : ''}',
                      style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                    ),
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

class _EditEntrySheet extends StatefulWidget {
  const _EditEntrySheet({required this.entry});

  final KrsEntry entry;

  @override
  State<_EditEntrySheet> createState() => _EditEntrySheetState();
}

class _EditEntrySheetState extends State<_EditEntrySheet> {
  late final TextEditingController _nameController =
      TextEditingController(text: widget.entry.courseName);
  late final TextEditingController _roomController =
      TextEditingController(text: widget.entry.room ?? '');
  late final TextEditingController _lecturerController =
      TextEditingController(text: widget.entry.lecturer ?? '');

  late int _day = widget.entry.dayOfWeek;
  late String _start = widget.entry.startTime;
  late String _end = widget.entry.endTime;

  @override
  void dispose() {
    _nameController.dispose();
    _roomController.dispose();
    _lecturerController.dispose();
    super.dispose();
  }

  Future<void> _pickTime({required bool mulai}) async {
    final awal = mulai ? _start : _end;
    final parts = awal.split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.tryParse(parts.first) ?? 7,
        minute: int.tryParse(parts.last) ?? 0,
      ),
    );
    if (picked == null) return;

    final teks = '${picked.hour.toString().padLeft(2, '0')}:'
        '${picked.minute.toString().padLeft(2, '0')}';
    setState(() {
      if (mulai) {
        _start = teks;
      } else {
        _end = teks;
      }
    });
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
              'Perbaiki Jadwal',
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
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var day = 1; day <= 7; day++)
                  ChoiceChip(
                    label: Text(weekDayName(day)),
                    selected: _day == day,
                    onSelected: (_) => setState(() => _day = day),
                    selectedColor: _color.withValues(alpha: 0.18),
                    labelStyle: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: _day == day
                          ? _color
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickTime(mulai: true),
                    child: Text('Mulai $_start'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickTime(mulai: false),
                    child: Text('Selesai $_end'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _roomController,
              decoration: const InputDecoration(labelText: 'Ruangan (opsional)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _lecturerController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Dosen (opsional)'),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: () {
                final nama = _nameController.text.trim();
                if (nama.isEmpty) return;
                if (_end.compareTo(_start) <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Jam selesai harus setelah jam mulai')),
                  );
                  return;
                }

                Navigator.pop(
                  context,
                  widget.entry.copyWith(
                    courseName: nama,
                    dayOfWeek: _day,
                    startTime: _start,
                    endTime: _end,
                    room: _roomController.text.trim().isEmpty
                        ? null
                        : _roomController.text.trim(),
                    lecturer: _lecturerController.text.trim().isEmpty
                        ? null
                        : _lecturerController.text.trim(),
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
