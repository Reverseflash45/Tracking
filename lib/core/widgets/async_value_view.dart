import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'empty_state.dart';

class AsyncValueView<T> extends StatelessWidget {
  const AsyncValueView({
    super.key,
    required this.value,
    required this.data,
    this.emptyIcon = Icons.inbox_outlined,
    this.emptyTitle = 'Belum ada data',
    this.emptySubtitle,
    this.isEmpty,
  });

  final AsyncValue<List<T>> value;
  final Widget Function(List<T> items) data;
  final IconData emptyIcon;
  final String emptyTitle;
  final String? emptySubtitle;
  final bool Function(List<T> items)? isEmpty;

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: (items) {
        final empty = isEmpty?.call(items) ?? items.isEmpty;
        if (empty) {
          return Center(
            child: EmptyState(icon: emptyIcon, title: emptyTitle, subtitle: emptySubtitle),
          );
        }
        return data(items);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: EmptyState(
          icon: Icons.error_outline,
          title: 'Terjadi kesalahan',
          subtitle: '$error',
        ),
      ),
    );
  }
}
