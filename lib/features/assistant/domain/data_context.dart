import '../../academic/data/models/task.dart';
import '../../finance/domain/finance_stats.dart';
import '../../finance/domain/transaction.dart';
import '../../nutrition/domain/food_log.dart';
import '../../run/data/run_repository.dart';
import '../../workout/data/models/workout_session.dart';

/// Berapa hari ke belakang yang dirangkum untuk asisten.
const int kContextDays = 30;

/// Susun ringkasan data untuk dikirim ke asisten.
///
/// Yang dikirim RINGKASAN, bukan data mentah. Tiga alasan: biayanya dihitung
/// per token jadi data mentah berbulan-bulan itu mahal; makin panjang konteks
/// makin gampang model salah baca; dan makin sedikit yang meninggalkan HP-mu,
/// makin baik.
///
/// Fungsi ini murni — tidak menyentuh jaringan maupun jam sistem kecuali lewat
/// [now], supaya hasilnya bisa diuji.
String buildDataContext({
  required DateTime now,
  List<AcademicTask> tasks = const [],
  List<WorkoutSession> sessions = const [],
  List<RunLog> runs = const [],
  List<FoodLog> foods = const [],
  List<Transaction> transactions = const [],
  FinanceSummary? finance,
}) {
  final sejak = DateTime(now.year, now.month, now.day)
      .subtract(const Duration(days: kContextDays - 1));
  bool dalamRentang(DateTime date) =>
      !DateTime(date.year, date.month, date.day).isBefore(sejak);

  final buffer = StringBuffer()
    ..writeln('Hari ini: ${_tanggal(now)}')
    ..writeln('Ringkasan $kContextDays hari terakhir.')
    ..writeln();

  _tulisTugas(buffer, tasks, now, dalamRentang);
  _tulisLatihan(buffer, sessions, dalamRentang);
  _tulisLari(buffer, runs, dalamRentang);
  _tulisNutrisi(buffer, foods, dalamRentang);
  _tulisKeuangan(buffer, transactions, finance, dalamRentang);

  return buffer.toString().trim();
}

void _tulisTugas(
  StringBuffer buffer,
  List<AcademicTask> tasks,
  DateTime now,
  bool Function(DateTime) dalamRentang,
) {
  buffer.writeln('== TUGAS ==');
  if (tasks.isEmpty) {
    buffer
      ..writeln('Belum ada tugas tercatat.')
      ..writeln();
    return;
  }

  final selesai = tasks
      .where((t) => t.completedAt != null && dalamRentang(t.completedAt!))
      .toList();
  final tepat = selesai.where((t) => t.isOnTime).length;

  final belum = tasks.where((t) => !t.isDone).toList()
    ..sort((a, b) => a.deadline.compareTo(b.deadline));

  buffer.writeln('Selesai: ${selesai.length}, tepat waktu: $tepat');
  buffer.writeln('Belum selesai: ${belum.length}');

  // Hanya lima terdekat. Menyertakan semuanya bisa jadi ratusan baris dan
  // menenggelamkan bagian lain dari ringkasan.
  for (final task in belum.take(5)) {
    final sisa = DateTime(task.deadline.year, task.deadline.month, task.deadline.day)
        .difference(DateTime(now.year, now.month, now.day))
        .inDays;
    final label = sisa < 0
        ? 'TELAT ${-sisa} hari'
        : (sisa == 0 ? 'hari ini' : '$sisa hari lagi');
    final matkul = task.courseName?.trim();
    buffer.writeln(
      '- ${task.title}'
      '${matkul != null && matkul.isNotEmpty ? ' ($matkul)' : ''}'
      ' — $label',
    );
  }
  buffer.writeln();
}

void _tulisLatihan(
  StringBuffer buffer,
  List<WorkoutSession> sessions,
  bool Function(DateTime) dalamRentang,
) {
  buffer.writeln('== LATIHAN ==');
  final dalam = sessions.where((s) => dalamRentang(s.sessionDate)).toList();

  if (dalam.isEmpty) {
    buffer
      ..writeln('Tidak ada sesi latihan tercatat.')
      ..writeln();
    return;
  }

  var volume = 0.0;
  final perLatihan = <String, int>{};
  for (final session in dalam) {
    for (final exercise in session.exercises) {
      if (exercise.type.pakaiVolume) volume += exercise.volume;
      final nama = exercise.exerciseName.trim();
      if (nama.isNotEmpty) perLatihan[nama] = (perLatihan[nama] ?? 0) + 1;
    }
  }

  buffer.writeln('Sesi: ${dalam.length}');
  if (volume > 0) buffer.writeln('Total volume angkat: ${volume.round()} kg');

  final urut = perLatihan.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  if (urut.isNotEmpty) {
    final teks = urut.take(5).map((e) => '${e.key} ${e.value}x').join(', ');
    buffer.writeln('Latihan tersering: $teks');
  }
  buffer.writeln();
}

void _tulisLari(
  StringBuffer buffer,
  List<RunLog> runs,
  bool Function(DateTime) dalamRentang,
) {
  buffer.writeln('== LARI ==');
  final dalam = runs.where((r) => dalamRentang(r.startedAt)).toList();

  if (dalam.isEmpty) {
    buffer
      ..writeln('Tidak ada lari tercatat.')
      ..writeln();
    return;
  }

  var jarak = 0.0;
  var terjauh = 0.0;
  for (final run in dalam) {
    jarak += run.distanceMeters;
    if (run.distanceMeters > terjauh) terjauh = run.distanceMeters;
  }

  buffer.writeln('Sesi lari: ${dalam.length}');
  buffer.writeln('Total jarak: ${(jarak / 1000).toStringAsFixed(1)} km');
  buffer.writeln('Terjauh sekali lari: ${(terjauh / 1000).toStringAsFixed(2)} km');
  buffer.writeln();
}

void _tulisNutrisi(
  StringBuffer buffer,
  List<FoodLog> foods,
  bool Function(DateTime) dalamRentang,
) {
  buffer.writeln('== MAKAN ==');
  final dalam = foods.where((f) => dalamRentang(f.loggedOn)).toList();

  if (dalam.isEmpty) {
    buffer
      ..writeln('Tidak ada catatan makan.')
      ..writeln();
    return;
  }

  final perHari = <DateTime, double>{};
  final perNama = <String, int>{};
  for (final food in dalam) {
    final hari = DateTime(food.loggedOn.year, food.loggedOn.month, food.loggedOn.day);
    perHari[hari] = (perHari[hari] ?? 0) + food.calories;
    final nama = food.name.trim();
    if (nama.isNotEmpty) perNama[nama] = (perNama[nama] ?? 0) + 1;
  }

  // Dibagi jumlah hari yang tercatat, bukan panjang periode — hari yang lupa
  // dicatat bukan berarti nol asupan.
  final rata = perHari.values.reduce((a, b) => a + b) / perHari.length;

  buffer.writeln('Hari tercatat: ${perHari.length} dari $kContextDays');
  buffer.writeln('Rata-rata kalori per hari tercatat: ${rata.round()} kkal');

  final urut = perNama.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  if (urut.isNotEmpty) {
    buffer.writeln(
      'Sering dimakan: ${urut.take(5).map((e) => '${e.key} ${e.value}x').join(', ')}',
    );
  }
  buffer.writeln();
}

void _tulisKeuangan(
  StringBuffer buffer,
  List<Transaction> transactions,
  FinanceSummary? finance,
  bool Function(DateTime) dalamRentang,
) {
  buffer.writeln('== KEUANGAN ==');
  final dalam = transactions.where((t) => dalamRentang(t.occurredOn)).toList();

  if (dalam.isEmpty && finance == null) {
    buffer
      ..writeln('Tidak ada catatan keuangan.')
      ..writeln();
    return;
  }

  if (finance != null) {
    buffer.writeln('Periode anggaran berjalan:');
    buffer.writeln('  Masuk: ${formatRupiah(finance.pemasukan)}');
    buffer.writeln('  Keluar: ${formatRupiah(finance.pengeluaran)}');
    if (finance.budget != null) {
      buffer.writeln('  Anggaran: ${formatRupiah(finance.budget!)}');
      buffer.writeln('  Sisa: ${formatRupiah(finance.sisaBudget ?? 0)}');
      buffer.writeln('  Sisa hari: ${finance.sisaHari}');
      final jatah = finance.jatahHarian;
      if (jatah != null) {
        buffer.writeln('  Jatah per hari: ${formatRupiah(jatah)}');
      }
    } else {
      buffer.writeln('  Anggaran bulanan belum diatur.');
    }

    for (final item in finance.perKategori.take(5)) {
      buffer.writeln('  ${item.category.label}: ${formatRupiah(item.total)}');
    }
  }

  buffer.writeln('Transaksi $kContextDays hari terakhir: ${dalam.length}');
  buffer.writeln();
}

String _tanggal(DateTime date) =>
    '${date.year}-${_dua(date.month)}-${_dua(date.day)}';

String _dua(int value) => value.toString().padLeft(2, '0');
