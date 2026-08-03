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
import 'academic_providers.dart';
import 'tasks_page.dart' show priorityColor;

const _deadlineColor = AppColors.deadline;
final _deadlineFormat = DateFormat('EEEE, d MMM y', 'id_ID');
final _timeFormat = DateFormat('HH:mm', 'id_ID');

class TaskFormPage extends ConsumerStatefulWidget {
  const TaskFormPage({super.key, this.taskId});

  /// Kalau diisi, form berjalan dalam mode edit.
  final String? taskId;

  @override
  ConsumerState<TaskFormPage> createState() => _TaskFormPageState();
}

class _TaskFormPageState extends ConsumerState<TaskFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  String? _courseId;
  TaskPriority _priority = TaskPriority.medium;
  DateTime _deadline = DeadlinePreset.satuMinggu.resolve();
  bool _saving = false;
  bool _prefilled = false;

  bool get _isEdit => widget.taskId != null;

  @override
  void initState() {
    super.initState();
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
          title: _titleController.text.trim(),
          description: description,
          deadline: _deadline,
          priority: _priority,
        );
      } else {
        await repository.addTask(
          userId: userId,
          courseId: _courseId,
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
    final coursesAsync = ref.watch(coursesProvider);

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
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.calendar_today, size: 20, color: _deadlineColor),
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
                    title: 'Mata Kuliah',
                    icon: Icons.menu_book_outlined,
                    color: _deadlineColor,
                  ),
                  coursesAsync.when(
                    data: (courses) => DropdownButtonFormField<String?>(
                      initialValue: _courseId,
                      decoration: const InputDecoration(
                        labelText: 'Mata kuliah (opsional)',
                        prefixIcon: Icon(Icons.school_outlined),
                      ),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Umum')),
                        ...courses.map(
                          (course) => DropdownMenuItem(value: course.id, child: Text(course.name)),
                        ),
                      ],
                      onChanged: (value) => setState(() => _courseId = value),
                    ),
                    loading: () => const LinearProgressIndicator(),
                    error: (error, stackTrace) => Text('Gagal memuat mata kuliah: $error'),
                  ),
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
            Icon(Icons.flag, size: 20, color: selected ? color : colorScheme.onSurfaceVariant),
            const SizedBox(height: 4),
            Text(
              priority.label,
              style: TextStyle(
                fontSize: 14,
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
      labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    );
  }
}

