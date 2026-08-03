import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/progressive_overload.dart';

const _workoutColor = AppColors.workout;

IconData adviceIcon(OverloadAdvice advice) => switch (advice) {
      OverloadAdvice.naikBeban => Icons.trending_up,
      OverloadAdvice.naikVariasi => Icons.stairs_outlined,
      OverloadAdvice.naikRep => Icons.add_circle_outline,
      OverloadAdvice.naikDurasi => Icons.timer_outlined,
      OverloadAdvice.pertahankan => Icons.shield_outlined,
    };

String adviceLabel(OverloadAdvice advice) => switch (advice) {
      OverloadAdvice.naikBeban => 'Naik beban',
      OverloadAdvice.naikVariasi => 'Naik variasi',
      OverloadAdvice.naikRep => 'Tambah rep',
      OverloadAdvice.naikDurasi => 'Tambah durasi',
      OverloadAdvice.pertahankan => 'Mantapkan dulu',
    };

/// Strip ringkas di dalam form: "Terakhir X -> Target Y" + tombol isi otomatis.
class OverloadStrip extends StatelessWidget {
  const OverloadStrip({super.key, required this.suggestion, required this.onApply});

  final OverloadSuggestion suggestion;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.sm),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: _workoutColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _workoutColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(adviceIcon(suggestion.advice), size: 18, color: _workoutColor),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Target: ${suggestion.targetLabel}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: _workoutColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Terakhir ${suggestion.lastLabel}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          TextButton(
            onPressed: onApply,
            style: TextButton.styleFrom(
              foregroundColor: _workoutColor,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              visualDensity: VisualDensity.compact,
            ),
            child: const Text('Pakai', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

/// Kartu penuh untuk halaman progress: target berikutnya + alasannya.
class OverloadCard extends StatelessWidget {
  const OverloadCard({super.key, required this.suggestion});

  final OverloadSuggestion suggestion;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _workoutColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(adviceIcon(suggestion.advice), size: 18, color: _workoutColor),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    adviceLabel(suggestion.advice),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: _TargetColumn(
                    label: 'Sesi terakhir',
                    value: suggestion.lastLabel,
                    emphasis: false,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                  child: Icon(Icons.arrow_forward, size: 18, color: colorScheme.onSurfaceVariant),
                ),
                Expanded(
                  child: _TargetColumn(
                    label: 'Target berikutnya',
                    value: suggestion.targetLabel,
                    emphasis: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              suggestion.reason,
              style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _TargetColumn extends StatelessWidget {
  const _TargetColumn({required this.label, required this.value, required this.emphasis});

  final String label;
  final String value;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: emphasis ? 16 : 14,
            color: emphasis ? _workoutColor : colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
