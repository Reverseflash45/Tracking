import '../../academic/data/models/task.dart';
import '../../nutrition/domain/daily_nutrition.dart';
import '../../nutrition/domain/food_log.dart';
import '../../workout/data/models/workout_session.dart';

enum WrappedPeriod {
  mingguan('Mingguan', 'minggu ini'),
  bulanan('Bulanan', 'bulan ini'),
  tahunan('Tahunan', 'tahun ini');

  const WrappedPeriod(this.label, this.phrase);

  final String label;

  /// Dipakai di kalimat, mis. "kamu menyelesaikan 12 tugas `minggu ini`".
  final String phrase;
}

/// Rentang periode, inklusif di kedua ujung pada level hari.
class WrappedRange {
  const WrappedRange(this.start, this.end);

  /// Awal hari pertama.
  final DateTime start;

  /// Akhir hari terakhir.
  final DateTime end;

  bool contains(DateTime moment) => !moment.isBefore(start) && !moment.isAfter(end);
}

WrappedRange rangeFor(WrappedPeriod period, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

  return switch (period) {
    // Minggu berjalan, Senin sampai hari ini.
    WrappedPeriod.mingguan =>
      WrappedRange(today.subtract(Duration(days: today.weekday - 1)), endOfToday),
    WrappedPeriod.bulanan => WrappedRange(DateTime(now.year, now.month), endOfToday),
    WrappedPeriod.tahunan => WrappedRange(DateTime(now.year), endOfToday),
  };
}

class Highlight {
  const Highlight(this.label, this.count);

  final String label;
  final int count;
}

class PersonalRecord {
  const PersonalRecord(this.exerciseName, this.weightKg);

  final String exerciseName;
  final double weightKg;
}

/// Ringkasan nutrisi selama periode Wrapped.
class NutritionRecap {
  const NutritionRecap({
    required this.hariTercatat,
    required this.totalKalori,
    required this.rataKalori,
    required this.rataProtein,
    required this.totalGelas,
    required this.makananFavorit,
  });

  /// Jumlah hari unik yang punya catatan makanan.
  final int hariTercatat;

  final double totalKalori;

  /// Rata-rata dibagi hari yang tercatat, bukan panjang periode — hari yang
  /// lupa dicatat bukan berarti tidak makan.
  final double rataKalori;
  final double rataProtein;

  final int totalGelas;
  final Highlight? makananFavorit;

  bool get kosong => hariTercatat == 0 && totalGelas == 0;

  static const empty = NutritionRecap(
    hariTercatat: 0,
    totalKalori: 0,
    rataKalori: 0,
    rataProtein: 0,
    totalGelas: 0,
    makananFavorit: null,
  );
}

class WrappedStats {
  const WrappedStats({
    required this.period,
    required this.range,
    required this.tugasSelesai,
    required this.tugasTepatWaktu,
    required this.sesiWorkout,
    required this.totalVolume,
    required this.hariAktif,
    required this.matkulTersibuk,
    required this.latihanFavorit,
    required this.prBeban,
    required this.hariPalingProduktif,
    required this.nutrisi,
    required this.persona,
  });

  final WrappedPeriod period;
  final WrappedRange range;
  final int tugasSelesai;
  final int tugasTepatWaktu;
  final int sesiWorkout;
  final double totalVolume;

  /// Jumlah hari unik yang ada aktivitasnya (tugas selesai atau workout).
  final int hariAktif;

  final Highlight? matkulTersibuk;
  final Highlight? latihanFavorit;
  final PersonalRecord? prBeban;

  /// 1 = Senin ... 7 = Minggu. Null kalau belum ada tugas yang selesai.
  final int? hariPalingProduktif;

  final NutritionRecap nutrisi;

  final String persona;

  bool get kosong => tugasSelesai == 0 && sesiWorkout == 0 && nutrisi.kosong;

  /// Dibulatkan ke bilangan bulat; 0 kalau belum ada tugas yang selesai.
  int get persenTepatWaktu =>
      tugasSelesai == 0 ? 0 : ((tugasTepatWaktu / tugasSelesai) * 100).round();
}

WrappedStats computeWrappedStats({
  required WrappedPeriod period,
  required DateTime now,
  required List<AcademicTask> tasks,
  required List<WorkoutSession> sessions,
  List<FoodLog> foods = const [],
  List<WaterLog> waters = const [],
}) {
  final range = rangeFor(period, now);

  // --- Tugas ---
  final selesai = tasks
      .where((task) => task.completedAt != null && range.contains(task.completedAt!))
      .toList();

  final tepatWaktu = selesai.where((task) => task.isOnTime).length;

  final perMatkul = <String, int>{};
  final perHari = <int, int>{};
  for (final task in selesai) {
    final matkul = task.courseName;
    if (matkul != null && matkul.trim().isNotEmpty) {
      perMatkul[matkul] = (perMatkul[matkul] ?? 0) + 1;
    }
    final weekday = task.completedAt!.weekday;
    perHari[weekday] = (perHari[weekday] ?? 0) + 1;
  }

  // --- Workout ---
  final sesiPeriode =
      sessions.where((session) => range.contains(session.sessionDate)).toList();

  var totalVolume = 0.0;
  final perLatihan = <String, int>{};
  PersonalRecord? pr;
  for (final session in sesiPeriode) {
    for (final exercise in session.exercises) {
      if (!exercise.type.pakaiVolume) continue;
      totalVolume += exercise.volume;
      perLatihan[exercise.exerciseName] = (perLatihan[exercise.exerciseName] ?? 0) + 1;

      final berat = exercise.weightKg;
      if (berat != null && (pr == null || berat > pr.weightKg)) {
        pr = PersonalRecord(exercise.exerciseName, berat);
      }
    }
  }

  // --- Nutrisi ---
  final nutrisi = _recapNutrisi(range: range, foods: foods, waters: waters);

  // --- Hari aktif ---
  // Sengaja tidak menghitung hari yang hanya ada catatan makan: mencatat
  // makanan bukan aktivitas, dan memasukkannya akan menggelembungkan angka ini.
  final hariAktif = <DateTime>{
    for (final task in selesai)
      DateTime(task.completedAt!.year, task.completedAt!.month, task.completedAt!.day),
    for (final session in sesiPeriode)
      DateTime(session.sessionDate.year, session.sessionDate.month, session.sessionDate.day),
  };

  return WrappedStats(
    period: period,
    range: range,
    tugasSelesai: selesai.length,
    tugasTepatWaktu: tepatWaktu,
    sesiWorkout: sesiPeriode.length,
    totalVolume: totalVolume,
    hariAktif: hariAktif.length,
    matkulTersibuk: _topEntry(perMatkul),
    latihanFavorit: _topEntry(perLatihan),
    prBeban: pr,
    hariPalingProduktif: _topKey(perHari),
    nutrisi: nutrisi,
    persona: _persona(
      tugasSelesai: selesai.length,
      tepatWaktu: tepatWaktu,
      sesiWorkout: sesiPeriode.length,
      hariCatatMakan: nutrisi.hariTercatat,
    ),
  );
}

NutritionRecap _recapNutrisi({
  required WrappedRange range,
  required List<FoodLog> foods,
  required List<WaterLog> waters,
}) {
  final dalamRentang = foods.where((food) => range.contains(food.loggedOn)).toList();
  final gelas = waters
      .where((water) => range.contains(water.loggedOn))
      .fold<int>(0, (sum, water) => sum + (water.ml / kGlassMl).round());

  if (dalamRentang.isEmpty) {
    return gelas == 0
        ? NutritionRecap.empty
        : NutritionRecap(
            hariTercatat: 0,
            totalKalori: 0,
            rataKalori: 0,
            rataProtein: 0,
            totalGelas: gelas,
            makananFavorit: null,
          );
  }

  var totalKalori = 0.0;
  var totalProtein = 0.0;
  final hari = <DateTime>{};
  final perMakanan = <String, int>{};

  for (final food in dalamRentang) {
    totalKalori += food.calories;
    totalProtein += food.proteinG;
    hari.add(DateTime(food.loggedOn.year, food.loggedOn.month, food.loggedOn.day));

    // Dikelompokkan tanpa peduli huruf besar/kecil supaya "Nasi Goreng" dan
    // "nasi goreng" tidak terhitung sebagai dua makanan berbeda.
    final key = food.name.trim().toLowerCase();
    if (key.isNotEmpty) perMakanan[key] = (perMakanan[key] ?? 0) + 1;
  }

  final favoritKey = _topEntry(perMakanan);
  final favoritNama = favoritKey == null
      ? null
      : dalamRentang
          .lastWhere((food) => food.name.trim().toLowerCase() == favoritKey.label)
          .name;

  return NutritionRecap(
    hariTercatat: hari.length,
    totalKalori: totalKalori,
    rataKalori: totalKalori / hari.length,
    rataProtein: totalProtein / hari.length,
    totalGelas: gelas,
    makananFavorit: favoritNama == null ? null : Highlight(favoritNama, favoritKey!.count),
  );
}

Highlight? _topEntry(Map<String, int> counts) {
  if (counts.isEmpty) return null;
  var best = counts.entries.first;
  for (final entry in counts.entries) {
    if (entry.value > best.value) best = entry;
  }
  return Highlight(best.key, best.value);
}

int? _topKey(Map<int, int> counts) {
  if (counts.isEmpty) return null;
  var best = counts.entries.first;
  for (final entry in counts.entries) {
    if (entry.value > best.value) best = entry;
  }
  return best.key;
}

/// Julukan berbasis aturan sederhana (bukan LLM), dipilih dari kombinasi
/// jumlah tugas, ketepatan waktu, dan sesi workout.
String _persona({
  required int tugasSelesai,
  required int tepatWaktu,
  required int sesiWorkout,
  int hariCatatMakan = 0,
}) {
  if (tugasSelesai == 0 && sesiWorkout == 0) {
    // Mencatat makanan saja sudah lebih dari tidak melakukan apa-apa.
    return hariCatatMakan >= 3 ? 'Pencatat Setia' : 'Baru Mulai';
  }

  final rajinTugas = tugasSelesai >= 5;
  final rajinGym = sesiWorkout >= 5;
  final disiplin = tugasSelesai > 0 && tepatWaktu == tugasSelesai;

  if (rajinTugas && rajinGym) return 'Si Seimbang';
  if (rajinGym) return 'Gym Rat';
  if (disiplin && rajinTugas) return 'Si Konsisten';
  if (rajinTugas) return 'Deadline Fighter';
  return 'Pemula Semangat';
}
