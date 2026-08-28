import '../../academic/data/models/class_schedule.dart';

/// Jenis kegiatan. Dipakai memilih ikon, bukan memberi warna.
///
/// Sengaja tidak tiap jenis dapat warnanya sendiri: satu hari berisi belasan
/// baris, dan kalau kedelapannya berwarna, lini masanya berubah jadi pelangi
/// yang tidak menunjukkan apa-apa. Yang benar-benar perlu dibedakan cuma dua —
/// kelas yang datang dari Jadwal Kuliah, dan workout yang juga kamu catat di
/// tempat lain.
enum KategoriRutinitas {
  bangun('bangun', 'Bangun'),
  makan('makan', 'Makan'),
  kerja('kerja', 'Kerja / Nugas'),
  workout('workout', 'Workout'),
  ibadah('ibadah', 'Ibadah'),
  santai('santai', 'Santai'),
  tidur('tidur', 'Tidur'),
  lainnya('lainnya', 'Lainnya');

  const KategoriRutinitas(this.dbValue, this.label);

  final String dbValue;
  final String label;

  static KategoriRutinitas fromDb(String? value) => KategoriRutinitas.values
      .firstWhere((e) => e.dbValue == value, orElse: () => KategoriRutinitas.lainnya);
}

/// Satu kegiatan berulang di hari tertentu.
class RoutineItem {
  const RoutineItem({
    required this.id,
    required this.userId,
    required this.dayOfWeek,
    required this.startTime,
    this.endTime,
    required this.title,
    this.category = KategoriRutinitas.lainnya,
    this.note,
  });

  final String id;
  final String userId;

  /// 1 = Senin ... 7 = Minggu.
  final int dayOfWeek;

  /// Format 'HH:mm:ss' dari kolom `time` Postgres.
  final String startTime;

  /// Null berarti kegiatan sesaat, bukan rentang.
  final String? endTime;

  final String title;
  final KategoriRutinitas category;
  final String? note;

  factory RoutineItem.fromMap(Map<String, dynamic> map) => RoutineItem(
        id: map['id'] as String,
        userId: map['user_id'] as String,
        dayOfWeek: map['day_of_week'] as int,
        startTime: map['start_time'] as String,
        endTime: map['end_time'] as String?,
        title: map['title'] as String,
        category: KategoriRutinitas.fromDb(map['category'] as String?),
        note: map['note'] as String?,
      );
}

/// Satu baris di lini masa harian.
///
/// Rutinitas pribadi dan kelas dari Jadwal Kuliah berakhir di bentuk yang sama
/// supaya harimu bisa dibaca berurutan dari atas ke bawah. Yang tidak
/// disamakan: kelas tidak bisa diubah dari sini, karena sumbernya KRS — dan
/// menyalinnya ke tabel rutinitas berarti dua salinan yang mulai berbeda begitu
/// jadwal kuliahnya berubah.
class BarisHarian {
  const BarisHarian({
    required this.judul,
    required this.mulai,
    this.selesai,
    this.keterangan,
    this.kategori,
    this.routineId,
  });

  final String judul;

  /// 'HH:mm'.
  final String mulai;
  final String? selesai;

  /// Ruangan untuk kelas, catatan untuk rutinitas.
  final String? keterangan;

  /// Null untuk baris yang datang dari Jadwal Kuliah.
  final KategoriRutinitas? kategori;

  /// Null untuk baris yang datang dari Jadwal Kuliah.
  final String? routineId;

  bool get dariKuliah => routineId == null;

  /// Null kalau kegiatannya sesaat. Melewati tengah malam dihitung benar,
  /// supaya "22:30 tidur sampai 05:45" tidak jadi durasi negatif.
  int? get durasiMenit {
    final akhir = selesai;
    if (akhir == null) return null;
    final awal = menitDariJam(mulai);
    final habis = menitDariJam(akhir);
    return habis >= awal ? habis - awal : habis + 24 * 60 - awal;
  }
}

/// 'HH:mm' atau 'HH:mm:ss' jadi menit sejak tengah malam.
int menitDariJam(String jam) {
  final bagian = jam.split(':');
  return int.parse(bagian[0]) * 60 + int.parse(bagian[1]);
}

/// Gabungkan rutinitas pribadi dengan kelas pada [hari], terurut menurut jam.
///
/// Kelas PHL tidak ikut. Halaman ini menggambarkan pola mingguan, sedangkan PHL
/// terjadi pada satu tanggal tertentu — menampilkannya di sini berarti kelas
/// pengganti bulan lalu muncul tiap minggu selamanya.
List<BarisHarian> lineMasaHarian({
  required int hari,
  List<RoutineItem> rutinitas = const [],
  List<ClassSchedule> jadwal = const [],
}) {
  final baris = <BarisHarian>[
    for (final item in rutinitas)
      if (item.dayOfWeek == hari)
        BarisHarian(
          judul: item.title,
          mulai: item.startTime.substring(0, 5),
          selesai: item.endTime?.substring(0, 5),
          keterangan: (item.note?.trim().isEmpty ?? true) ? null : item.note!.trim(),
          kategori: item.category,
          routineId: item.id,
        ),
    for (final kelas in jadwal)
      if (kelas.dayOfWeek == hari && !kelas.isPhl)
        BarisHarian(
          judul: kelas.courseName,
          mulai: kelas.startTime.substring(0, 5),
          selesai: kelas.endTime.substring(0, 5),
          keterangan: kelas.room,
        ),
  ];

  baris.sort((a, b) {
    final jam = menitDariJam(a.mulai).compareTo(menitDariJam(b.mulai));
    return jam != 0 ? jam : a.judul.compareTo(b.judul);
  });
  return baris;
}

/// Menit yang benar-benar punya rentang.
///
/// Kegiatan sesaat tidak ikut dihitung, dan itu memang bukan nol jam — cuma
/// tidak diketahui. Angka ini dipakai sebagai "jam terisi", bukan "jam sibuk".
int menitTerisi(List<BarisHarian> baris) {
  var total = 0;
  for (final item in baris) {
    total += item.durasiMenit ?? 0;
  }
  return total;
}

/// "3j 30m", atau "45m" kalau kurang dari satu jam.
String labelDurasi(int menit) {
  if (menit <= 0) return '0m';
  final jam = menit ~/ 60;
  final sisa = menit % 60;
  if (jam == 0) return '${sisa}m';
  if (sisa == 0) return '${jam}j';
  return '${jam}j ${sisa}m';
}

/// Hari yang sudah punya isi, dipakai menandai pemilih hari.
Set<int> hariTerisi(List<RoutineItem> rutinitas) =>
    {for (final item in rutinitas) item.dayOfWeek};
