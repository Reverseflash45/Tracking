import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/hero_header.dart';
import '../../../core/widgets/section_header.dart';
import '../../academic/presentation/academic_providers.dart';
import '../../finance/data/finance_repository.dart';
import '../../nutrition/data/nutrition_repository.dart';
import '../../run/data/run_repository.dart';
import '../../workout/presentation/workout_providers.dart';
import '../domain/preset_answers.dart';

const _color = AppColors.dashboard;

/// Bahan jawaban, dirakit dari provider yang sudah ada.
///
/// Null selama data inti masih dimuat, supaya tidak ada jawaban yang dihitung
/// dari data setengah jadi lalu terlihat seperti fakta.
final questionInputProvider = Provider.autoDispose<QuestionInput?>((ref) {
  final tasks = ref.watch(tasksProvider).value;
  final sessions = ref.watch(workoutSessionsProvider).value;
  final runs = ref.watch(runsProvider).value;

  if (tasks == null || sessions == null || runs == null) return null;

  return QuestionInput(
    now: DateTime.now(),
    tasks: tasks,
    sessions: sessions,
    runs: runs,
    foods: ref.watch(foodLogsProvider).value ?? const [],
    transactions: ref.watch(transactionsProvider).value ?? const [],
    finance: ref.watch(financeSummaryProvider).value,
  );
});

class PresetAnswersPage extends ConsumerWidget {
  const PresetAnswersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final input = ref.watch(questionInputProvider);
    final grouped = questionsByCategory;

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          HeroHeader(
            title: 'Tanya Data',
            subtitle: 'Ketuk pertanyaan, jawabannya dihitung dari catatanmu',
            color: _color,
            leading: HeroIconButton(
              icon: Icons.arrow_back,
              tooltip: 'Kembali',
              onPressed: () => context.pop(),
            ),
          ),
          if (input == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 64),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.xl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final entry in grouped.entries) ...[
                    SectionHeader(
                      title: entry.key.label,
                      icon: entry.key.icon,
                      color: _color,
                    ),
                    for (final question in entry.value)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: _QuestionCard(question: question, input: input),
                      ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  const _CatatanBawah(),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Kartu pertanyaan yang membuka jawabannya di tempat.
///
/// Jawaban tidak dihitung sampai kartunya dibuka — dengan 19 pertanyaan yang
/// masing-masing menyapu seluruh data, menghitung semuanya di awal membuat
/// halaman ini tersendat saat dibuka.
class _QuestionCard extends StatefulWidget {
  const _QuestionCard({required this.question, required this.input});

  final Question question;
  final QuestionInput input;

  @override
  State<_QuestionCard> createState() => _QuestionCardState();
}

class _QuestionCardState extends State<_QuestionCard> {
  bool _terbuka = false;
  Answer? _answer;

  void _toggle() {
    setState(() {
      _terbuka = !_terbuka;
      _answer ??= widget.question.answer(widget.input);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final answer = _answer;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _toggle,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.question.text,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                        height: 1.35,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Icon(
                    _terbuka ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              if (_terbuka && answer != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Divider(height: 1, color: colorScheme.outlineVariant),
                const SizedBox(height: AppSpacing.sm),
                if (answer.kosong)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 15,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          answer.detail,
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.45,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  )
                else ...[
                  Text(
                    answer.headline!,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      height: 1.15,
                      color: _warna(answer.tone, colorScheme),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    answer.detail,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.45,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _warna(AnswerTone tone, ColorScheme scheme) => switch (tone) {
        AnswerTone.bagus => AppColors.statusDone,
        AnswerTone.perhatian => AppColors.priorityHigh,
        AnswerTone.netral => scheme.onSurface,
      };
}

class _CatatanBawah extends StatelessWidget {
  const _CatatanBawah();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          margin: EdgeInsets.zero,
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.calculate_outlined, size: 16,
                    color: colorScheme.onSurfaceVariant),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Semua jawaban di halaman ini dihitung langsung dari '
                    'catatanmu — bukan ditebak. Gratis, seketika, dan tidak ada '
                    'data yang keluar dari HP-mu.',
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
        const SizedBox(height: AppSpacing.sm),
        Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            onTap: () => context.push('/profile/tanya/bebas'),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.forum_outlined, size: 18, color: _color),
            ),
            title: const Text(
              'Punya pertanyaan lain?',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
            ),
            subtitle: const Text(
              'Ketik bebas — butuh setup & berbayar',
              style: TextStyle(fontSize: 11.5),
            ),
            trailing: const Icon(Icons.chevron_right, size: 20),
          ),
        ),
      ],
    );
  }
}
