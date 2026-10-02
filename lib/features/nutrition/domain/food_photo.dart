/// Hasil taksiran gizi dari foto makanan.
///
/// Semua angkanya perkiraan dari satu foto. Yang paling sering meleset adalah
/// berat — dan karena kalori dihitung dari berat, kamu bisa mengoreksi gramnya
/// lalu semua angka lain ikut menyesuaikan.
library;

import 'food_log.dart';

/// Di bawah angka ini taksiran ditandai "perkiraan kasar" di layar.
const int kBatasYakin = 60;

double _angka(dynamic value) {
  if (value is num && value.isFinite) return value.toDouble().clamp(0, 100000).toDouble();
  return 0;
}

class TebakanMakanan {
  const TebakanMakanan({
    required this.nama,
    required this.porsi,
    required this.gram,
    required this.kalori,
    required this.proteinG,
    required this.karboG,
    required this.lemakG,
    required this.yakin,
  });

  final String nama;

  /// Keterangan porsi dari AI, misal "1 centong, termasuk minyak goreng".
  final String porsi;

  final double gram;
  final double kalori;
  final double proteinG;
  final double karboG;
  final double lemakG;

  /// 0–100.
  final int yakin;

  bool get kasar => yakin < kBatasYakin;

  /// Item yang sama untuk berat [gramBaru], semua gizi diskalakan sebanding.
  ///
  /// Taksiran berat 0 g tidak bisa diskalakan (tidak ada dasar per gramnya),
  /// jadi gizinya dibiarkan apa adanya dan hanya gramnya yang berubah.
  TebakanMakanan denganGram(double gramBaru) {
    if (gram <= 0) {
      return TebakanMakanan(
        nama: nama,
        porsi: porsi,
        gram: gramBaru,
        kalori: kalori,
        proteinG: proteinG,
        karboG: karboG,
        lemakG: lemakG,
        yakin: yakin,
      );
    }
    final faktor = gramBaru / gram;
    return TebakanMakanan(
      nama: nama,
      porsi: porsi,
      gram: gramBaru,
      kalori: kalori * faktor,
      proteinG: proteinG * faktor,
      karboG: karboG * faktor,
      lemakG: lemakG * faktor,
      yakin: yakin,
    );
  }

  /// Catatan makanan siap simpan. Angka dibulatkan satu desimal — presisi di
  /// bawah itu cuma kesan akurat yang tidak dimiliki taksiran dari foto.
  FoodLog keFoodLog(Meal meal, DateTime waktu) {
    double bulat(double x) => (x * 10).round() / 10;
    return FoodLog(
      id: '',
      loggedOn: waktu,
      loggedAt: waktu,
      name: nama,
      meal: meal,
      calories: kalori.roundToDouble(),
      proteinG: bulat(proteinG),
      carbsG: bulat(karboG),
      fatG: bulat(lemakG),
      servingGrams: gram.roundToDouble(),
      confidencePercent: yakin.toDouble(),
    );
  }

  /// Null kalau barisnya tidak bisa dipakai (tanpa nama).
  static TebakanMakanan? fromJson(Map<String, dynamic> json) {
    final nama = (json['nama'] as String?)?.trim() ?? '';
    if (nama.isEmpty) return null;
    final yakin = json['yakin'];
    return TebakanMakanan(
      nama: nama,
      porsi: (json['porsi'] as String?)?.trim() ?? '',
      gram: _angka(json['gram']),
      kalori: _angka(json['kalori']),
      proteinG: _angka(json['protein_g']),
      karboG: _angka(json['karbo_g']),
      lemakG: _angka(json['lemak_g']),
      yakin: yakin is num ? yakin.round().clamp(0, 100) : 0,
    );
  }
}

/// Seluruh jawaban untuk satu foto.
class HasilFotoMakanan {
  const HasilFotoMakanan({required this.items, required this.catatan});

  final List<TebakanMakanan> items;

  /// Peringatan singkat dari AI soal apa yang paling mungkin meleset.
  final String catatan;

  static HasilFotoMakanan fromJson(Map<String, dynamic> json) {
    final mentah = json['items'];
    return HasilFotoMakanan(
      items: [
        if (mentah is List)
          for (final item in mentah)
            if (item is Map) ?TebakanMakanan.fromJson(Map<String, dynamic>.from(item)),
      ],
      catatan: (json['catatan'] as String?)?.trim() ?? '',
    );
  }
}

/// Total kalori dan makro dari item yang dipilih.
({double kalori, double protein, double karbo, double lemak}) totalTebakan(
  Iterable<TebakanMakanan> items,
) {
  var kalori = 0.0, protein = 0.0, karbo = 0.0, lemak = 0.0;
  for (final item in items) {
    kalori += item.kalori;
    protein += item.proteinG;
    karbo += item.karboG;
    lemak += item.lemakG;
  }
  return (kalori: kalori, protein: protein, karbo: karbo, lemak: lemak);
}

/// Jenis gambar dari beberapa byte pertamanya, bukan dari nama file — galeri
/// HP kadang memberi nama .jpg untuk file yang isinya HEIC atau PNG. Null
/// kalau bukan JPEG, PNG, atau WebP.
String? jenisGambar(List<int> bytes) {
  bool cocok(int dari, List<int> tanda) {
    if (bytes.length < dari + tanda.length) return false;
    for (var i = 0; i < tanda.length; i++) {
      if (bytes[dari + i] != tanda[i]) return false;
    }
    return true;
  }

  if (cocok(0, const [0xFF, 0xD8, 0xFF])) return 'image/jpeg';
  if (cocok(0, const [0x89, 0x50, 0x4E, 0x47])) return 'image/png';
  // "RIFF" .... "WEBP"
  if (cocok(0, const [0x52, 0x49, 0x46, 0x46]) && cocok(8, const [0x57, 0x45, 0x42, 0x50])) {
    return 'image/webp';
  }
  return null;
}

/// Porsi yang biasa kamu catat untuk satu makanan.
class PorsiKebiasaan {
  const PorsiKebiasaan({required this.nama, required this.gram, required this.kali});

  final String nama;

  /// Median berat — bukan rata-rata, supaya satu kali makan porsi jumbo tidak
  /// menggeser patokannya.
  final double gram;
  final int kali;

  Map<String, dynamic> toJson() => {'nama': nama, 'gram': gram.round(), 'kali': kali};
}

/// Porsi kebiasaan dari riwayat makan, dikirim bersama foto sebagai patokan.
///
/// Hanya catatan yang punya berat. Nama dicocokkan tanpa beda huruf besar
/// kecil, dan yang ditampilkan adalah ejaan yang paling sering kamu pakai.
/// Makanan yang baru sekali dicatat belum dianggap kebiasaan.
List<PorsiKebiasaan> porsiKebiasaan(
  List<FoodLog> logs, {
  required DateTime now,
  int hari = 90,
  int minKali = 2,
  int maks = 15,
}) {
  final batas = now.subtract(Duration(days: hari));
  final berat = <String, List<double>>{};
  final ejaan = <String, Map<String, int>>{};

  for (final log in logs) {
    final gram = log.servingGrams;
    if (gram == null || gram <= 0 || log.loggedOn.isBefore(batas)) continue;
    final nama = log.name.trim();
    if (nama.isEmpty) continue;
    final kunci = nama.toLowerCase();
    berat.putIfAbsent(kunci, () => []).add(gram);
    final e = ejaan.putIfAbsent(kunci, () => {});
    e[nama] = (e[nama] ?? 0) + 1;
  }

  double median(List<double> xs) {
    final s = [...xs]..sort();
    final m = s.length ~/ 2;
    return s.length.isOdd ? s[m] : (s[m - 1] + s[m]) / 2;
  }

  final hasil = [
    for (final MapEntry(key: kunci, value: xs) in berat.entries)
      if (xs.length >= minKali)
        PorsiKebiasaan(
          nama: (ejaan[kunci]!.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).first.key,
          gram: median(xs),
          kali: xs.length,
        ),
  ]..sort((a, b) {
      final k = b.kali.compareTo(a.kali);
      return k != 0 ? k : a.nama.compareTo(b.nama);
    });

  return hasil.length > maks ? hasil.sublist(0, maks) : hasil;
}
