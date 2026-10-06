/// Hari tanpa latihan yang otomatis jadi hari istirahat, dan status tiap hari
/// untuk strip "7 hari terakhir".
///
/// Murni — tanpa jaringan atau jam sistem kecuali lewat parameter — supaya
/// bisa diuji.
library;

/// Isi kolom catatan untuk hari istirahat yang dibuat otomatis.
///
/// Inilah yang membedakannya dari istirahat yang kamu tandai sendiri: yang
/// otomatis boleh dihapus app begitu ternyata ada latihan di hari itu (kamu
/// lupa mencatatnya), yang manual tidak pernah disentuh.
const String kCatatanIstirahatOtomatis = 'Otomatis: tidak ada latihan';

/// Paling jauh berapa hari ke belakang yang diisi otomatis. Kalau app tidak
/// dibuka sebulan, mengisi sebulan istirahat tidak menyelamatkan apa-apa —
/// streak tetap putus setelah dua hari — dan cuma memenuhi riwayat.
const int kMaksHariOtomatis = 14;

DateTime _tanggal(DateTime t) => DateTime(t.year, t.month, t.day);

/// Hari yang perlu ditandai istirahat otomatis: sejak [sejak] sampai kemarin,
/// yang tidak ada latihan maupun tanda istirahat.
///
/// Hari ini tidak pernah ikut — kamu masih bisa latihan nanti malam. Hari
/// sebelum latihan pertamamu juga tidak: sebelum itu kamu memang belum
/// memakai fitur ini, bukan sedang istirahat.
List<DateTime> hariIstirahatOtomatis({
  required Iterable<DateTime> aktif,
  required Iterable<DateTime> istirahat,
  required DateTime now,
  DateTime? sejak,
}) {
  final hariAktif = aktif.map(_tanggal).toSet();
  if (hariAktif.isEmpty) return const [];

  final sudahDitandai = istirahat.map(_tanggal).toSet();
  final kemarin = _tanggal(now).subtract(const Duration(days: 1));
  final pertama = hariAktif.reduce((a, b) => a.isBefore(b) ? a : b);

  var mulai = _tanggal(sejak ?? kemarin.subtract(const Duration(days: kMaksHariOtomatis - 1)));
  final batas = kemarin.subtract(const Duration(days: kMaksHariOtomatis - 1));
  if (mulai.isBefore(batas)) mulai = batas;
  if (mulai.isBefore(pertama)) mulai = pertama;

  final hasil = <DateTime>[];
  for (var d = mulai; !d.isAfter(kemarin); d = DateTime(d.year, d.month, d.day + 1)) {
    if (!hariAktif.contains(d) && !sudahDitandai.contains(d)) hasil.add(d);
  }
  return hasil;
}

enum StatusHari {
  /// Ada latihan atau lari.
  latihan,

  /// Kamu tandai sendiri sebagai istirahat.
  istirahat,

  /// Ditandai otomatis karena tidak ada latihan.
  istirahatOtomatis,

  /// Belum ada apa-apa (biasanya hari ini, atau fitur otomatisnya mati).
  kosong,
}

/// Status [jumlah] hari terakhir, yang paling lama di depan dan hari ini di
/// belakang. Latihan selalu menang atas tanda istirahat.
List<(DateTime, StatusHari)> statusHarian({
  required Iterable<DateTime> aktif,
  required Map<DateTime, String?> istirahat,
  required DateTime now,
  int jumlah = 7,
}) {
  final hariAktif = aktif.map(_tanggal).toSet();
  final catatan = {for (final e in istirahat.entries) _tanggal(e.key): e.value};
  final hariIni = _tanggal(now);

  return [
    for (var i = jumlah - 1; i >= 0; i--)
      () {
        final d = DateTime(hariIni.year, hariIni.month, hariIni.day - i);
        final StatusHari status;
        if (hariAktif.contains(d)) {
          status = StatusHari.latihan;
        } else if (catatan.containsKey(d)) {
          status = catatan[d] == kCatatanIstirahatOtomatis
              ? StatusHari.istirahatOtomatis
              : StatusHari.istirahat;
        } else {
          status = StatusHari.kosong;
        }
        return (d, status);
      }(),
  ];
}
