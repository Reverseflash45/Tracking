import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/hero_header.dart';
import '../data/academic_repository.dart';
import '../data/models/class_schedule.dart';
import '../data/models/course.dart';
import '../data/models/task.dart';
import '../data/recurring_task_generator.dart';
import '../domain/recurring_task.dart';
import 'academic_providers.dart';

const _color = AppColors.deadline;

class RecurringTasksPage extends ConsumerWidget {
  const RecurringTasksPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templatesAsync = ref.watch(recurringTasksProvider);
    final templates = templatesAsync.value ?? const <RecurringTask>[];
    final aktif = templates.where((t) => t.active).length;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _bukaForm(context, ref),
        backgroundColor: _color,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Template'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(recurringTasksProvider),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            HeroHeader.sub(
              title: 'Tugas Berulang',
              subtitle: 'Dibuat otomatis tiap minggu',
              color: _color,
              leading: HeroIconButton(
                icon: Icons.arrow_back,
                tooltip: 'Kembali',
                onPressed: () => context.pop(),
              ),
              stats: [
                HeroStatData(
                  icon: Icons.event_repeat,
                  value: '$aktif',
                  label: 'Aktif',
                ),
                HeroStatData(
                  icon: Icons.calendar_month_outlined,
                  value: '$kHorizonTugasBerulangHari',
                  label: 'Hari ke Depan',
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 96),
              child: templatesAsync.when(
                data: (items) => items.isEmpty
                    ? const _Penjelasan()
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final template in items)
                            Padding(
                              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                              child: _TemplateTile(template: template),
                            ),
                          const SizedBox(height: AppSpacing.md),
                          const _CatatanCaraKerja(),
                        ],
                      ),
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, _) => EmptyState(
                  icon: Icons.error_outline,
                  title: 'Gagal memuat template',
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

Future<void> _bukaForm(BuildContext context, WidgetRef ref, {RecurringTask? template}) async {
  final tersimpan = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _TemplateSheet(template: template),
  );
  if (tersimpan != true) return;

  ref.invalidate(recurringTasksProvider);
  // Template baru langsung menghasilkan tugasnya, tanpa menunggu app dibuka
  // ulang — kalau tidak, halaman Tugas akan terlihat tidak berubah dan kamu
  // wajar mengira fiturnya tidak jalan.
  await ref.read(recurringTaskGeneratorProvider).jalankan();
}

class _Penjelasan extends StatelessWidget {
  const _Penjelasan();

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      icon: Icons.event_repeat,
      title: 'Belum ada tugas berulang',
      subtitle: 'Buat satu template — misalnya "Laporan praktikum, tiap Senin" — '
          'dan tugasnya dibuat sendiri untuk tiga minggu ke depan.',
      color: _color,
    );
  }
}

class _CatatanCaraKerja extends StatelessWidget {
  const _CatatanCaraKerja();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 16, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Tugas dibuat untuk $kHorizonTugasBerulangHari hari ke depan tiap '
              'kali app dibuka. Menandai satu tugas selesai tidak memengaruhi '
              'minggu berikutnya. Menghapus tugas yang sudah dibuat akan '
              'membuatnya muncul lagi — matikan template-nya kalau memang tidak '
              'ingin dibuat lagi.',
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TemplateTile extends ConsumerWidget {
  const _TemplateTile({required this.template});

  final RecurringTask template;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final mati = !template.active;

    return Dismissible(
      key: ValueKey(template.id),
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
          title: const Text('Hapus template?'),
          content: Text(
            '"${template.title}" tidak akan dibuat lagi. Tugas yang sudah '
            'terlanjur dibuat tetap ada.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hapus')),
          ],
        ),
      ),
      onDismissed: (_) async {
        await ref.read(academicRepositoryProvider).deleteRecurringTask(template.id);
        ref.invalidate(recurringTasksProvider);
      },
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _bukaForm(context, ref, template: template),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: (mati ? colorScheme.onSurfaceVariant : _color).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.event_repeat,
                    size: 17,
                    color: mati ? colorScheme.onSurfaceVariant : _color,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        template.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          decoration: mati ? TextDecoration.lineThrough : null,
                          color: mati ? colorScheme.onSurfaceVariant : null,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        [
                          'Tiap ${weekDayName(template.weekday)}',
                          template.jamLabel,
                          if (template.courseName != null) template.courseName!,
                        ].join('  ·  '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: template.active,
                  activeThumbColor: _color,
                  onChanged: (value) async {
                    await ref.read(academicRepositoryProvider).saveRecurringTask(
                          userId: template.userId,
                          id: template.id,
                          courseId: template.courseId,
                          title: template.title,
                          description: template.description,
                          priority: template.priority,
                          weekday: template.weekday,
                          deadlineMinute: template.deadlineMinute,
                          active: value,
                        );
                    ref.invalidate(recurringTasksProvider);
                    if (value) await ref.read(recurringTaskGeneratorProvider).jalankan();
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

class _TemplateSheet extends ConsumerStatefulWidget {
  const _TemplateSheet({this.template});

  final RecurringTask? template;

  @override
  ConsumerState<_TemplateSheet> createState() => _TemplateSheetState();
}

class _TemplateSheetState extends ConsumerState<_TemplateSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;

  String? _courseId;
  late int _weekday;
  late TimeOfDay _jam;
  late TaskPriority _priority;
  bool _saving = false;

  bool get _isEdit => widget.template != null;

  @override
  void initState() {
    super.initState();
    final template = widget.template;
    _titleController = TextEditingController(text: template?.title ?? '');
    _descriptionController = TextEditingController(text: template?.description ?? '');
    _courseId = template?.courseId;
    _weekday = template?.weekday ?? DateTime.now().weekday;
    _priority = template?.priority ?? TaskPriority.medium;
    _jam = template == null
        ? const TimeOfDay(hour: 23, minute: 59)
        : TimeOfDay(
            hour: template.deadlineMinute ~/ 60,
            minute: template.deadlineMinute % 60,
          );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _simpan() async {
    if (!_formKey.currentState!.validate()) return;

    final userId = ref.read(currentUserProvider)?.id;
    if (userId == null) return;

    setState(() => _saving = true);
    try {
      final deskripsi = _descriptionController.text.trim();
      await ref.read(academicRepositoryProvider).saveRecurringTask(
            userId: userId,
            id: widget.template?.id,
            courseId: _courseId,
            title: _titleController.text.trim(),
            description: deskripsi.isEmpty ? null : deskripsi,
            priority: _priority,
            weekday: _weekday,
            deadlineMinute: _jam.hour * 60 + _jam.minute,
            active: widget.template?.active ?? true,
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
    final courses = ref.watch(coursesProvider).value ?? const <Course>[];

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        top: AppSpacing.md,
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
                _isEdit ? 'Edit Template' : 'Tugas Berulang Baru',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _titleController,
                autofocus: !_isEdit,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Judul tugas',
                  hintText: 'Misal: Laporan praktikum',
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (value) =>
                    (value == null || value.trim().isEmpty) ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 12),
              if (courses.isNotEmpty) ...[
                DropdownButtonFormField<String>(
                  initialValue: _courseId,
                  decoration: const InputDecoration(
                    labelText: 'Mata kuliah (opsional)',
                    prefixIcon: Icon(Icons.menu_book_outlined),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Tidak dikaitkan')),
                    ...courses.map(
                      (course) => DropdownMenuItem(value: course.id, child: Text(course.name)),
                    ),
                  ],
                  onChanged: (value) => setState(() => _courseId = value),
                ),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: _descriptionController,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Catatan (opsional)',
                  prefixIcon: Icon(Icons.notes),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              const Text('Hari', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: AppSpacing.sm),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (var day = 1; day <= 7; day++) ...[
                      if (day > 1) const SizedBox(width: 6),
                      ChoiceChip(
                        label: Text(weekDayName(day).substring(0, 3)),
                        selected: _weekday == day,
                        onSelected: (_) => setState(() => _weekday = day),
                        selectedColor: _color.withValues(alpha: 0.18),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showTimePicker(context: context, initialTime: _jam);
                        if (picked != null) setState(() => _jam = picked);
                      },
                      icon: const Icon(Icons.schedule, size: 18),
                      label: Text('Jam ${_jam.format(context)}'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              const Text('Prioritas', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: AppSpacing.sm),
              SegmentedButton<TaskPriority>(
                segments: [
                  for (final priority in TaskPriority.values)
                    ButtonSegment(value: priority, label: Text(priority.label)),
                ],
                selected: {_priority},
                showSelectedIcon: false,
                onSelectionChanged: (value) => setState(() => _priority = value.first),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: _saving ? null : _simpan,
                style: FilledButton.styleFrom(
                  backgroundColor: _color,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Simpan'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
