import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/hero_header.dart';
import '../../../core/widgets/section_header.dart';
import '../data/run_repository.dart';
import '../domain/geo.dart';
import '../domain/run_stats.dart';
import 'run_tracker_page.dart';

const _color = AppColors.workout;
final _dateFormat = DateFormat('EEEE, d MMM y · HH:mm', 'id_ID');
final _shortDate = DateFormat('d MMM', 'id_ID');

class RunHistoryPage extends ConsumerWidget {
  const RunHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runsAsync = ref.watch(runsProvider);
    final runs = runsAsync.value ?? const <RunLog>[];

    final totalMeters = runs.fold<double>(0, (sum, run) => sum + run.distanceMeters);
    final now = DateTime.now();
    final bulanIni = runs
        .where((r) => r.startedAt.year == now.year && r.startedAt.month == now.month)
        .fold<double>(0, (sum, run) => sum + run.distanceMeters);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/workout/run/track');
          ref.invalidate(runsProvider);
        },
        backgroundColor: _color,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.play_arrow),
        label: const Text('Mulai Lari'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(runsProvider),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            HeroHeader(
              title: 'Lari',
              subtitle: 'Jarak, pace, dan rutemu',
              color: _color,
              leading: HeroIconButton(
                icon: Icons.arrow_back,
                tooltip: 'Kembali',
                onPressed: () => context.pop(),
              ),
              stats: [
                HeroStatData(
                  icon: Icons.route,
                  value: formatDistance(totalMeters),
                  label: 'Total Jarak',
                ),
                HeroStatData(
                  icon: Icons.calendar_month_outlined,
                  value: formatDistance(bulanIni),
                  label: 'Bulan Ini',
                ),
                HeroStatData(
                  icon: Icons.directions_run,
                  value: '${runs.length}',
                  label: 'Sesi',
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.md,
                96,
              ),
              child: runsAsync.when(
                data: (items) => items.isEmpty
                    ? EmptyState(
                        icon: Icons.directions_run,
                        title: 'Belum ada catatan lari',
                        subtitle: runTrackingSupported
                            ? 'Tekan "Mulai Lari" saat kamu siap berangkat'
                            : 'Perekaman lari hanya tersedia di HP',
                        color: _color,
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final run in items)
                            Padding(
                              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                              child: _RunCard(run: run),
                            ),
                        ],
                      ),
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, _) => EmptyState(
                  icon: Icons.error_outline,
                  title: 'Gagal memuat',
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

class _RunCard extends ConsumerWidget {
  const _RunCard({required this.run});

  final RunLog run;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final pace = run.pace;

    return Dismissible(
      key: ValueKey(run.id),
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
          title: const Text('Hapus catatan lari?'),
          content: Text(
            'Lari ${formatDistance(run.distanceMeters)} pada '
            '${_shortDate.format(run.startedAt)} akan dihapus.',
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
      ),
      onDismissed: (_) async {
        await ref.read(runRepositoryProvider).deleteRun(run.id);
        ref.invalidate(runsProvider);
      },
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => _RunDetailPage(run: run)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _dateFormat.format(run.startedAt),
                  style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatDistance(run.distanceMeters),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: _color,
                        height: 1,
                      ),
                    ),
                    const Spacer(),
                    _Pill(
                      icon: Icons.timer_outlined,
                      label: formatDuration(run.durationSeconds),
                    ),
                    const SizedBox(width: 10),
                    _Pill(
                      icon: Icons.speed,
                      label: pace == null ? '-' : '${formatPace(pace)}/km',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: color)),
      ],
    );
  }
}

class _RunDetailPage extends StatelessWidget {
  const _RunDetailPage({required this.run});

  final RunLog run;

  @override
  Widget build(BuildContext context) {
    final splits = computeSplits(run.route);
    final pace = run.pace;

    return Scaffold(
      appBar: AppBar(title: Text(formatDistance(run.distanceMeters))),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text(
            _dateFormat.format(run.startedAt),
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _DetailStat(
                  value: formatDuration(run.durationSeconds),
                  label: 'Waktu Bergerak',
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _DetailStat(
                  value: pace == null ? '-' : formatPace(pace),
                  label: 'Pace /km',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          const SectionHeader(title: 'Rute', icon: Icons.map_outlined, color: _color),
          _RouteMap(route: run.route),
          if (splits.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            const SectionHeader(
              title: 'KmSplit per Kilometer',
              icon: Icons.timeline,
              color: _color,
            ),
            Card(
              child: Column(
                children: [
                  for (final split in splits) _SplitRow(split: split, splits: splits),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailStat extends StatelessWidget {
  const _DetailStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SplitRow extends StatelessWidget {
  const _SplitRow({required this.split, required this.splits});

  final KmSplit split;
  final List<KmSplit> splits;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tercepat = splits.map((s) => s.seconds).reduce((a, b) => a < b ? a : b);
    final terlama = splits.map((s) => s.seconds).reduce((a, b) => a > b ? a : b);

    // Bar relatif terhadap split terlama, jadi perbedaan antar kilometer
    // langsung kelihatan tanpa perlu membandingkan angka satu per satu.
    final ratio = terlama == 0 ? 0.0 : split.seconds / terlama;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '${split.km}',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 8,
                backgroundColor: colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(
                  split.seconds == tercepat ? AppColors.statusDone : _color,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            width: 48,
            child: Text(
              split.label,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteMap extends StatelessWidget {
  const _RouteMap({required this.route});

  final List<GeoPoint> route;

  @override
  Widget build(BuildContext context) {
    final bounds = routeBounds(route);
    if (bounds == null || route.length < 2) {
      return const Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
          child: EmptyState(
            icon: Icons.map_outlined,
            title: 'Rute tidak terekam',
            subtitle: 'Sinyal GPS-nya terlalu lemah untuk menggambar jalur',
            color: _color,
          ),
        ),
      );
    }

    final points = [for (final p in route) LatLng(p.lat, p.lng)];

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 280,
        child: FlutterMap(
          options: MapOptions(
            initialCameraFit: CameraFit.bounds(
              bounds: LatLngBounds(
                LatLng(bounds.minLat, bounds.minLng),
                LatLng(bounds.maxLat, bounds.maxLng),
              ),
              padding: const EdgeInsets.all(32),
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              // Wajib diisi sesuai kebijakan pemakaian tile OpenStreetMap.
              userAgentPackageName: 'com.example.tracking',
            ),
            PolylineLayer(
              polylines: [
                Polyline(points: points, strokeWidth: 4, color: _color),
              ],
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: points.first,
                  child: const _RouteDot(color: AppColors.statusDone),
                ),
                Marker(
                  point: points.last,
                  child: const _RouteDot(color: AppColors.priorityHigh),
                ),
              ],
            ),
            // Atribusi OpenStreetMap wajib ditampilkan, bukan opsional.
            RichAttributionWidget(
              attributions: [
                TextSourceAttribution(
                  'OpenStreetMap contributors',
                  onTap: () => launchUrl(
                    Uri.parse('https://openstreetmap.org/copyright'),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteDot extends StatelessWidget {
  const _RouteDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
    );
  }
}
