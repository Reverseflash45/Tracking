import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/hero_header.dart';
import '../data/run_repository.dart';
import '../domain/run_stats.dart';

const _color = AppColors.workout;
final _dateFormat = DateFormat('d MMMM y', 'id_ID');

/// Kartu lari untuk dibagikan.
///
/// Ukurannya dipatok 1080x1350 dalam satuan logis yang diperkecil, bukan
/// mengikuti lebar layar: hasilnya harus sama di HP mana pun, karena yang
/// dilihat orang lain adalah gambarnya, bukan layarmu.
class RunShareCard extends StatelessWidget {
  const RunShareCard({super.key, required this.run});

  final RunLog run;

  @override
  Widget build(BuildContext context) {
    final pace = run.pace;
    final points = [for (final p in run.route) LatLng(p.lat, p.lng)];
    final bounds = routeBounds(run.route);

    return Container(
      width: 320,
      height: 400,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: HeroHeader.gradientFor(_color),
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Stack(
        children: [
          // Rute jadi latar, bukan elemen utama: yang orang baca duluan
          // angkanya, petanya cuma memberi konteks.
          if (bounds != null && points.length >= 2)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Opacity(
                  opacity: 0.35,
                  child: FlutterMap(
                    options: MapOptions(
                      initialCameraFit: CameraFit.bounds(
                        bounds: LatLngBounds(
                          LatLng(bounds.minLat, bounds.minLng),
                          LatLng(bounds.maxLat, bounds.maxLng),
                        ),
                        padding: const EdgeInsets.all(48),
                      ),
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.none,
                      ),
                    ),
                    children: [
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: points,
                            strokeWidth: 5,
                            color: Colors.white,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.directions_run, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'LARI',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  formatDistance(run.distanceMeters),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 54,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    _Stat(
                      label: 'Waktu',
                      value: formatDuration(run.durationSeconds),
                    ),
                    const SizedBox(width: 28),
                    _Stat(
                      label: 'Pace',
                      value: pace == null ? '-' : '${formatPace(pace)}/km',
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  _dateFormat.format(run.startedAt),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.75),
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            height: 1.1,
          ),
        ),
      ],
    );
  }
}
