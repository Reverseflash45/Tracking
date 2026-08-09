import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/hero_header.dart';
import '../../../core/widgets/save_bar.dart';
import '../../../core/widgets/section_header.dart';
import '../data/academic_repository.dart';
import '../data/models/task.dart';
import '../domain/date_presets.dart';
import '../domain/matkul_aktif.dart';
import 'academic_providers.dart';
import 'task_tile.dart' show priorityColor;

const _deadlineColor = AppColors.deadline;
final _deadlineFormat = DateFormat('EEEE, d MMM y', 'id_ID');
final _timeFormat = DateFormat('HH:mm', 'id_ID');

class TaskFormPage extends ConsumerStatefulWidget {
  const TaskFormPage({super.key, this.taskId, this.kindAwal = TaskKind.kuliah});

  /// Kalau diisi, form berjalan dalam mode edit.
  final String? taskId;

  /// Jenis yang terpilih saat form dibuka. Dipakai halaman Tugas Pribadi supaya
  /// tombol tambahnya tidak melahirkan tugas kuliah yang langsung hilang dari
  /// daftar tempat kamu menekannya.
  final TaskKind kindAwal;

  @override
  ConsumerState<TaskFormPage> createState() => _TaskFormPageState();
}

class _TaskFormPageState extends ConsumerState<TaskFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  String? _courseId;
  late TaskKind _kind;
  TaskPriority _priority = TaskPriority.medium;
  DateTime _deadline = DeadlinePreset.satuMinggu.resolve();
  bool _saving = false;
  bool _prefilled = false;

  /// Membuka kembali seluruh daftar mata kuliah, termasuk semester yang sudah
  /// lewat. Mati secara bawaan.
  bool _semuaMatkul = false;

  bool get _isEdit => widget.taskId != null;

  @override
  void initState() {
    super.initState();
    _kind = widget.kindAwal;
    // Data biasanya sudah ada di cache provider karena user datang dari daftar
    // tugas; kalau belum (mis. halaman di-refresh langsung), diisi lewat
    // ref.listen di build saat datanya tiba.
    if (_isEdit) {
      final task = _findTask(ref.read(tasksProvider).value);
      if (task != null) _prefill(task);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  AcademicTask? _findTask(List<AcademicTask>? tasks) {
    if (tasks == null) return null;
    for (final task in tasks) {
      if (task.id == widget.taskId) return task;
    }
    return null;
  }

  void _prefill(AcademicTask task) {
    _titleController.text = task.title;
    _descriptionController.text = task.description ?? '';
    _courseId = task.courseId;
    _kind = task.kind;
    _priority = task.priority;
    _deadline = task.deadline;
    _prefilled = true;
  }

  Future<void> _pickDeadline() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _deadline,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1095)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_deadline),
    );
    if (time == null) return;
    setState(() {
      _deadline = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final userId = ref.read(currentUserProvider)?.id;
    if (userId == null) return;

    setState(() => _saving = true);
    try {
      final repository = ref.read(academicRepositoryProvider);
      final description =
          _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim();

      if (_isEdit) {
        await repository.updateTask(
          id: widget.taskId!,
          courseId: _courseId,
          kind: _kind,
          title: _titleController.text.trim(),
          description: description,
          deadline: _deadline,
          priority: _priority,
        );
      } else {
        await repository.addTask(
          userId: userId,
          courseId: _courseId,
          kind: _kind,
          title: _titleController.text.trim(),
          description: description,
          deadline: _deadline,
          priority: _priority,
        );
      }
      ref.invalidate(tasksProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Gagal menyimpan: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final matkulAsync = ref.watch(daftarMatkulProvider);

    if (_isEdit) {
      ref.listen(tasksProvider, (previous, next) {
        if (_prefilled) return;
        final task = _findTask(next.value);
        if (task != null) setState(() => _prefill(task));
      });
    }

    return Scaffold(
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            HeroHeader.sub(
              title: _isEdit ? 'Edit Tugas' : 'Tambah Tugas',
              subtitle: 'Catat tugas beserta deadline dan prioritasnya',
              color: _deadlineColor,
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
                  const SectionHeader(
                    title: 'Detail Tugas',
                    icon: Icons.assignment_outlined,
                    color: _deadlineColor,
                  ),
                  TextFormField(
                    controller: _titleController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Judul Tugas',
                      hintText: 'Misal: Laporan Praktikum Bab 3',
                      prefixIcon: Icon(Icons.title),
                    ),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty) ? 'Wajib diisi' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descriptionController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Deskripsi (opsional)',
                      hintText: 'Detail pengerjaan, referensi, atau catatan lain',
                      alignLabelWithHint: true,
                    ),
                    maxLines: 4,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const SectionHeader(
                    title: 'Prioritas',
                    icon: Icons.flag_outlined,
                    color: _deadlineColor,
                  ),
                  Row(
                    children: [
                      for (final priority in TaskPriority.values) ...[
                        if (priority != TaskPriority.values.first)
                          const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: _PriorityOption(
                            priority: priority,
                            selected: _priority == priority,
                            onTap: () => setState(() => _priority = priority),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const SectionHeader(
                    title: 'Deadline',
                    icon: Icons.event_outlined,
                    color: _deadlineColor,
                  ),
                  Card(
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _deadlineColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.calendar_today, size: 18, color: _deadlineColor),
                      ),
                      title: Text(
                        _deadlineFormat.format(_deadline),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text('Pukul ${_timeFormat.format(_deadline)}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _pickDeadline,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    children: [
                      for (final preset in DeadlinePreset.values)
                        _DeadlinePresetChip(
                          label: preset.label,
                          onTap: () => setState(() => _deadline = preset.resolve()),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const SectionHeader(
                    title: 'Jenis',
                    icon: Icons.label_outline,
                    color: _deadlineColor,
                  ),
                  SegmentedButton<TaskKind>(
                    segments: const [
                      ButtonSegment(
                        value: TaskKind.kuliah,
                        icon: Icon(Icons.school_outlined, size: 18),
                        label: Text('Kuliah'),
                      ),
                      ButtonSegment(
                        value: TaskKind.pribadi,
                        icon: Icon(Icons.person_outline, size: 18),
                        label: Text('Pribadi'),
                      ),
                    ],
                    selected: {_kind},
                    onSelectionChanged: (v) => setState(() {
                      _kind = v.first;
                      // Tugas pribadi tidak punya mata kuliah. Kalau sebelumnya
                      // terisi lalu dipindah ke pribadi, mata kuliahnya ikut
                      // dilepas — bukan disimpan diam-diam dan muncul lagi saat
                      // dipindah balik.
                      if (_kind == TaskKind.pribadi) _courseId = null;
                    }),
                    showSelectedIcon: false,
                  ),
                  if (_kind == TaskKind.kuliah) ...[
                  const SizedBox(height: AppSpacing.lg),
                  const SectionHeader(
                    title: 'Mata Kuliah',
                    icon: Icons.menu_book_outlined,
                    color: _deadlineColor,
                  ),
                  matkulAsync.when(
                    data: (daftar) {
                      final aktif = pilihanMatkul(
                        daftar.semua,
                        daftar.jadwal,
                        dipakai: _courseId,
                      );
                      final tersembunyi = daftar.semua.length - aktif.length;
                      final pilihan = _semuaMatkul ? daftar.semua : aktif;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DropdownButtonFormField<String?>(
                            // Kunci ikut berubah bersama nilainya supaya isian
                            // yang datang belakangan — mode edit, atau daftar
                            // yang baru dibuka lebar — benar-benar terpasang.
                            key: ValueKey('matkul-$_courseId-$_semuaMatkul'),
                            initialValue: _courseId,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Mata kuliah (opsional)',
                              prefixIcon: Icon(Icons.school_outlined),
                            ),
                            items: [
                              const DropdownMenuItem(value: null, child: Text('Umum')),
                              ...pilihan.map(
                                (course) => DropdownMenuItem(
                                  value: course.id,
                                  child: Text(course.name, overflow: TextOverflow.ellipsis),
                                ),
                              ),
                            ],
                            onChanged: (value) => setState(() => _courseId = value),
                          ),
                          if (tersembunyi > 0) ...[
                            const SizedBox(height: 4),
                            TextButton.icon(
                              onPressed: () => setState(() => _semuaMatkul = !_semuaMatkul),
                              icon: Icon(
                                _semuaMatkul ? Icons.filter_list : Icons.history,
                                size: 16,
                              ),
                              label: Text(
                                _semuaMatkul
                                    ? 'Tampilkan yang ada jadwalnya saja'
                                    : 'Tampilkan $tersembunyi mata kuliah semester lalu',
                                style: const TextStyle(fontSize: 12),
                              ),
                              style: TextButton.styleFrom(
                                foregroundColor: _deadlineColor,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                    loading: () => const LinearProgressIndicator(),
                    error: (error, stackTrace) => Text('Gagal memuat mata kuliah: $error'),
                  ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SaveBar(
        color: _deadlineColor,
        saving: _saving,
        onPressed: _submit,
      ),
    );
  }
}

class _PriorityOption extends StatelessWidget {
  const _PriorityOption({
    required this.priority,
    required this.selected,
    required this.onTap,
  });

  final TaskPriority priority;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = priorityColor(priority);
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radius),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.14) : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          border: Border.all(
            color: selected ? color : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.flag, size: 18, color: selected ? color : colorScheme.onSurfaceVariant),
            const SizedBox(height: 4),
            Text(
              priority.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected ? color : colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeadlinePresetChip extends StatelessWidget {
  const _DeadlinePresetChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
      avatar: const Icon(Icons.bolt, size: 16, color: _deadlineColor),
      labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
    );
  }
}

