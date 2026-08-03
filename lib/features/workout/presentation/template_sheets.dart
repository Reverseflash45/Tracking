import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/empty_state.dart';
import '../data/models/workout_template.dart';
import '../data/workout_repository.dart';
import 'workout_providers.dart';

const _color = AppColors.workout;

/// Pemilih template. Mengembalikan template yang dipilih, atau null kalau
/// sheet ditutup tanpa memilih.
Future<WorkoutTemplate?> showTemplatePicker(BuildContext context) {
  return showModalBottomSheet<WorkoutTemplate>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => const _TemplatePickerSheet(),
  );
}

class _TemplatePickerSheet extends ConsumerWidget {
  const _TemplatePickerSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templatesAsync = ref.watch(workoutTemplatesProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: ConstrainedBox(
        // Sheet dibatasi supaya daftar panjang tidak menutupi seluruh layar.
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
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
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.bookmark_outline, size: 20, color: _color),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Pakai Template',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Flexible(
                child: templatesAsync.when(
                  data: (templates) => templates.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                          child: EmptyState(
                            icon: Icons.bookmark_border,
                            title: 'Belum ada template',
                            subtitle: 'Isi latihanmu dulu, lalu tekan '
                                '"Simpan sebagai Template" di form ini',
                            color: _color,
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          itemCount: templates.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 4),
                          itemBuilder: (context, index) {
                            final template = templates[index];
                            return Card(
                              margin: EdgeInsets.zero,
                              clipBehavior: Clip.antiAlias,
                              child: ListTile(
                                onTap: () => Navigator.of(context).pop(template),
                                title: Text(
                                  template.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                                subtitle: Text(
                                  template.summary,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 20),
                                  tooltip: 'Hapus template',
                                  onPressed: () => _confirmDelete(context, ref, template),
                                ),
                              ),
                            );
                          },
                        ),
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
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
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    WorkoutTemplate template,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus template?'),
        content: Text(
          '"${template.name}" akan dihapus. Sesi workout yang sudah tercatat '
          'tidak ikut terhapus.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref.read(workoutRepositoryProvider).deleteTemplate(template.id);
    ref.invalidate(workoutTemplatesProvider);
  }
}

/// Dialog nama template. Mengembalikan nama yang diketik, atau null kalau batal.
Future<String?> showTemplateNameDialog(BuildContext context, {String initial = ''}) {
  final controller = TextEditingController(text: initial);

  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Simpan sebagai Template'),
      content: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          labelText: 'Nama template',
          hintText: 'Misal: Push A',
        ),
        onSubmitted: (value) {
          final name = value.trim();
          if (name.isNotEmpty) Navigator.pop(context, name);
        },
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
        FilledButton(
          onPressed: () {
            final name = controller.text.trim();
            if (name.isNotEmpty) Navigator.pop(context, name);
          },
          style: FilledButton.styleFrom(backgroundColor: _color, foregroundColor: Colors.white),
          child: const Text('Simpan'),
        ),
      ],
    ),
  ).whenComplete(controller.dispose);
}
