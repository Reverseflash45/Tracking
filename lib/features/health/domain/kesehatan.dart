/// Mengolah data dari Health Connect (langkah, tidur, detak jantung).
///
/// Murni — tanpa plugin atau jaringan — supaya aturan impornya bisa diuji.
library;

/// Penanda di kolom catatan untuk tidur yang diimpor dari Health Connect.
///
/// Baris berpenanda ini boleh diperbarui lagi saat jam tangan menyinkronkan
/// data yang lebih lengkap. Baris tanpa penanda — yang kamu ketik sendiri —
/// tidak pernah ditimpa.
const String kPenandaHealthConnect = 'Dari Health Connect';

/// Tidur siang: sesi pendek (di bawah [kMinTidurMalam]) yang dimulai antara
/// jam 09.00 dan 19.00. Tidak dijumlahkan ke tidur malam.
///
/// Dua syarat, bukan hanya durasi: tidur yang terpecah — bangun jam 5 lalu
/// tidur lagi sampai jam 7 — juga menghasilkan sesi pendek, dan itu bagian
/// dari tidur malam.
const Duration kMinTidurMalam = Duration(hours: 3);

bool _tidurSiang(SesiTidur s) =>
    s.lama < kMinTidurMalam && s.mulai.hour >= 9 && s.mulai.hour < 19;

/// Satu sesi tidur dari Health Connect.
class SesiTidur {
  const SesiTidur({required this.mulai, required this.selesai});

  final DateTime mulai;
  final DateTime selesai;

  Duration get lama => selesai.difference(mulai);
}

DateTime _tanggal(DateTime t) => DateTime(t.year, t.month, t.day);

/// Lama tidur per tanggal bangun, dalam jam.
///
/// Sama dengan aturan catatan tidur di app: tidur dicatat di tanggal bangun.
/// Tidur yang terpecah (bangun jam 3, tidur lagi sampai jam 7) dijumlahkan.
/// Tidur siang tidak dihitung, dan sesi yang tumpang tindih (dua jam tangan
/// mencatat malam yang sama) hanya dihitung sekali.
Map<DateTime, double> tidurPerHari(List<SesiTidur> sesi) {
  final urut = sesi.where((s) => !_tidurSiang(s) && s.lama > Duration.zero).toList()
    ..sort((a, b) => a.mulai.compareTo(b.mulai));

  final perHari = <DateTime, Duration>{};
  DateTime? sampai;
  for (final s in urut) {
    // Bagian yang sudah tercakup sesi sebelumnya dilewati.
    final mulai = sampai != null && s.mulai.isBefore(sampai) ? sampai : s.mulai;
    if (!s.selesai.isAfter(mulai)) continue;
    final hari = _tanggal(s.selesai);
    perHari[hari] = (perHari[hari] ?? Duration.zero) + s.selesai.difference(mulai);
    sampai = s.selesai;
  }

  return {
    for (final e in perHari.entries)
      // Dibulatkan ke 0,1 jam, dan dibatasi 24 seperti kolom di database.
      e.key: (e.value.inMinutes / 60 * 10).round().clamp(1, 240) / 10,
  };
}

/// Catatan tidur yang sudah ada, sejauh yang perlu diketahui untuk impor.
class TidurTercatat {
  const TidurTercatat({required this.tanggal, required this.jam, this.kualitas, this.catatan});

  final DateTime tanggal;
  final double jam;
  final int? kualitas;
  final String? catatan;

  bool get dariHealthConnect => catatan == kPenandaHealthConnect;
}

/// Satu baris tidur yang akan ditulis.
class ImporTidur {
  const ImporTidur({required this.tanggal, required this.jam, this.kualitas});

  final DateTime tanggal;
  final double jam;

  /// Kualitas yang sudah kamu isi sebelumnya dipertahankan.
  final int? kualitas;
}

/// Tidur mana yang perlu ditulis ke database.
///
/// Hari yang belum dicatat diisi. Hari yang dicatat dari Health Connect
/// diperbarui kalau angkanya berubah. Hari yang kamu catat sendiri tidak
/// disentuh, dan hari ini hanya diisi setelah ada tidur yang selesai.
List<ImporTidur> rencanaImporTidur({
  required Map<DateTime, double> dariHealthConnect,
  required List<TidurTercatat> tercatat,
}) {
  final perTanggal = {for (final t in tercatat) _tanggal(t.tanggal): t};
  final hasil = <ImporTidur>[];

  for (final e in dariHealthConnect.entries) {
    final ada = perTanggal[_tanggal(e.key)];
    if (ada == null) {
      hasil.add(ImporTidur(tanggal: e.key, jam: e.value));
    } else if (ada.dariHealthConnect && (ada.jam - e.value).abs() >= 0.05) {
      hasil.add(ImporTidur(tanggal: e.key, jam: e.value, kualitas: ada.kualitas));
    }
  }

  hasil.sort((a, b) => a.tanggal.compareTo(b.tanggal));
  return hasil;
}

/// Langkah dalam satu hari.
class LangkahHarian {
  const LangkahHarian({required this.tanggal, required this.langkah});

  final DateTime tanggal;
  final int langkah;
}

/// Rata-rata langkah per hari, tanpa hari yang nol (biasanya jam tangan tidak
/// dipakai, bukan benar-benar diam seharian). Null kalau semuanya nol.
int? rataRataLangkah(List<LangkahHarian> hari) {
  final terisi = hari.where((h) => h.langkah > 0).toList();
  if (terisi.isEmpty) return null;
  return (terisi.fold<int>(0, (n, h) => n + h.langkah) / terisi.length).round();
}
