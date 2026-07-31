/// Posisi tubuh pada sumbu gerakan yang sedang dilacak.
enum RepPhase {
  /// Sendi menekuk — bawah pada squat/push up, atas pada bicep curl.
  tekuk,

  /// Sendi lurus — berdiri tegak, lengan terkunci.
  lurus,
}

/// Satu repetisi yang selesai terhitung.
class RepEvent {
  const RepEvent({
    required this.index,
    required this.minAngle,
    required this.maxAngle,
    required this.durationMs,
  });

  /// Nomor repetisi, mulai dari 1.
  final int index;

  final double minAngle;
  final double maxAngle;

  /// Rentang gerak yang benar-benar dilalui pada repetisi ini.
  double get rangeOfMotion => maxAngle - minAngle;

  final int durationMs;
}

/// Penghitung repetisi berbasis dua ambang.
///
/// Memakai satu ambang (mis. "sudut < 90 berarti satu rep") akan menghitung
/// berkali-kali saat sudutnya bergetar di sekitar angka itu. Dengan dua ambang
/// yang berjauhan, tubuh harus benar-benar melewati seluruh rentang gerak dulu
/// sebelum repetisi berikutnya bisa dihitung.
class RepCounter {
  RepCounter({
    required this.flexBelow,
    required this.extendAbove,
    required this.countOn,
  }) : assert(flexBelow < extendAbove, 'Ambang tekuk harus di bawah ambang lurus');

  /// Sudut di bawah nilai ini dianggap posisi menekuk.
  final double flexBelow;

  /// Sudut di atas nilai ini dianggap posisi lurus.
  final double extendAbove;

  /// Fase yang kedatangannya menutup satu repetisi.
  ///
  /// Push up, squat, dan curl dihitung saat kembali lurus. Jumping jack
  /// dihitung saat tangan kembali turun, yaitu saat masuk fase tekuk.
  final RepPhase countOn;

  int _reps = 0;
  int get reps => _reps;

  /// Null sampai tubuh terbaca berada di salah satu zona. Tanpa ini, memulai
  /// perekaman dalam posisi setengah jalan bisa langsung menghasilkan satu
  /// repetisi gratis.
  RepPhase? _phase;
  RepPhase? get phase => _phase;

  double? _min;
  double? _max;
  int? _cycleStartMs;

  /// Sudut terakhir yang terbaca, dipakai UI untuk menampilkan indikator.
  double? _lastAngle;
  double? get lastAngle => _lastAngle;

  /// Masukkan satu pembacaan sudut. Mengembalikan [RepEvent] kalau pembacaan
  /// ini menutup sebuah repetisi.
  ///
  /// [nowMs] dipisah sebagai parameter, bukan diambil dari jam sistem, supaya
  /// perilakunya bisa diuji tanpa menunggu waktu nyata.
  RepEvent? update(double angle, {required int nowMs}) {
    _lastAngle = angle;
    _min = _min == null ? angle : (angle < _min! ? angle : _min);
    _max = _max == null ? angle : (angle > _max! ? angle : _max);
    _cycleStartMs ??= nowMs;

    final RepPhase? zona;
    if (angle <= flexBelow) {
      zona = RepPhase.tekuk;
    } else if (angle >= extendAbove) {
      zona = RepPhase.lurus;
    } else {
      // Di antara dua ambang: belum jelas, jangan ubah fase.
      zona = null;
    }

    if (zona == null) return null;

    final sebelumnya = _phase;
    if (sebelumnya == zona) return null;

    _phase = zona;

    // Pembacaan pertama hanya menetapkan titik awal, belum menghitung apa pun.
    if (sebelumnya == null) {
      _resetCycle(nowMs);
      return null;
    }

    if (zona != countOn) {
      // Baru setengah jalan; rentang gerak terus dikumpulkan sampai kembali.
      return null;
    }

    _reps++;
    final event = RepEvent(
      index: _reps,
      minAngle: _min ?? angle,
      maxAngle: _max ?? angle,
      durationMs: nowMs - (_cycleStartMs ?? nowMs),
    );
    _resetCycle(nowMs);
    return event;
  }

  void _resetCycle(int nowMs) {
    _min = _lastAngle;
    _max = _lastAngle;
    _cycleStartMs = nowMs;
  }

  /// Lupakan fase saat tubuh hilang dari frame, supaya gerakan yang tidak
  /// terlihat tidak diam-diam terhitung sebagai repetisi saat tubuh muncul lagi.
  void interrupt() {
    _phase = null;
    _min = null;
    _max = null;
    _cycleStartMs = null;
    _lastAngle = null;
  }

  void reset() {
    _reps = 0;
    interrupt();
  }
}
