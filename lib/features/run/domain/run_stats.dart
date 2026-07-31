import 'geo.dart';

/// Waktu tempuh satu kilometer penuh.
class KmSplit {
  const KmSplit({required this.km, required this.seconds});

  /// Kilometer ke berapa, mulai dari 1.
  final int km;

  final int seconds;

  String get label => formatPace(seconds.toDouble());
}

/// Detik per kilometer. Null kalau jaraknya masih nol.
double? paceSecondsPerKm({required double distanceMeters, required int seconds}) {
  if (distanceMeters <= 0) return null;
  return seconds / (distanceMeters / 1000);
}

/// Pace ditulis mm:ss, bukan desimal. "5:30/km" itu bahasa pelari;
/// "5,5 menit/km" bukan.
String formatPace(double secondsPerKm) {
  if (secondsPerKm.isNaN || secondsPerKm.isInfinite || secondsPerKm <= 0) {
    return '-';
  }
  final total = secondsPerKm.round();
  final minutes = total ~/ 60;
  final seconds = total % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

String formatDuration(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  final mm = m.toString().padLeft(2, '0');
  final ss = s.toString().padLeft(2, '0');
  return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
}

String formatDistance(double meters) {
  if (meters < 1000) return '${meters.round()} m';
  return '${(meters / 1000).toStringAsFixed(2)} km';
}

/// Hitung waktu tiap kilometer penuh dari rute.
///
/// Batas kilometer hampir tidak pernah jatuh persis di titik GPS, jadi waktunya
/// diinterpolasi di dalam ruas tempat batas itu terlewati. Tanpa itu, split
/// akan menempel ke titik terdekat dan ikut bergeser sampai beberapa detik.
List<KmSplit> computeSplits(List<GeoPoint> points) {
  if (points.length < 2) return const [];

  final splits = <KmSplit>[];
  var jarakKumulatif = 0.0;
  var kmBerikutnya = 1;
  var waktuKmSebelumnya = 0;

  for (var i = 1; i < points.length; i++) {
    final a = points[i - 1];
    final b = points[i];
    final ruas = haversineMeters(a.lat, a.lng, b.lat, b.lng);
    if (ruas <= 0) continue;

    final sebelum = jarakKumulatif;
    jarakKumulatif += ruas;

    // Satu ruas panjang bisa melewati lebih dari satu batas kilometer.
    while (jarakKumulatif >= kmBerikutnya * 1000) {
      final sisa = kmBerikutnya * 1000 - sebelum;
      final rasio = sisa / ruas;
      final waktuBatas =
          a.elapsedMs + ((b.elapsedMs - a.elapsedMs) * rasio).round();

      splits.add(KmSplit(
        km: kmBerikutnya,
        seconds: ((waktuBatas - waktuKmSebelumnya) / 1000).round(),
      ));

      waktuKmSebelumnya = waktuBatas;
      kmBerikutnya++;
    }
  }

  return splits;
}

/// Kotak pembatas rute, dipakai peta untuk mengatur zoom awal.
class RouteBounds {
  const RouteBounds({
    required this.minLat,
    required this.maxLat,
    required this.minLng,
    required this.maxLng,
  });

  final double minLat;
  final double maxLat;
  final double minLng;
  final double maxLng;

  double get centerLat => (minLat + maxLat) / 2;
  double get centerLng => (minLng + maxLng) / 2;
}

RouteBounds? routeBounds(List<GeoPoint> points) {
  if (points.isEmpty) return null;

  var minLat = points.first.lat;
  var maxLat = points.first.lat;
  var minLng = points.first.lng;
  var maxLng = points.first.lng;

  for (final point in points) {
    if (point.lat < minLat) minLat = point.lat;
    if (point.lat > maxLat) maxLat = point.lat;
    if (point.lng < minLng) minLng = point.lng;
    if (point.lng > maxLng) maxLng = point.lng;
  }

  return RouteBounds(
    minLat: minLat,
    maxLat: maxLat,
    minLng: minLng,
    maxLng: maxLng,
  );
}
