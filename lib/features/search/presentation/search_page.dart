import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/hero_header.dart';
import '../../../core/widgets/section_header.dart';
import '../../academic/presentation/academic_providers.dart';
import '../../document/data/document_repository.dart';
import '../../finance/data/finance_repository.dart';
import '../../goals/data/goal_repository.dart';
import '../../nutrition/data/nutrition_repository.dart';
import '../../vehicle/data/vehicle_repository.dart';
import '../../watchlist/data/watchlist_repository.dart';
import '../../wishlist/data/wishlist_repository.dart';
import '../../workout/presentation/workout_providers.dart';
import '../domain/global_search.dart';

const _color = AppColors.dashboard;

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Semua dari provider yang sudah dimuat — tidak ada query baru ke server,
    // jadi pencarian ini juga jalan tanpa sinyal.
    final hits = searchAll(
      query: _query,
      tasks: ref.watch(tasksProvider).value ?? const [],
      courses: ref.watch(coursesProvider).value ?? const [],
      sessions: ref.watch(workoutSessionsProvider).value ?? const [],
      foods: ref.watch(foodLogsProvider).value ?? const [],
      transactions: ref.watch(transactionsProvider).value ?? const [],
      wishlist: ref.watch(wishlistProvider).value ?? const [],
      media: ref.watch(watchlistProvider).value ?? const [],
      vehicles: ref.watch(vehiclesProvider).value ?? const [],
      services: ref.watch(vehicleServicesProvider).value ?? const [],
      documents: ref.watch(documentsProvider).value ?? const [],
      goals: ref.watch(goalsProvider).value ?? const [],
    );
    final grouped = groupHits(hits);
    final cukupPanjang = _query.trim().length >= kMinQueryLength;

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          HeroHeader(
            title: 'Cari',
            subtitle: 'Semua catatanmu dalam satu kotak',
            color: _color,
            leading: HeroIconButton(
              icon: Icons.arrow_back,
              tooltip: 'Kembali',
              onPressed: () => context.pop(),
            ),
          ),
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
                TextField(
                  controller: _controller,
                  autofocus: true,
                  onChanged: (value) => setState(() => _query = value),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Ketik apa saja',
                    prefixIcon: const Icon(Icons.search, size: 19),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            tooltip: 'Hapus',
                            onPressed: () {
                              _controller.clear();
                              setState(() => _query = '');
                            },
                          ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                if (!cukupPanjang)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.lg),
                    child: Text(
                      _query.isEmpty
                          ? 'Tugas, mata kuliah, latihan, makanan, pengeluaran, '
                              'wishlist, watchlist, kendaraan, dokumen, dan '
                              'target — semuanya sekaligus.'
                          : 'Ketik minimal $kMinQueryLength huruf — satu huruf '
                              'cocok dengan hampir semua catatan.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.5,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                else if (hits.isEmpty)
                  EmptyState(
                    icon: Icons.search_off,
                    title: 'Tidak ada yang cocok',
                    subtitle: 'Tidak ada catatan yang memuat "${_query.trim()}"',
                    color: _color,
                  )
                else
                  for (final entry in grouped.entries) ...[
                    SectionHeader(
                      title: '${entry.key.label} (${entry.value.length})',
                      icon: entry.key.icon,
                      color: _color,
                    ),
                    for (final hit in entry.value)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: _HitTile(hit: hit),
                      ),
                    const SizedBox(height: AppSpacing.md),
                  ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HitTile extends StatelessWidget {
  const _HitTile({required this.hit});

  final SearchHit hit;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: () => context.push(hit.tujuan),
        dense: true,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(hit.kind.icon, size: 16, color: _color),
        ),
        title: Text(
          hit.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
        subtitle: Text(
          hit.subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
        ),
        trailing: const Icon(Icons.chevron_right, size: 18),
      ),
    );
  }
}
