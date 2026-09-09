/// Gambar gerakan sebagai data, bukan berkas gambar.
///
/// Tiap gerakan digambarkan lewat titik sendi dalam ruang 0..1, lalu digambar
/// ulang oleh CustomPainter saat dipakai. Alasannya bukan menghemat ukuran APK:
///
/// - Warnanya ikut tema. Gambar PNG hitam jadi tidak terbaca di tema gelap, dan
///   menyiapkan dua berkas untuk tiap gerakan berarti dua kali kesempatan untuk
///   lupa memperbarui salah satunya.
/// - Tidak ada yang perlu diunduh. Gambar dari internet berarti halaman program
///   berhenti berguna persis di tempat kamu memakainya — kamar kos tanpa sinyal.
/// - Bisa diuji. "Gerakan ini belum punya gambar" jadi test yang gagal, bukan
///   kotak kosong yang baru ketahuan setelah APK terpasang.
///
/// Gambarnya skematik, bukan anatomis. Yang ingin disampaikan cuma bentuk
/// badan di awal dan di akhir gerakan; teknik yang sebenarnya tetap paling
/// jelas dari video, dan tiap gerakan menyediakan tautannya.
library;

import 'dart:ui' show Offset;

/// Titik sendi. Ruangnya 0..1, x ke kanan, y ke bawah, lantai di y = 0.90.
enum Sendi {
  kepala,
  leher,
  pinggul,
  sikuKiri,
  tanganKiri,
  sikuKanan,
  tanganKanan,
  lututKiri,
  kakiKiri,
  lututKanan,
  kakiKanan,
}

/// Benda selain badan yang perlu ikut digambar.
enum Prop {
  /// Garis lantai. Hampir selalu ada — tanpa lantai, badan yang condong
  /// terbaca seperti melayang.
  lantai,

  /// Kursi dilihat dari samping.
  kursi,

  /// Dumbbell di kedua tangan.
  beban,

  /// Dumbbell di satu tangan saja (one arm row).
  bebanKanan,
}

class Pose {
  const Pose(this.titik, {this.props = const [Prop.lantai], this.garisBantu});

  final Map<Sendi, Offset> titik;
  final List<Prop> props;

  /// Sepasang sendi yang dihubungkan garis putus-putus, untuk menunjukkan
  /// "punggung datar" atau "badan satu garis" — dua hal yang paling sering
  /// dilanggar dan paling sulit dijelaskan dengan kata.
  final (Sendi, Sendi)? garisBantu;

  Offset operator [](Sendi sendi) => titik[sendi] ?? const Offset(0.5, 0.5);
}

/// Satu gerakan: posisi awal, posisi akhir, dan keterangan masing-masing.
class DiagramGerakan {
  const DiagramGerakan({
    required this.mulai,
    required this.akhir,
    required this.labelMulai,
    required this.labelAkhir,
  });

  final Pose mulai;
  final Pose akhir;
  final String labelMulai;
  final String labelAkhir;
}

// --- Pose yang dipakai berulang ---

const _berdiriBeban = Pose({
  Sendi.kepala: Offset(0.44, 0.12),
  Sendi.leher: Offset(0.44, 0.21),
  Sendi.pinggul: Offset(0.44, 0.50),
  Sendi.sikuKanan: Offset(0.49, 0.35),
  Sendi.tanganKanan: Offset(0.49, 0.50),
  Sendi.sikuKiri: Offset(0.39, 0.35),
  Sendi.tanganKiri: Offset(0.39, 0.50),
  Sendi.lututKanan: Offset(0.47, 0.70),
  Sendi.kakiKanan: Offset(0.47, 0.90),
  Sendi.lututKiri: Offset(0.41, 0.70),
  Sendi.kakiKiri: Offset(0.41, 0.90),
}, props: [Prop.lantai, Prop.beban]);

// --- Katalog gerakan ---

const _gobletSquat = DiagramGerakan(
  labelMulai: 'Berdiri',
  labelAkhir: 'Turun',
  mulai: Pose({
    Sendi.kepala: Offset(0.44, 0.12),
    Sendi.leher: Offset(0.44, 0.21),
    Sendi.pinggul: Offset(0.44, 0.50),
    Sendi.sikuKanan: Offset(0.52, 0.32),
    Sendi.tanganKanan: Offset(0.48, 0.27),
    Sendi.sikuKiri: Offset(0.36, 0.32),
    Sendi.tanganKiri: Offset(0.41, 0.27),
    Sendi.lututKanan: Offset(0.48, 0.70),
    Sendi.kakiKanan: Offset(0.48, 0.90),
    Sendi.lututKiri: Offset(0.40, 0.70),
    Sendi.kakiKiri: Offset(0.40, 0.90),
  }, props: [Prop.lantai, Prop.beban]),
  akhir: Pose({
    Sendi.kepala: Offset(0.42, 0.22),
    Sendi.leher: Offset(0.42, 0.31),
    Sendi.pinggul: Offset(0.36, 0.62),
    Sendi.sikuKanan: Offset(0.50, 0.42),
    Sendi.tanganKanan: Offset(0.46, 0.37),
    Sendi.sikuKiri: Offset(0.34, 0.42),
    Sendi.tanganKiri: Offset(0.39, 0.37),
    Sendi.lututKanan: Offset(0.54, 0.66),
    Sendi.kakiKanan: Offset(0.48, 0.90),
    Sendi.lututKiri: Offset(0.46, 0.66),
    Sendi.kakiKiri: Offset(0.40, 0.90),
  }, props: [Prop.lantai, Prop.beban]),
);

const _romanianDeadlift = DiagramGerakan(
  labelMulai: 'Berdiri',
  labelAkhir: 'Pinggul ke belakang',
  mulai: _berdiriBeban,
  akhir: Pose({
    Sendi.kepala: Offset(0.24, 0.30),
    Sendi.leher: Offset(0.31, 0.32),
    Sendi.pinggul: Offset(0.56, 0.46),
    Sendi.sikuKanan: Offset(0.33, 0.48),
    Sendi.tanganKanan: Offset(0.34, 0.66),
    Sendi.sikuKiri: Offset(0.30, 0.48),
    Sendi.tanganKiri: Offset(0.31, 0.66),
    Sendi.lututKanan: Offset(0.52, 0.68),
    Sendi.kakiKanan: Offset(0.50, 0.90),
    Sendi.lututKiri: Offset(0.48, 0.68),
    Sendi.kakiKiri: Offset(0.46, 0.90),
  }, props: [Prop.lantai, Prop.beban], garisBantu: (Sendi.kepala, Sendi.pinggul)),
);

const _bentOverRow = DiagramGerakan(
  labelMulai: 'Lengan menggantung',
  labelAkhir: 'Siku ke belakang',
  mulai: Pose({
    Sendi.kepala: Offset(0.24, 0.30),
    Sendi.leher: Offset(0.31, 0.32),
    Sendi.pinggul: Offset(0.56, 0.46),
    Sendi.sikuKanan: Offset(0.33, 0.48),
    Sendi.tanganKanan: Offset(0.34, 0.66),
    Sendi.sikuKiri: Offset(0.30, 0.48),
    Sendi.tanganKiri: Offset(0.31, 0.66),
    Sendi.lututKanan: Offset(0.52, 0.68),
    Sendi.kakiKanan: Offset(0.50, 0.90),
    Sendi.lututKiri: Offset(0.48, 0.68),
    Sendi.kakiKiri: Offset(0.46, 0.90),
  }, props: [Prop.lantai, Prop.beban], garisBantu: (Sendi.kepala, Sendi.pinggul)),
  akhir: Pose({
    Sendi.kepala: Offset(0.24, 0.30),
    Sendi.leher: Offset(0.31, 0.32),
    Sendi.pinggul: Offset(0.56, 0.46),
    Sendi.sikuKanan: Offset(0.44, 0.30),
    Sendi.tanganKanan: Offset(0.34, 0.44),
    Sendi.sikuKiri: Offset(0.42, 0.30),
    Sendi.tanganKiri: Offset(0.32, 0.44),
    Sendi.lututKanan: Offset(0.52, 0.68),
    Sendi.kakiKanan: Offset(0.50, 0.90),
    Sendi.lututKiri: Offset(0.48, 0.68),
    Sendi.kakiKiri: Offset(0.46, 0.90),
  }, props: [Prop.lantai, Prop.beban], garisBantu: (Sendi.kepala, Sendi.pinggul)),
);

const _oneArmRow = DiagramGerakan(
  labelMulai: 'Tumpu kursi',
  labelAkhir: 'Siku ke belakang',
  mulai: Pose({
    Sendi.kepala: Offset(0.26, 0.32),
    Sendi.leher: Offset(0.33, 0.34),
    Sendi.pinggul: Offset(0.58, 0.46),
    Sendi.sikuKanan: Offset(0.36, 0.50),
    Sendi.tanganKanan: Offset(0.37, 0.68),
    Sendi.sikuKiri: Offset(0.28, 0.44),
    Sendi.tanganKiri: Offset(0.24, 0.56),
    Sendi.lututKanan: Offset(0.56, 0.68),
    Sendi.kakiKanan: Offset(0.54, 0.90),
    Sendi.lututKiri: Offset(0.50, 0.68),
    Sendi.kakiKiri: Offset(0.48, 0.90),
  }, props: [Prop.lantai, Prop.kursi, Prop.bebanKanan],
      garisBantu: (Sendi.kepala, Sendi.pinggul)),
  akhir: Pose({
    Sendi.kepala: Offset(0.26, 0.32),
    Sendi.leher: Offset(0.33, 0.34),
    Sendi.pinggul: Offset(0.58, 0.46),
    Sendi.sikuKanan: Offset(0.46, 0.32),
    Sendi.tanganKanan: Offset(0.37, 0.46),
    Sendi.sikuKiri: Offset(0.28, 0.44),
    Sendi.tanganKiri: Offset(0.24, 0.56),
    Sendi.lututKanan: Offset(0.56, 0.68),
    Sendi.kakiKanan: Offset(0.54, 0.90),
    Sendi.lututKiri: Offset(0.50, 0.68),
    Sendi.kakiKiri: Offset(0.48, 0.90),
  }, props: [Prop.lantai, Prop.kursi, Prop.bebanKanan],
      garisBantu: (Sendi.kepala, Sendi.pinggul)),
);

const _shoulderPress = DiagramGerakan(
  labelMulai: 'Tangan di bahu',
  labelAkhir: 'Dorong ke atas',
  mulai: Pose({
    Sendi.kepala: Offset(0.44, 0.16),
    Sendi.leher: Offset(0.44, 0.25),
    Sendi.pinggul: Offset(0.44, 0.54),
    Sendi.sikuKanan: Offset(0.56, 0.36),
    Sendi.tanganKanan: Offset(0.56, 0.24),
    Sendi.sikuKiri: Offset(0.32, 0.36),
    Sendi.tanganKiri: Offset(0.32, 0.24),
    Sendi.lututKanan: Offset(0.48, 0.72),
    Sendi.kakiKanan: Offset(0.48, 0.90),
    Sendi.lututKiri: Offset(0.40, 0.72),
    Sendi.kakiKiri: Offset(0.40, 0.90),
  }, props: [Prop.lantai, Prop.beban]),
  akhir: Pose({
    Sendi.kepala: Offset(0.44, 0.20),
    Sendi.leher: Offset(0.44, 0.29),
    Sendi.pinggul: Offset(0.44, 0.56),
    Sendi.sikuKanan: Offset(0.53, 0.20),
    Sendi.tanganKanan: Offset(0.56, 0.08),
    Sendi.sikuKiri: Offset(0.35, 0.20),
    Sendi.tanganKiri: Offset(0.32, 0.08),
    Sendi.lututKanan: Offset(0.48, 0.73),
    Sendi.kakiKanan: Offset(0.48, 0.90),
    Sendi.lututKiri: Offset(0.40, 0.73),
    Sendi.kakiKiri: Offset(0.40, 0.90),
  }, props: [Prop.lantai, Prop.beban]),
);

const _bicepCurl = DiagramGerakan(
  labelMulai: 'Lengan lurus',
  labelAkhir: 'Angkat ke bahu',
  mulai: _berdiriBeban,
  akhir: Pose({
    Sendi.kepala: Offset(0.44, 0.12),
    Sendi.leher: Offset(0.44, 0.21),
    Sendi.pinggul: Offset(0.44, 0.50),
    Sendi.sikuKanan: Offset(0.50, 0.40),
    Sendi.tanganKanan: Offset(0.53, 0.26),
    Sendi.sikuKiri: Offset(0.38, 0.40),
    Sendi.tanganKiri: Offset(0.35, 0.26),
    Sendi.lututKanan: Offset(0.47, 0.70),
    Sendi.kakiKanan: Offset(0.47, 0.90),
    Sendi.lututKiri: Offset(0.41, 0.70),
    Sendi.kakiKiri: Offset(0.41, 0.90),
  }, props: [Prop.lantai, Prop.beban]),
);

const _splitSquat = DiagramGerakan(
  labelMulai: 'Kaki depan-belakang',
  labelAkhir: 'Turun lurus',
  mulai: Pose({
    Sendi.kepala: Offset(0.44, 0.12),
    Sendi.leher: Offset(0.44, 0.21),
    Sendi.pinggul: Offset(0.44, 0.50),
    Sendi.sikuKanan: Offset(0.49, 0.35),
    Sendi.tanganKanan: Offset(0.49, 0.50),
    Sendi.sikuKiri: Offset(0.39, 0.35),
    Sendi.tanganKiri: Offset(0.39, 0.50),
    Sendi.lututKanan: Offset(0.58, 0.70),
    Sendi.kakiKanan: Offset(0.62, 0.90),
    Sendi.lututKiri: Offset(0.32, 0.70),
    Sendi.kakiKiri: Offset(0.26, 0.90),
  }, props: [Prop.lantai, Prop.beban], garisBantu: (Sendi.kepala, Sendi.pinggul)),
  akhir: Pose({
    Sendi.kepala: Offset(0.44, 0.26),
    Sendi.leher: Offset(0.44, 0.35),
    Sendi.pinggul: Offset(0.44, 0.62),
    Sendi.sikuKanan: Offset(0.49, 0.47),
    Sendi.tanganKanan: Offset(0.49, 0.62),
    Sendi.sikuKiri: Offset(0.39, 0.47),
    Sendi.tanganKiri: Offset(0.39, 0.62),
    Sendi.lututKanan: Offset(0.62, 0.68),
    Sendi.kakiKanan: Offset(0.62, 0.90),
    Sendi.lututKiri: Offset(0.30, 0.86),
    Sendi.kakiKiri: Offset(0.26, 0.90),
  }, props: [Prop.lantai, Prop.beban], garisBantu: (Sendi.kepala, Sendi.pinggul)),
);

const _bulgarianSplitSquat = DiagramGerakan(
  labelMulai: 'Kaki belakang di kursi',
  labelAkhir: 'Turun lurus',
  mulai: Pose({
    Sendi.kepala: Offset(0.48, 0.12),
    Sendi.leher: Offset(0.48, 0.21),
    Sendi.pinggul: Offset(0.48, 0.50),
    Sendi.sikuKanan: Offset(0.53, 0.35),
    Sendi.tanganKanan: Offset(0.53, 0.50),
    Sendi.sikuKiri: Offset(0.43, 0.35),
    Sendi.tanganKiri: Offset(0.43, 0.50),
    Sendi.lututKanan: Offset(0.60, 0.70),
    Sendi.kakiKanan: Offset(0.62, 0.90),
    Sendi.lututKiri: Offset(0.32, 0.62),
    Sendi.kakiKiri: Offset(0.20, 0.66),
  }, props: [Prop.lantai, Prop.kursi, Prop.beban],
      garisBantu: (Sendi.kepala, Sendi.pinggul)),
  akhir: Pose({
    Sendi.kepala: Offset(0.48, 0.26),
    Sendi.leher: Offset(0.48, 0.35),
    Sendi.pinggul: Offset(0.48, 0.62),
    Sendi.sikuKanan: Offset(0.53, 0.47),
    Sendi.tanganKanan: Offset(0.53, 0.62),
    Sendi.sikuKiri: Offset(0.43, 0.47),
    Sendi.tanganKiri: Offset(0.43, 0.62),
    Sendi.lututKanan: Offset(0.64, 0.70),
    Sendi.kakiKanan: Offset(0.62, 0.90),
    Sendi.lututKiri: Offset(0.30, 0.80),
    Sendi.kakiKiri: Offset(0.20, 0.66),
  }, props: [Prop.lantai, Prop.kursi, Prop.beban],
      garisBantu: (Sendi.kepala, Sendi.pinggul)),
);

const _reverseLunge = DiagramGerakan(
  labelMulai: 'Berdiri',
  labelAkhir: 'Langkah ke belakang',
  mulai: _berdiriBeban,
  akhir: Pose({
    Sendi.kepala: Offset(0.46, 0.24),
    Sendi.leher: Offset(0.46, 0.33),
    Sendi.pinggul: Offset(0.46, 0.60),
    Sendi.sikuKanan: Offset(0.51, 0.45),
    Sendi.tanganKanan: Offset(0.51, 0.60),
    Sendi.sikuKiri: Offset(0.41, 0.45),
    Sendi.tanganKiri: Offset(0.41, 0.60),
    Sendi.lututKanan: Offset(0.62, 0.68),
    Sendi.kakiKanan: Offset(0.62, 0.90),
    Sendi.lututKiri: Offset(0.30, 0.84),
    Sendi.kakiKiri: Offset(0.24, 0.90),
  }, props: [Prop.lantai, Prop.beban], garisBantu: (Sendi.kepala, Sendi.pinggul)),
);

const _stepUp = DiagramGerakan(
  labelMulai: 'Satu kaki di kursi',
  labelAkhir: 'Dorong lewat tumit',
  mulai: Pose({
    Sendi.kepala: Offset(0.30, 0.30),
    Sendi.leher: Offset(0.30, 0.39),
    Sendi.pinggul: Offset(0.30, 0.62),
    Sendi.sikuKanan: Offset(0.35, 0.50),
    Sendi.tanganKanan: Offset(0.35, 0.64),
    Sendi.sikuKiri: Offset(0.25, 0.50),
    Sendi.tanganKiri: Offset(0.25, 0.64),
    Sendi.lututKanan: Offset(0.48, 0.60),
    Sendi.kakiKanan: Offset(0.56, 0.66),
    Sendi.lututKiri: Offset(0.28, 0.78),
    Sendi.kakiKiri: Offset(0.28, 0.90),
  }, props: [Prop.lantai, Prop.kursi, Prop.beban]),
  akhir: Pose({
    Sendi.kepala: Offset(0.48, 0.08),
    Sendi.leher: Offset(0.48, 0.17),
    Sendi.pinggul: Offset(0.48, 0.40),
    Sendi.sikuKanan: Offset(0.53, 0.28),
    Sendi.tanganKanan: Offset(0.53, 0.42),
    Sendi.sikuKiri: Offset(0.43, 0.28),
    Sendi.tanganKiri: Offset(0.43, 0.42),
    Sendi.lututKanan: Offset(0.52, 0.54),
    Sendi.kakiKanan: Offset(0.56, 0.66),
    Sendi.lututKiri: Offset(0.40, 0.56),
    Sendi.kakiKiri: Offset(0.36, 0.70),
  }, props: [Prop.lantai, Prop.kursi, Prop.beban]),
);

const _hipThrust = DiagramGerakan(
  labelMulai: 'Pinggul di bawah',
  labelAkhir: 'Dorong ke atas',
  mulai: Pose({
    Sendi.kepala: Offset(0.20, 0.52),
    Sendi.leher: Offset(0.28, 0.54),
    Sendi.pinggul: Offset(0.52, 0.80),
    Sendi.sikuKanan: Offset(0.30, 0.64),
    Sendi.tanganKanan: Offset(0.38, 0.68),
    Sendi.sikuKiri: Offset(0.28, 0.64),
    Sendi.tanganKiri: Offset(0.36, 0.68),
    Sendi.lututKanan: Offset(0.72, 0.62),
    Sendi.kakiKanan: Offset(0.74, 0.90),
    Sendi.lututKiri: Offset(0.68, 0.62),
    Sendi.kakiKiri: Offset(0.70, 0.90),
  }, props: [Prop.lantai, Prop.kursi]),
  akhir: Pose({
    Sendi.kepala: Offset(0.20, 0.48),
    Sendi.leher: Offset(0.28, 0.50),
    Sendi.pinggul: Offset(0.54, 0.56),
    Sendi.sikuKanan: Offset(0.30, 0.60),
    Sendi.tanganKanan: Offset(0.38, 0.62),
    Sendi.sikuKiri: Offset(0.28, 0.60),
    Sendi.tanganKiri: Offset(0.36, 0.62),
    Sendi.lututKanan: Offset(0.74, 0.58),
    Sendi.kakiKanan: Offset(0.74, 0.90),
    Sendi.lututKiri: Offset(0.70, 0.58),
    Sendi.kakiKiri: Offset(0.70, 0.90),
  }, props: [Prop.lantai, Prop.kursi], garisBantu: (Sendi.leher, Sendi.lututKanan)),
);

const _gluteBridge = DiagramGerakan(
  labelMulai: 'Punggung di lantai',
  labelAkhir: 'Angkat pinggul',
  mulai: Pose({
    Sendi.kepala: Offset(0.16, 0.86),
    Sendi.leher: Offset(0.25, 0.86),
    Sendi.pinggul: Offset(0.50, 0.86),
    Sendi.sikuKanan: Offset(0.32, 0.88),
    Sendi.tanganKanan: Offset(0.42, 0.89),
    Sendi.sikuKiri: Offset(0.30, 0.88),
    Sendi.tanganKiri: Offset(0.40, 0.89),
    Sendi.lututKanan: Offset(0.68, 0.60),
    Sendi.kakiKanan: Offset(0.72, 0.90),
    Sendi.lututKiri: Offset(0.64, 0.60),
    Sendi.kakiKiri: Offset(0.68, 0.90),
  }),
  akhir: Pose({
    Sendi.kepala: Offset(0.16, 0.86),
    Sendi.leher: Offset(0.25, 0.86),
    Sendi.pinggul: Offset(0.52, 0.62),
    Sendi.sikuKanan: Offset(0.32, 0.88),
    Sendi.tanganKanan: Offset(0.42, 0.89),
    Sendi.sikuKiri: Offset(0.30, 0.88),
    Sendi.tanganKiri: Offset(0.40, 0.89),
    Sendi.lututKanan: Offset(0.72, 0.60),
    Sendi.kakiKanan: Offset(0.72, 0.90),
    Sendi.lututKiri: Offset(0.68, 0.60),
    Sendi.kakiKiri: Offset(0.68, 0.90),
  }, garisBantu: (Sendi.leher, Sendi.lututKanan)),
);

const _floorPress = DiagramGerakan(
  labelMulai: 'Siku di lantai',
  labelAkhir: 'Dorong ke atas',
  mulai: Pose({
    Sendi.kepala: Offset(0.16, 0.84),
    Sendi.leher: Offset(0.25, 0.84),
    Sendi.pinggul: Offset(0.52, 0.86),
    Sendi.sikuKanan: Offset(0.28, 0.88),
    Sendi.tanganKanan: Offset(0.30, 0.72),
    Sendi.sikuKiri: Offset(0.26, 0.88),
    Sendi.tanganKiri: Offset(0.28, 0.72),
    Sendi.lututKanan: Offset(0.72, 0.62),
    Sendi.kakiKanan: Offset(0.76, 0.90),
    Sendi.lututKiri: Offset(0.68, 0.62),
    Sendi.kakiKiri: Offset(0.72, 0.90),
  }, props: [Prop.lantai, Prop.beban]),
  akhir: Pose({
    Sendi.kepala: Offset(0.16, 0.84),
    Sendi.leher: Offset(0.25, 0.84),
    Sendi.pinggul: Offset(0.52, 0.86),
    Sendi.sikuKanan: Offset(0.28, 0.68),
    Sendi.tanganKanan: Offset(0.29, 0.50),
    Sendi.sikuKiri: Offset(0.26, 0.68),
    Sendi.tanganKiri: Offset(0.27, 0.50),
    Sendi.lututKanan: Offset(0.72, 0.62),
    Sendi.kakiKanan: Offset(0.76, 0.90),
    Sendi.lututKiri: Offset(0.68, 0.62),
    Sendi.kakiKiri: Offset(0.72, 0.90),
  }, props: [Prop.lantai, Prop.beban]),
);

const _pushUp = DiagramGerakan(
  labelMulai: 'Lengan lurus',
  labelAkhir: 'Turun',
  mulai: Pose({
    Sendi.kepala: Offset(0.20, 0.46),
    Sendi.leher: Offset(0.29, 0.50),
    Sendi.pinggul: Offset(0.56, 0.62),
    Sendi.sikuKanan: Offset(0.28, 0.70),
    Sendi.tanganKanan: Offset(0.27, 0.90),
    Sendi.sikuKiri: Offset(0.26, 0.70),
    Sendi.tanganKiri: Offset(0.25, 0.90),
    Sendi.lututKanan: Offset(0.72, 0.74),
    Sendi.kakiKanan: Offset(0.86, 0.90),
    Sendi.lututKiri: Offset(0.70, 0.74),
    Sendi.kakiKiri: Offset(0.84, 0.90),
  }, garisBantu: (Sendi.kepala, Sendi.kakiKanan)),
  akhir: Pose({
    Sendi.kepala: Offset(0.20, 0.66),
    Sendi.leher: Offset(0.29, 0.69),
    Sendi.pinggul: Offset(0.56, 0.76),
    Sendi.sikuKanan: Offset(0.40, 0.72),
    Sendi.tanganKanan: Offset(0.27, 0.90),
    Sendi.sikuKiri: Offset(0.38, 0.72),
    Sendi.tanganKiri: Offset(0.25, 0.90),
    Sendi.lututKanan: Offset(0.74, 0.82),
    Sendi.kakiKanan: Offset(0.88, 0.90),
    Sendi.lututKiri: Offset(0.72, 0.82),
    Sendi.kakiKiri: Offset(0.86, 0.90),
  }, garisBantu: (Sendi.kepala, Sendi.kakiKanan)),
);

const _declinePushUp = DiagramGerakan(
  labelMulai: 'Kaki di kursi',
  labelAkhir: 'Turun',
  mulai: Pose({
    Sendi.kepala: Offset(0.16, 0.52),
    Sendi.leher: Offset(0.25, 0.55),
    Sendi.pinggul: Offset(0.52, 0.62),
    Sendi.sikuKanan: Offset(0.24, 0.72),
    Sendi.tanganKanan: Offset(0.23, 0.90),
    Sendi.sikuKiri: Offset(0.22, 0.72),
    Sendi.tanganKiri: Offset(0.21, 0.90),
    Sendi.lututKanan: Offset(0.68, 0.66),
    Sendi.kakiKanan: Offset(0.84, 0.68),
    Sendi.lututKiri: Offset(0.66, 0.66),
    Sendi.kakiKiri: Offset(0.82, 0.68),
  }, props: [Prop.lantai, Prop.kursi], garisBantu: (Sendi.kepala, Sendi.kakiKanan)),
  akhir: Pose({
    Sendi.kepala: Offset(0.16, 0.70),
    Sendi.leher: Offset(0.25, 0.71),
    Sendi.pinggul: Offset(0.52, 0.70),
    Sendi.sikuKanan: Offset(0.36, 0.76),
    Sendi.tanganKanan: Offset(0.23, 0.90),
    Sendi.sikuKiri: Offset(0.34, 0.76),
    Sendi.tanganKiri: Offset(0.21, 0.90),
    Sendi.lututKanan: Offset(0.68, 0.70),
    Sendi.kakiKanan: Offset(0.84, 0.68),
    Sendi.lututKiri: Offset(0.66, 0.70),
    Sendi.kakiKiri: Offset(0.82, 0.68),
  }, props: [Prop.lantai, Prop.kursi], garisBantu: (Sendi.kepala, Sendi.kakiKanan)),
);

const _pikePushUp = DiagramGerakan(
  labelMulai: 'Pinggul tinggi',
  labelAkhir: 'Kepala turun',
  mulai: Pose({
    Sendi.kepala: Offset(0.30, 0.44),
    Sendi.leher: Offset(0.36, 0.40),
    Sendi.pinggul: Offset(0.52, 0.22),
    Sendi.sikuKanan: Offset(0.31, 0.58),
    Sendi.tanganKanan: Offset(0.26, 0.90),
    Sendi.sikuKiri: Offset(0.29, 0.58),
    Sendi.tanganKiri: Offset(0.24, 0.90),
    Sendi.lututKanan: Offset(0.66, 0.56),
    Sendi.kakiKanan: Offset(0.76, 0.90),
    Sendi.lututKiri: Offset(0.64, 0.56),
    Sendi.kakiKiri: Offset(0.74, 0.90),
  }),
  akhir: Pose({
    Sendi.kepala: Offset(0.26, 0.72),
    Sendi.leher: Offset(0.34, 0.62),
    Sendi.pinggul: Offset(0.52, 0.24),
    Sendi.sikuKanan: Offset(0.38, 0.72),
    Sendi.tanganKanan: Offset(0.26, 0.90),
    Sendi.sikuKiri: Offset(0.36, 0.72),
    Sendi.tanganKiri: Offset(0.24, 0.90),
    Sendi.lututKanan: Offset(0.66, 0.58),
    Sendi.kakiKanan: Offset(0.76, 0.90),
    Sendi.lututKiri: Offset(0.64, 0.58),
    Sendi.kakiKiri: Offset(0.74, 0.90),
  }),
);

const _tricepDip = DiagramGerakan(
  labelMulai: 'Lengan lurus',
  labelAkhir: 'Siku menekuk',
  mulai: Pose({
    Sendi.kepala: Offset(0.44, 0.34),
    Sendi.leher: Offset(0.44, 0.43),
    Sendi.pinggul: Offset(0.42, 0.62),
    Sendi.sikuKanan: Offset(0.31, 0.54),
    Sendi.tanganKanan: Offset(0.26, 0.66),
    Sendi.sikuKiri: Offset(0.29, 0.54),
    Sendi.tanganKiri: Offset(0.24, 0.66),
    Sendi.lututKanan: Offset(0.66, 0.66),
    Sendi.kakiKanan: Offset(0.78, 0.90),
    Sendi.lututKiri: Offset(0.64, 0.66),
    Sendi.kakiKiri: Offset(0.76, 0.90),
  }, props: [Prop.lantai, Prop.kursi]),
  akhir: Pose({
    Sendi.kepala: Offset(0.44, 0.48),
    Sendi.leher: Offset(0.44, 0.57),
    Sendi.pinggul: Offset(0.42, 0.74),
    Sendi.sikuKanan: Offset(0.22, 0.58),
    Sendi.tanganKanan: Offset(0.26, 0.66),
    Sendi.sikuKiri: Offset(0.20, 0.58),
    Sendi.tanganKiri: Offset(0.24, 0.66),
    Sendi.lututKanan: Offset(0.66, 0.76),
    Sendi.kakiKanan: Offset(0.78, 0.90),
    Sendi.lututKiri: Offset(0.64, 0.76),
    Sendi.kakiKiri: Offset(0.76, 0.90),
  }, props: [Prop.lantai, Prop.kursi]),
);

const _plank = DiagramGerakan(
  labelMulai: 'Tahan',
  labelAkhir: 'Badan satu garis',
  mulai: Pose({
    Sendi.kepala: Offset(0.18, 0.62),
    Sendi.leher: Offset(0.27, 0.65),
    Sendi.pinggul: Offset(0.54, 0.72),
    Sendi.sikuKanan: Offset(0.26, 0.90),
    Sendi.tanganKanan: Offset(0.16, 0.90),
    Sendi.sikuKiri: Offset(0.24, 0.90),
    Sendi.tanganKiri: Offset(0.14, 0.90),
    Sendi.lututKanan: Offset(0.72, 0.80),
    Sendi.kakiKanan: Offset(0.88, 0.90),
    Sendi.lututKiri: Offset(0.70, 0.80),
    Sendi.kakiKiri: Offset(0.86, 0.90),
  }, garisBantu: (Sendi.kepala, Sendi.kakiKanan)),
  akhir: Pose({
    Sendi.kepala: Offset(0.18, 0.62),
    Sendi.leher: Offset(0.27, 0.65),
    Sendi.pinggul: Offset(0.54, 0.72),
    Sendi.sikuKanan: Offset(0.26, 0.90),
    Sendi.tanganKanan: Offset(0.16, 0.90),
    Sendi.sikuKiri: Offset(0.24, 0.90),
    Sendi.tanganKiri: Offset(0.14, 0.90),
    Sendi.lututKanan: Offset(0.72, 0.80),
    Sendi.kakiKanan: Offset(0.88, 0.90),
    Sendi.lututKiri: Offset(0.70, 0.80),
    Sendi.kakiKiri: Offset(0.86, 0.90),
  }, garisBantu: (Sendi.kepala, Sendi.kakiKanan)),
);

const _sidePlank = DiagramGerakan(
  labelMulai: 'Tahan',
  labelAkhir: 'Pinggul jangan turun',
  mulai: Pose({
    Sendi.kepala: Offset(0.18, 0.56),
    Sendi.leher: Offset(0.26, 0.60),
    Sendi.pinggul: Offset(0.52, 0.70),
    Sendi.sikuKanan: Offset(0.24, 0.90),
    Sendi.tanganKanan: Offset(0.14, 0.90),
    Sendi.sikuKiri: Offset(0.30, 0.44),
    Sendi.tanganKiri: Offset(0.32, 0.28),
    Sendi.lututKanan: Offset(0.72, 0.80),
    Sendi.kakiKanan: Offset(0.90, 0.90),
    Sendi.lututKiri: Offset(0.72, 0.80),
    Sendi.kakiKiri: Offset(0.90, 0.90),
  }, garisBantu: (Sendi.kepala, Sendi.kakiKanan)),
  akhir: Pose({
    Sendi.kepala: Offset(0.18, 0.56),
    Sendi.leher: Offset(0.26, 0.60),
    Sendi.pinggul: Offset(0.52, 0.70),
    Sendi.sikuKanan: Offset(0.24, 0.90),
    Sendi.tanganKanan: Offset(0.14, 0.90),
    Sendi.sikuKiri: Offset(0.30, 0.44),
    Sendi.tanganKiri: Offset(0.32, 0.28),
    Sendi.lututKanan: Offset(0.72, 0.80),
    Sendi.kakiKanan: Offset(0.90, 0.90),
    Sendi.lututKiri: Offset(0.72, 0.80),
    Sendi.kakiKiri: Offset(0.90, 0.90),
  }, garisBantu: (Sendi.kepala, Sendi.kakiKanan)),
);

/// Gambar untuk satu nama gerakan, atau null kalau memang belum digambar.
///
/// Null dikembalikan apa adanya, bukan diganti gambar seadanya: gambar gerakan
/// yang salah lebih berbahaya daripada tidak ada gambar. Test menjaga supaya
/// tidak ada gerakan di program yang jatuh ke null.
const Map<String, DiagramGerakan> _katalog = {
  'Goblet Squat': _gobletSquat,
  'Romanian Deadlift': _romanianDeadlift,
  'Shoulder Press': _shoulderPress,
  'Bicep Curl': _bicepCurl,
  'Plank': _plank,
  'Side Plank': _sidePlank,
  'Bulgarian Split Squat': _bulgarianSplitSquat,
  'Split Squat': _splitSquat,
  'Reverse Lunge': _reverseLunge,
  'Step Up': _stepUp,
  'Hip Thrust': _hipThrust,
  'Glute Bridge': _gluteBridge,
  'One Arm Row': _oneArmRow,
  'Bent Over Row': _bentOverRow,
  'Floor Press': _floorPress,
  'Push Up': _pushUp,
  'Decline Push Up': _declinePushUp,
  'Pike Push Up': _pikePushUp,
  'Tricep Dip': _tricepDip,
};

DiagramGerakan? diagramGerakan(String nama) => _katalog[nama.trim()];

/// Nama gerakan yang sudah punya gambar. Dipakai test.
Iterable<String> get gerakanBergambar => _katalog.keys;
