import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Tombol simpan yang menempel di bawah layar, jadi tidak perlu scroll dulu
/// untuk menyimpan form yang panjang.
class SaveBar extends StatelessWidget {
  const SaveBar({
    super.key,
    required this.color,
    required this.saving,
    required this.onPressed,
    this.label = 'Simpan',
  });

  final Color color;
  final bool saving;
  final VoidCallback onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        MediaQuery.of(context).padding.bottom + AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: FilledButton(
        onPressed: saving ? null : onPressed,
        style: FilledButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white),
        child: saving
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Text(label),
      ),
    );
  }
}
