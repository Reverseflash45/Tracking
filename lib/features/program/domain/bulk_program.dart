/// Program latihan untuk menaikkan berat badan.
///
/// Datanya `const` Dart, bukan tabel Supabase: isinya sama untuk semua orang,
/// tidak pernah berubah per akun, dan dengan begini halamannya tetap terbuka
/// tanpa sinyal. Yang disimpan di database cuma pilihan variasi alat dan
/// tanggal mulai.
///
/// Nama gerakannya sengaja memakai ejaan yang sama dengan tangga progresi di
/// [ExerciseType] bodyweight ("Push Up", "Squat", "Row", "Plank", ...), supaya
/// saran progressive overload yang sudah ada di app ikut mengenali gerakan di
/// program ini. Kalau ejaannya beda, sarannya diam-diam berhenti muncul.
library;

import '../../workout/data/models/exercise_entry.dart';

/// Alat yang tersedia. Ini yang menentukan enam gerakan mana yang dipakai.
enum VariasiAlat {
  denganKursi(
    'kursi',
    'Punya kursi',
    'Kursi kokoh tanpa roda, tinggi sekitar lutut',
  ),
  tanpaKursi(
    'tanpa_kursi',
    'Tanpa kursi',
    'Cukup lantai dan sepasang dumbbell',
  );

  const VariasiAlat(this.dbValue, this.label, this.keterangan);

  final String dbValue;
  final String label;
  final String keterangan;

  static VariasiAlat fromDb(String? value) => VariasiAlat.values
      .firstWhere((e) => e.dbValue == value, orElse: () => VariasiAlat.tanpaKursi);
}

class GerakanProgram {
  const GerakanProgram({
    required this.nama,
    required this.tipe,
    required this.set,
    this.rep,
    this.detik,
    this.perSisi = false,
    required this.istirahatDetik,
    required this.cue,
    this.ganti,
  });

  final String nama;
  final ExerciseType tipe;
  final int set;

  /// Diisi untuk gerakan yang dihitung repetisi.
  final int? rep;

  /// Diisi untuk gerakan isometrik.
  final int? detik;

  /// Dikerjakan bergantian kiri-kanan, jadi satu "set" sebenarnya dua giliran.
  final bool perSisi;

  final int istirahatDetik;

  /// Satu petunjuk teknik yang paling sering dilanggar. Bukan panduan lengkap —
  /// satu kalimat yang benar-benar dibaca lebih berguna daripada lima yang
  /// dilewati.
  final String cue;

  /// Gerakan pengganti kalau yang ini masih terlalu berat.
  final String? ganti;

  /// "3 × 10", "3 × 8 / kaki", "3 × 40 detik".
  String get takaran {
    final jumlah = detik != null ? '$detik detik' : '$rep';
    return '$set × $jumlah${perSisi ? ' / sisi' : ''}';
  }

  /// Giliran yang benar-benar dikerjakan. Gerakan per sisi memakan dua kali
  /// lipat waktu, dan itu yang membuat perkiraan durasinya masuk akal.
  int get giliran => perSisi ? set * 2 : set;

  String get istirahatLabel =>
      istirahatDetik >= 60 ? '${istirahatDetik ~/ 60} menit' : '$istirahatDetik detik';
}

class SesiProgram {
  const SesiProgram({
    required this.kode,
    required this.fokus,
    required this.gerakan,
  });

  /// 'A' atau 'B'.
  final String kode;
  final String fokus;
  final List<GerakanProgram> gerakan;

  String get nama => 'Workout $kode';

  int get totalGiliran =>
      gerakan.fold(0, (jumlah, g) => jumlah + g.giliran);

  /// Perkiraan lama sesi, dibulatkan ke kelipatan 5 menit.
  ///
  /// Satu giliran dihitung 40 detik kerja (atau lama tahanan untuk isometrik)
  /// ditambah istirahatnya. Angkanya perkiraan, dan memang tidak perlu tepat —
  /// yang ingin kamu tahu cuma "muat tidak di jam segini".
  int get perkiraanMenit {
    var detik = 0;
    for (final g in gerakan) {
      final kerja = g.detik ?? 40;
      detik += g.giliran * (kerja + g.istirahatDetik);
    }
    final menit = (detik / 60).round();
    return ((menit + 2) ~/ 5) * 5;
  }
}

class ProgramNaikBerat {
  const ProgramNaikBerat({required this.variasi, required this.sesi});

  final VariasiAlat variasi;
  final List<SesiProgram> sesi;
}

// --- Gerakan yang sama di kedua variasi ---

const _gobletSquat = GerakanProgram(
  nama: 'Goblet Squat',
  tipe: ExerciseType.beban,
  set: 3,
  rep: 10,
  istirahatDetik: 90,
  cue: 'Turun sampai paha sejajar lantai, dada tetap tegak',
);

const _romanianDeadlift = GerakanProgram(
  nama: 'Romanian Deadlift',
  tipe: ExerciseType.beban,
  set: 3,
  rep: 10,
  istirahatDetik: 90,
  cue: 'Punggung datar, dorong pinggul ke belakang — terasa di paha belakang, '
      'bukan di pinggang',
);

const _shoulderPress = GerakanProgram(
  nama: 'Shoulder Press',
  tipe: ExerciseType.beban,
  set: 3,
  rep: 10,
  istirahatDetik: 90,
  cue: 'Siku sedikit di depan badan, bukan melebar penuh ke samping',
);

const _bicepCurl = GerakanProgram(
  nama: 'Bicep Curl',
  tipe: ExerciseType.beban,
  set: 3,
  rep: 10,
  istirahatDetik: 60,
  cue: 'Siku menempel di sisi badan, jangan mengayun pakai pinggang',
);

const _plank = GerakanProgram(
  nama: 'Plank',
  tipe: ExerciseType.isometrik,
  set: 3,
  detik: 40,
  istirahatDetik: 45,
  cue: 'Pinggul sejajar bahu — jangan naik, jangan melorot',
);

const _sidePlank = GerakanProgram(
  nama: 'Side Plank',
  tipe: ExerciseType.isometrik,
  set: 3,
  detik: 30,
  perSisi: true,
  istirahatDetik: 45,
  cue: 'Badan satu garis lurus dari bahu sampai mata kaki',
);

// --- Versi punya kursi ---

const _programKursi = ProgramNaikBerat(
  variasi: VariasiAlat.denganKursi,
  sesi: [
    SesiProgram(
      kode: 'A',
      fokus: 'Dorong + kaki',
      gerakan: [
        _gobletSquat,
        GerakanProgram(
          nama: 'Bulgarian Split Squat',
          tipe: ExerciseType.beban,
          set: 3,
          rep: 8,
          perSisi: true,
          istirahatDetik: 90,
          cue: 'Punggung kaki belakang di dudukan kursi, turun lurus ke bawah',
          ganti: 'Split Squat (dua kaki di lantai) kalau masih goyah',
        ),
        GerakanProgram(
          nama: 'Decline Push Up',
          tipe: ExerciseType.bodyweight,
          set: 3,
          rep: 10,
          istirahatDetik: 60,
          cue: 'Kaki di kursi, badan tetap satu garis dari kepala ke tumit',
          ganti: 'Push Up biasa kalau belum sampai 8 rep',
        ),
        _shoulderPress,
        GerakanProgram(
          nama: 'Tricep Dip',
          tipe: ExerciseType.bodyweight,
          set: 3,
          rep: 10,
          istirahatDetik: 60,
          cue: 'Tangan di tepi dudukan, siku menekuk ke belakang bukan melebar',
        ),
        _plank,
      ],
    ),
    SesiProgram(
      kode: 'B',
      fokus: 'Tarik + kaki',
      gerakan: [
        _romanianDeadlift,
        GerakanProgram(
          nama: 'Step Up',
          tipe: ExerciseType.beban,
          set: 3,
          rep: 10,
          perSisi: true,
          istirahatDetik: 90,
          cue: 'Dorong lewat tumit kaki yang di kursi, jangan menolak dengan kaki bawah',
        ),
        GerakanProgram(
          nama: 'One Arm Row',
          tipe: ExerciseType.beban,
          set: 3,
          rep: 12,
          perSisi: true,
          istirahatDetik: 75,
          cue: 'Satu tangan tumpu kursi, tarik siku ke belakang bukan ke samping',
        ),
        GerakanProgram(
          nama: 'Hip Thrust',
          tipe: ExerciseType.beban,
          set: 3,
          rep: 12,
          istirahatDetik: 75,
          cue: 'Punggung atas bersandar di dudukan kursi, tahan sebentar di puncak',
        ),
        _bicepCurl,
        _sidePlank,
      ],
    ),
  ],
);

// --- Versi tanpa kursi ---

const _programTanpaKursi = ProgramNaikBerat(
  variasi: VariasiAlat.tanpaKursi,
  sesi: [
    SesiProgram(
      kode: 'A',
      fokus: 'Dorong + kaki',
      gerakan: [
        _gobletSquat,
        GerakanProgram(
          nama: 'Split Squat',
          tipe: ExerciseType.beban,
          set: 3,
          rep: 8,
          perSisi: true,
          istirahatDetik: 90,
          cue: 'Kedua kaki tetap di tempat — turun lurus ke bawah, bukan melangkah',
        ),
        GerakanProgram(
          nama: 'Floor Press',
          tipe: ExerciseType.beban,
          set: 3,
          rep: 10,
          istirahatDetik: 90,
          cue: 'Berbaring di lantai, siku berhenti begitu menyentuh lantai',
          ganti: 'Push Up kalau dumbbell-nya sudah terlalu ringan',
        ),
        _shoulderPress,
        GerakanProgram(
          nama: 'Pike Push Up',
          tipe: ExerciseType.bodyweight,
          set: 3,
          rep: 8,
          istirahatDetik: 60,
          cue: 'Pinggul setinggi mungkin, ubun-ubun turun ke antara telapak tangan',
          ganti: 'Push Up biasa kalau bahu belum kuat',
        ),
        _plank,
      ],
    ),
    SesiProgram(
      kode: 'B',
      fokus: 'Tarik + kaki',
      gerakan: [
        _romanianDeadlift,
        GerakanProgram(
          nama: 'Bent Over Row',
          tipe: ExerciseType.beban,
          set: 3,
          rep: 12,
          istirahatDetik: 75,
          cue: 'Punggung datar, badan condong sekitar 45°, tarik siku ke belakang',
        ),
        GerakanProgram(
          nama: 'Reverse Lunge',
          tipe: ExerciseType.beban,
          set: 3,
          rep: 10,
          perSisi: true,
          istirahatDetik: 75,
          cue: 'Melangkah ke belakang, lutut belakang hampir menyentuh lantai',
        ),
        GerakanProgram(
          nama: 'Glute Bridge',
          tipe: ExerciseType.bodyweight,
          set: 3,
          rep: 15,
          istirahatDetik: 60,
          cue: 'Tumpuan di tumit, tahan sebentar di puncak',
          ganti: 'Taruh dumbbell di lipatan pinggul kalau sudah terlalu ringan',
        ),
        _bicepCurl,
        _sidePlank,
      ],
    ),
  ],
);

ProgramNaikBerat programNaikBerat(VariasiAlat variasi) => switch (variasi) {
      VariasiAlat.denganKursi => _programKursi,
      VariasiAlat.tanpaKursi => _programTanpaKursi,
    };

/// Tiga sesi seminggu, selang-seling: A B A, lalu minggu berikutnya B A B.
///
/// [nomor] dihitung dari nol. Dua sesi bergantian membuat tiap gerakan dilatih
/// sekitar 1,5 kali seminggu — cukup sering untuk tumbuh, cukup jarang untuk
/// pulih di antara sesi.
const int kSesiPerMinggu = 3;

SesiProgram sesiKe(ProgramNaikBerat program, int nomor) =>
    program.sesi[nomor % program.sesi.length];

/// Sudah berjalan berapa minggu sejak [mulai].
///
/// Minggu pertama disebut minggu 1, bukan minggu 0 — yang dihitung lamanya
/// menjalani, bukan jaraknya dari tanggal mulai.
int mingguKe(DateTime mulai, DateTime sekarang) {
  final hari = DateTime(sekarang.year, sekarang.month, sekarang.day)
      .difference(DateTime(mulai.year, mulai.month, mulai.day))
      .inDays;
  if (hari < 0) return 1;
  return hari ~/ 7 + 1;
}
