import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AsyncValueView<T> extends StatelessWidget {
  const AsyncValueView({
    super.key,
    required this.value,
    required this.data,
    this.emptyMessage,
    this.isEmpty,
  });

  final AsyncValue<List<T>> value;
  final Widget Function(List<T> items) data;
  final String? emptyMessage;
  final bool Function(List<T> items)? isEmpty;

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: (items) {
        final empty = isEmpty?.call(items) ?? items.isEmpty;
        if (empty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                emptyMessage ?? 'Belum ada data',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        return data(items);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Terjadi kesalahan: $error', textAlign: TextAlign.center),
        ),
      ),
    );
  }
}
