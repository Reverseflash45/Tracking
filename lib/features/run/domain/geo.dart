import 'dart:math';

/// Satu titik rute yang sudah lolos penyaringan.
class GeoPoint {
  const GeoPoint({
    required this.lat,
    required this.lng,
    required this.elapsedMs,
  });

  final double lat;
  final double lng;

  /// Milidetik sejak lari dimulai, tidak menghitung waktu jeda.
  final int elapsedMs;

  Map<String, dynamic> toJson() => {'lat': lat, 'lng': lng, 't': elapsedMs};

  factory GeoPoint.fromJson(Map<String, dynamic> json) => GeoPoint(
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
        elapsedMs: (json['t'] as num?)?.toInt() ?? 0,
      );
}

const double _earthRadiusMeters = 6371008.8;

/// Jarak lingkaran besar antara dua koordinat, dalam meter.
///
/// Haversine, bukan rumus Vincenty yang lebih teliti: pada jarak beberapa meter
/// antar titik GPS, selisih keduanya jauh lebih kecil daripada derau GPS itu
/// sendiri, jadi ketelitian tambahannya tidak ada artinya.
double haversineMeters(double lat1, double lng1, double lat2, double lng2) {
  const toRad = pi / 180;
  final dLat = (lat2 - lat1) * toRad;
  final dLng = (lng2 - lng1) * toRad;

  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(lat1 * toRad) * cos(lat2 * toRad) * sin(dLng / 2) * sin(dLng / 2);

  return 2 * _earthRadiusMeters * atan2(sqrt(a), sqrt(1 - a));
}

/// Ambang penyaringan sinyal GPS.
///
/// Tanpa penyaringan, berdiri diam di bawah pohon bisa "menempuh" ratusan meter
/// karena titiknya melompat-lompat. Tiga aturan di bawah ini yang membedakan
/// pelacak yang bisa dipercaya dari yang cuma menjumlahkan derau.
class RunFilterConfig {
  const RunFilterConfig({
    this.maxAccuracyMeters = 30,
    this.minMoveMeters = 5,
    this.maxSpeedMps = 12,
    this.maxConsecutiveRejects = 5,
  });

  /// Fix dengan ketidakpastian di atas ini dibuang. 30 m kira-kira batas saat
  /// sinyal mulai memantul di antara gedung.
  final double maxAccuracyMeters;

  /// Perpindahan di bawah ini dianggap goyangan sinyal, bukan langkah.
  final double minMoveMeters;

  /// 12 m/s ≈ 43 km/h — lebih cepat dari sprinter mana pun, jadi itu lompatan
  /// sinyal, bukan gerakan.
  final double maxSpeedMps;

  /// Setelah sekian penolakan beruntun, titik jangkar dianggap sudah basi
  /// (mis. sinyal baru pulih setelah lewat terowongan) dan dipasang ulang.
  /// Tanpa ini, satu jangkar yang salah bisa menolak seluruh sisa lari.
  final int maxConsecutiveRejects;
}

/// Alasan sebuah titik ditolak, dipakai untuk menjelaskan ke user kenapa
/// jaraknya tidak bertambah.
enum RejectReason { akurasiBuruk, terlaluDekat, lompatanSinyal }

class SampleResult {
  const SampleResult._({this.accepted, this.reason, this.addedMeters = 0});

  const SampleResult.accept(GeoPoint point, double addedMeters)
      : this._(accepted: point, addedMeters: addedMeters);

  const SampleResult.reject(RejectReason reason) : this._(reason: reason);

  final GeoPoint? accepted;
  final RejectReason? reason;
  final double addedMeters;

  bool get isAccepted => accepted != null;
}

/// Mengumpulkan titik GPS menjadi satu rute beserta total jaraknya.
class RunRecorder {
  RunRecorder({this.config = const RunFilterConfig()});

  final RunFilterConfig config;

  final List<GeoPoint> points = [];
  double distanceMeters = 0;

  GeoPoint? _anchor;
  int _consecutiveRejects = 0;

  /// Putuskan sambungan ke titik sebelumnya. Titik berikutnya jadi jangkar baru
  /// tanpa menambah jarak.
  ///
  /// Dipanggil setelah jeda: kalau kamu berjalan 50 meter selama berhenti di
  /// lampu merah, jarak itu bukan bagian dari larimu.
  void markGap() {
    _anchor = null;
    _consecutiveRejects = 0;
  }

  SampleResult add({
    required double lat,
    required double lng,
    required double accuracy,
    required int elapsedMs,
  }) {
    if (accuracy > config.maxAccuracyMeters) {
      return const SampleResult.reject(RejectReason.akurasiBuruk);
    }

    final anchor = _anchor;
    final point = GeoPoint(lat: lat, lng: lng, elapsedMs: elapsedMs);

    if (anchor == null) {
      _anchor = point;
      _consecutiveRejects = 0;
      points.add(point);
      return SampleResult.accept(point, 0);
    }

    final meters = haversineMeters(anchor.lat, anchor.lng, lat, lng);

    if (meters < config.minMoveMeters) {
      // Bukan penolakan yang mencurigakan — berdiri diam itu wajar — jadi
      // hitungan penolakan beruntun tidak dinaikkan.
      return const SampleResult.reject(RejectReason.terlaluDekat);
    }

    final dtSeconds = (elapsedMs - anchor.elapsedMs) / 1000;
    if (dtSeconds > 0 && meters / dtSeconds > config.maxSpeedMps) {
      _consecutiveRejects++;
      if (_consecutiveRejects < config.maxConsecutiveRejects) {
        return const SampleResult.reject(RejectReason.lompatanSinyal);
      }
      // Sinyal tampaknya sudah pulih di tempat lain; pasang jangkar baru dan
      // jangan hitung jarak lompatannya.
      _anchor = point;
      _consecutiveRejects = 0;
      points.add(point);
      return SampleResult.accept(point, 0);
    }

    _anchor = point;
    _consecutiveRejects = 0;
    points.add(point);
    distanceMeters += meters;
    return SampleResult.accept(point, meters);
  }
}
