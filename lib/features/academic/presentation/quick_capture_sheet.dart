import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../data/academic_repository.dart';
import '../data/models/task.dart';
import '../domain/date_presets.dart';
import 'academic_providers.dart';

const _color = AppColors.deadline;

/// Catat tugas kilat tanpa membuka form panjang: cukup judul + satu preset
/// deadline. Detail lain (mata kuliah, deskripsi, prioritas) bisa dilengkapi
/// belakangan lewat halaman edit.
Future<void> showQuickCaptureSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => const _QuickCaptureSheet(),
  );
}

class _QuickCaptureSheet extends ConsumerStatefulWidget {
  const _QuickCaptureSheet();

  @override
  ConsumerState<_QuickCaptureSheet> createState() => _QuickCaptureSheetState();
}

class _QuickCaptureSheetState extends ConsumerState<_QuickCaptureSheet> {
  final _titleController = TextEditingController();
  DeadlinePreset _preset = DeadlinePreset.satuMinggu;
  bool _saving = false;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    final userId = ref.read(currentUserProvider)?.id;
    if (userId == null) return;

    setState(() => _saving = true);
    try {
      await ref.read(academicRepositoryProvider).addTask(
            userId: userId,
            title: title,
            deadline: _preset.resolve(),
            priority: TaskPriority.medium,
          );
      ref.invalidate(tasksProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"$title" tersimpan'),
          action: SnackBarAction(
            label: 'Lihat',
            onPressed: () => context.go('/academic/tasks'),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Gagal menyimpan: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // viewInsets menjaga isi sheet tetap di atas keyboard.
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        MediaQuery.of(context).viewInsets.bottom + AppSpacing.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.bolt, size: 18, color: _color),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Catat Cepat',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _titleController,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _saving ? null : _submit(),
            decoration: const InputDecoration(
              labelText: 'Mau catat apa?',
              hintText: 'Misal: Revisi bab 2',
              prefixIcon: Icon(Icons.edit_outlined),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Deadline',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              for (final preset in DeadlinePreset.values)
                ChoiceChip(
                  label: Text(preset.label),
                  selected: _preset == preset,
                  onSelected: (_) => setState(() => _preset = preset),
                  selectedColor: _color.withValues(alpha: 0.18),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _preset == preset
                        ? _color
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            onPressed: _saving ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: _color,
              foregroundColor: Colors.white,
            ),
            icon: _saving
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.check),
            label: Text(_saving ? 'Menyimpan...' : 'Simpan'),
          ),
        ],
      ),
    );
  }
}
