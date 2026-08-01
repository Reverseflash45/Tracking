/// Tanya-jawab yang jawabannya dihitung, bukan ditebak model.
///
/// Karena daftar pertanyaannya sudah ditentukan, tiap jawaban bisa dihitung
/// langsung dari data. Hasilnya gratis, seketika, selalu tepat, dan tidak ada
/// data yang meninggalkan HP. Model bahasa hanya diperlukan untuk pertanyaan
/// yang tidak bisa diduga sebelumnya.
library;

import 'package:flutter/material.dart';

import '../../academic/data/models/class_schedule.dart' show weekDayName;
import '../../academic/data/models/task.dart';
import '../../finance/domain/finance_stats.dart';
import '../../finance/domain/transaction.dart';
import '../../nutrition/domain/food_log.dart';
import '../../run/data/run_repository.dart';
import '../../run/domain/run_stats.dart';
import '../../sleep/data/sleep_repository.dart';
import '../../sleep/domain/sleep_stats.dart';
import '../../workout/data/models/workout_session.dart';

/// Rentang yang dipakai pertanyaan bertema "belakangan ini".
const int kPresetDays = 30;

enum AnswerTone {
  /// Sekadar fakta.
  netral,

  /// Kabar baik yang layak ditonjolkan.
  bagus,

  /// Sesuatu yang sebaiknya kamu perhatikan.
  perhatian,
}

class Answer {
  const Answer(this.headline, this.detail, {this.tone = AnswerTone.netral});

  /// Jawaban tanpa data. [detail] menjelaskan apa yang harus diisi dulu.
  const Answer.kosong(this.detail)
      : headline = null,
        tone = AnswerTone.netral;

  /// Angka atau kalimat utamanya. Null berarti datanya belum ada.
  final String? headline;

  /// Kalimat pendukung. Selalu terisi — termasuk saat datanya kosong, supaya
  /// user tahu harus mengisi apa alih-alih menatap layar kosong.
  final String detail;

  final AnswerTone tone;

  bool get kosong => headline == null;
}

/// Semua data yang dibutuhkan katalog pertanyaan.
class QuestionInput {
  const QuestionInput({
    required this.now,
    this.tasks = const [],
    this.sessions = const [],
    this.runs = const [],
    this.foods = const [],
    this.transactions = const [],
    this.sleep = const [],
    this.finance,
  });

  final DateTime now;
  final List<AcademicTask> tasks;
  final List<WorkoutSession> sessions;
  final List<RunLog> runs;
  final List<FoodLog> foods;
  final List<Transaction> transactions;
  final List<SleepLog> sleep;
  final FinanceSummary? finance;

  DateTime get today => DateTime(now.year, now.month, now.day);
  DateTime get sejak => today.subtract(const Duration(days: kPresetDays - 1));

  bool baru(DateTime date) =>
      !DateTime(date.year, date.month, date.day).isBefore(sejak);

  bool bulanIni(DateTime date) => date.year == now.year && date.month == now.month;
}

enum QuestionCategory {
  akademik('Kuliah', Icons.school_outlined),
  latihan('Latihan', Icons.fitness_center),
  lari('Lari', Icons.directions_run),
  makan('Makan', Icons.restaurant_menu),
  tidur('Tidur', Icons.bedtime_outlined),
  keuangan('Keuangan', Icons.savings_outlined),
  lintas('Hubungan Antar Data', Icons.insights);

  const QuestionCategory(this.label, this.icon);

  final String label;
  final IconData icon;
}

class Question {
  const Question({
    required this.id,
    required this.text,
    required this.category,
    required this.answer,
  });

  final String id;
  final String text;
  final QuestionCategory category;
  final Answer Function(QuestionInput) answer;
}

// --- Pembantu ---

/// Hari unik kamu bergerak — sesi latihan maupun lari.
Set<DateTime> _hariOlahraga(QuestionInput input, {bool Function(DateTime)? filter}) {
  bool lolos(DateTime d) => filter == null ? input.baru(d) : filter(d);
  return {
    for (final s in input.sessions)
      if (lolos(s.sessionDate))
        DateTime(s.sessionDate.year, s.sessionDate.month, s.sessionDate.day),
    for (final r in input.runs)
      if (lolos(r.startedAt))
        DateTime(r.startedAt.year, r.startedAt.month, r.startedAt.day),
  };
}

MapEntry<K, int>? _terbanyak<K>(Map<K, int> counts) {
  if (counts.isEmpty) return null;
  var best = counts.entries.first;
  for (final e in counts.entries) {
    if (e.value > best.value) best = e;
  }
  return best;
}

String _angka(double value) {
  final bulat = value.round();
  final digits = bulat.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digits[i]);
  }
  return '${bulat < 0 ? '-' : ''}$buffer';
}

String _km(double meters) => '${(meters / 1000).toStringAsFixed(1)} km';

// --- Katalog ---

/// Daftar pertanyaan. Sengaja bukan `const` — tiap entri membawa closure.
final List<Question> questionCatalog = [
  // ---------- Kuliah ----------
  Question(
    id: 'tugas-mendesak',
    text: 'Tugas apa yang paling mendesak?',
    category: QuestionCategory.akademik,
    answer: (input) {
      // Belum punya tugas sama sekali dan sudah menyelesaikan semuanya itu dua
      // keadaan berbeda. Menyamakannya akan memberi selamat pada orang yang
      // sebenarnya belum mencatat apa pun.
      if (input.tasks.isEmpty) {
        return const Answer.kosong('Belum ada tugas yang kamu catat.');
      }

      final belum = input.tasks.where((t) => !t.isDone).toList()
        ..sort((a, b) => a.deadline.compareTo(b.deadline));
      if (belum.isEmpty) {
        return const Answer(
          'Tidak ada',
          'Semua tugasmu sudah selesai. Nikmati.',
          tone: AnswerTone.bagus,
        );
      }

      final tugas = belum.first;
      final sisa = DateTime(tugas.deadline.year, tugas.deadline.month, tugas.deadline.day)
          .difference(input.today)
          .inDays;

      final (String label, AnswerTone tone) = switch (sisa) {
        < 0 => ('Sudah lewat ${-sisa} hari', AnswerTone.perhatian),
        0 => ('Tenggatnya hari ini', AnswerTone.perhatian),
        1 => ('Tenggatnya besok', AnswerTone.perhatian),
        < 4 => ('$sisa hari lagi', AnswerTone.perhatian),
        _ => ('$sisa hari lagi', AnswerTone.netral),
      };

      final matkul = tugas.courseName?.trim();
      return Answer(
        tugas.title,
        '$label${matkul != null && matkul.isNotEmpty ? ' · $matkul' : ''}'
        '${belum.length > 1 ? '\n${belum.length - 1} tugas lain menyusul.' : ''}',
        tone: tone,
      );
    },
  ),
  Question(
    id: 'tepat-waktu',
    text: 'Berapa persen tugasku selesai tepat waktu?',
    category: QuestionCategory.akademik,
    answer: (input) {
      final selesai = input.tasks.where((t) => t.isDone && t.completedAt != null).toList();
      if (selesai.isEmpty) {
        return const Answer.kosong('Belum ada tugas yang kamu tandai selesai.');
      }

      final tepat = selesai.where((t) => t.isOnTime).length;
      final persen = (tepat / selesai.length * 100).round();

      return Answer(
        '$persen%',
        '$tepat dari ${selesai.length} tugas selesai sebelum tenggat.',
        tone: persen >= 80
            ? AnswerTone.bagus
            : (persen < 50 ? AnswerTone.perhatian : AnswerTone.netral),
      );
    },
  ),
  Question(
    id: 'matkul-tersibuk',
    text: 'Mata kuliah mana yang paling banyak tugasnya?',
    category: QuestionCategory.akademik,
    answer: (input) {
      final perMatkul = <String, int>{};
      for (final task in input.tasks) {
        final nama = task.courseName?.trim();
        if (nama == null || nama.isEmpty) continue;
        perMatkul[nama] = (perMatkul[nama] ?? 0) + 1;
      }

      final top = _terbanyak(perMatkul);
      if (top == null) {
        return const Answer.kosong(
          'Tugasmu belum dikaitkan ke mata kuliah mana pun.',
        );
      }
      return Answer(
        top.key,
        '${top.value} tugas dari total ${input.tasks.length}.',
      );
    },
  ),
  Question(
    id: 'hari-produktif',
    text: 'Hari apa aku paling produktif?',
    category: QuestionCategory.akademik,
    answer: (input) {
      final perHari = <int, int>{};
      for (final task in input.tasks) {
        final selesai = task.completedAt;
        if (selesai == null) continue;
        perHari[selesai.weekday] = (perHari[selesai.weekday] ?? 0) + 1;
      }

      final top = _terbanyak(perHari);
      if (top == null) {
        return const Answer.kosong('Belum ada tugas selesai untuk dibandingkan.');
      }
      return Answer(
        weekDayName(top.key),
        '${top.value} tugas kamu selesaikan di hari itu.',
      );
    },
  ),

  // ---------- Latihan ----------
  Question(
    id: 'latihan-tersering',
    text: 'Latihan apa yang paling sering aku lakukan?',
    category: QuestionCategory.latihan,
    answer: (input) {
      final perNama = <String, int>{};
      for (final session in input.sessions) {
        for (final exercise in session.exercises) {
          final nama = exercise.exerciseName.trim();
          if (nama.isNotEmpty) perNama[nama] = (perNama[nama] ?? 0) + 1;
        }
      }

      final top = _terbanyak(perNama);
      if (top == null) {
        return const Answer.kosong('Belum ada latihan tercatat.');
      }
      return Answer(top.key, 'Tercatat ${top.value} kali.');
    },
  ),
  Question(
    id: 'beban-terberat',
    text: 'Berapa beban terberat yang pernah aku angkat?',
    category: QuestionCategory.latihan,
    answer: (input) {
      String? nama;
      var terberat = 0.0;
      for (final session in input.sessions) {
        for (final exercise in session.exercises) {
          final berat = exercise.weightKg;
          if (berat != null && berat > terberat) {
            terberat = berat;
            nama = exercise.exerciseName.trim();
          }
        }
      }

      if (nama == null || terberat <= 0) {
        return const Answer.kosong('Belum ada latihan dengan beban tercatat.');
      }
      return Answer('${_angka(terberat)} kg', 'Rekormu di $nama.',
          tone: AnswerTone.bagus);
    },
  ),
  Question(
    id: 'olahraga-bulan-ini',
    text: 'Bulan ini aku olahraga berapa hari?',
    category: QuestionCategory.latihan,
    answer: (input) {
      final hari = _hariOlahraga(input, filter: input.bulanIni);
      if (hari.isEmpty) {
        return const Answer.kosong('Belum ada olahraga bulan ini.');
      }
      return Answer(
        '${hari.length} hari',
        'Menghitung sesi latihan dan lari, satu hari dihitung sekali.',
        tone: hari.length >= 12 ? AnswerTone.bagus : AnswerTone.netral,
      );
    },
  ),
  Question(
    id: 'total-volume',
    text: 'Berapa total beban yang aku angkat belakangan ini?',
    category: QuestionCategory.latihan,
    answer: (input) {
      var volume = 0.0;
      for (final session in input.sessions) {
        if (!input.baru(session.sessionDate)) continue;
        for (final exercise in session.exercises) {
          volume += exercise.volume;
        }
      }

      if (volume <= 0) {
        return const Answer.kosong(
          'Belum ada latihan beban dalam $kPresetDays hari terakhir.',
        );
      }
      return Answer(
        '${_angka(volume)} kg',
        'Beban x set x rep, dijumlahkan selama $kPresetDays hari terakhir.',
      );
    },
  ),

  // ---------- Lari ----------
  Question(
    id: 'lari-bulan-ini',
    text: 'Bulan ini aku lari berapa km?',
    category: QuestionCategory.lari,
    answer: (input) {
      final dalam = input.runs.where((r) => input.bulanIni(r.startedAt)).toList();
      if (dalam.isEmpty) {
        return const Answer.kosong('Belum ada lari bulan ini.');
      }
      final jarak = dalam.fold<double>(0, (sum, r) => sum + r.distanceMeters);
      return Answer(_km(jarak), 'Dari ${dalam.length} sesi lari.');
    },
  ),
  Question(
    id: 'lari-terjauh',
    text: 'Lari terjauhku berapa?',
    category: QuestionCategory.lari,
    answer: (input) {
      if (input.runs.isEmpty) {
        return const Answer.kosong('Belum ada lari tercatat.');
      }
      var terjauh = input.runs.first;
      for (final run in input.runs) {
        if (run.distanceMeters > terjauh.distanceMeters) terjauh = run;
      }
      return Answer(
        formatDistance(terjauh.distanceMeters),
        'Dalam ${formatDuration(terjauh.durationSeconds)}, '
        'pada ${terjauh.startedAt.day}/${terjauh.startedAt.month}.',
        tone: AnswerTone.bagus,
      );
    },
  ),
  Question(
    id: 'pace-terbaik',
    text: 'Pace terbaikku berapa?',
    category: QuestionCategory.lari,
    answer: (input) {
      // Lari sangat pendek gampang menghasilkan pace ekstrem yang menyesatkan,
      // jadi hanya lari minimal 1 km yang dianggap.
      RunLog? terbaik;
      double? pace;
      for (final run in input.runs) {
        if (run.distanceMeters < 1000) continue;
        final p = run.pace;
        if (p == null) continue;
        if (pace == null || p < pace) {
          pace = p;
          terbaik = run;
        }
      }

      if (terbaik == null || pace == null) {
        return const Answer.kosong(
          'Belum ada lari sejauh minimal 1 km untuk dibandingkan.',
        );
      }
      return Answer(
        '${formatPace(pace)} /km',
        'Saat lari ${formatDistance(terbaik.distanceMeters)} '
        'pada ${terbaik.startedAt.day}/${terbaik.startedAt.month}.',
        tone: AnswerTone.bagus,
      );
    },
  ),

  // ---------- Makan ----------
  Question(
    id: 'rata-kalori',
    text: 'Rata-rata kalori harianku berapa?',
    category: QuestionCategory.makan,
    answer: (input) {
      final perHari = <DateTime, double>{};
      for (final food in input.foods) {
        if (!input.baru(food.loggedOn)) continue;
        final hari = DateTime(food.loggedOn.year, food.loggedOn.month, food.loggedOn.day);
        perHari[hari] = (perHari[hari] ?? 0) + food.calories;
      }

      if (perHari.isEmpty) {
        return const Answer.kosong(
          'Belum ada catatan makan dalam $kPresetDays hari terakhir.',
        );
      }

      // Dibagi hari yang tercatat, bukan $kPresetDays: hari yang lupa dicatat
      // bukan berarti kamu tidak makan.
      final rata = perHari.values.reduce((a, b) => a + b) / perHari.length;
      return Answer(
        '${_angka(rata)} kkal',
        'Dari ${perHari.length} hari yang kamu catat. Hari yang terlewat tidak '
        'dihitung sebagai nol.',
      );
    },
  ),
  Question(
    id: 'makanan-tersering',
    text: 'Makanan apa yang paling sering aku catat?',
    category: QuestionCategory.makan,
    answer: (input) {
      final perNama = <String, int>{};
      for (final food in input.foods) {
        final nama = food.name.trim();
        if (nama.isNotEmpty) perNama[nama] = (perNama[nama] ?? 0) + 1;
      }

      final top = _terbanyak(perNama);
      if (top == null) {
        return const Answer.kosong('Belum ada catatan makan.');
      }
      return Answer(top.key, 'Tercatat ${top.value} kali.');
    },
  ),
  Question(
    id: 'hari-lupa-catat',
    text: 'Berapa hari aku lupa mencatat makan?',
    category: QuestionCategory.makan,
    answer: (input) {
      final tercatat = <DateTime>{
        for (final food in input.foods)
          if (input.baru(food.loggedOn))
            DateTime(food.loggedOn.year, food.loggedOn.month, food.loggedOn.day),
      };

      if (tercatat.isEmpty) {
        return const Answer.kosong('Belum ada catatan makan sama sekali.');
      }

      final lupa = kPresetDays - tercatat.length;
      return Answer(
        '$lupa hari',
        'Kamu mencatat di ${tercatat.length} dari $kPresetDays hari terakhir.',
        tone: lupa > kPresetDays / 2 ? AnswerTone.perhatian : AnswerTone.netral,
      );
    },
  ),

  // ---------- Keuangan ----------
  Question(
    id: 'kategori-terbesar',
    text: 'Uangku paling banyak habis ke mana?',
    category: QuestionCategory.keuangan,
    answer: (input) {
      final finance = input.finance;
      if (finance == null || finance.perKategori.isEmpty) {
        return const Answer.kosong('Belum ada pengeluaran tercatat periode ini.');
      }

      final top = finance.perKategori.first;
      final persen = finance.pengeluaran <= 0
          ? 0
          : (top.total / finance.pengeluaran * 100).round();

      return Answer(
        top.category.label,
        '${formatRupiah(top.total)} — $persen% dari total pengeluaranmu '
        'periode ini.',
      );
    },
  ),
  Question(
    id: 'rata-pengeluaran',
    text: 'Rata-rata pengeluaran harianku berapa?',
    category: QuestionCategory.keuangan,
    answer: (input) {
      final keluar = input.transactions
          .where((t) => t.kind == TxKind.pengeluaran && input.baru(t.occurredOn))
          .toList();

      if (keluar.isEmpty) {
        return const Answer.kosong(
          'Belum ada pengeluaran dalam $kPresetDays hari terakhir.',
        );
      }

      final total = keluar.fold<double>(0, (sum, t) => sum + t.amount);
      return Answer(
        formatRupiah(total / kPresetDays),
        'Total ${formatRupiah(total)} dibagi $kPresetDays hari.',
      );
    },
  ),
  Question(
    id: 'hari-terboros',
    text: 'Hari apa aku paling boros?',
    category: QuestionCategory.keuangan,
    answer: (input) {
      final perHari = <DateTime, double>{};
      for (final tx in input.transactions) {
        if (tx.kind != TxKind.pengeluaran || !input.baru(tx.occurredOn)) continue;
        final hari = DateTime(tx.occurredOn.year, tx.occurredOn.month, tx.occurredOn.day);
        perHari[hari] = (perHari[hari] ?? 0) + tx.amount;
      }

      if (perHari.isEmpty) {
        return const Answer.kosong(
          'Belum ada pengeluaran dalam $kPresetDays hari terakhir.',
        );
      }

      var puncak = perHari.entries.first;
      for (final e in perHari.entries) {
        if (e.value > puncak.value) puncak = e;
      }

      return Answer(
        formatRupiah(puncak.value),
        '${puncak.key.day}/${puncak.key.month} — hari '
        '${weekDayName(puncak.key.weekday)}.',
      );
    },
  ),

  // ---------- Lintas data ----------
  // Pertanyaan-pertanyaan berikut yang benar-benar tidak bisa dijawab satu
  // halaman mana pun: keduanya menggabungkan dua domain sekaligus.
  Question(
    id: 'olahraga-vs-tugas',
    text: 'Kalau aku rajin olahraga, tugasku lebih cepat selesai?',
    category: QuestionCategory.lintas,
    answer: (input) {
      final hariOlahraga = _hariOlahraga(input);

      var awalSaatOlahraga = 0.0;
      var jumlahOlahraga = 0;
      var awalSaatTidak = 0.0;
      var jumlahTidak = 0;

      for (final task in input.tasks) {
        final selesai = task.completedAt;
        if (selesai == null || !input.baru(selesai)) continue;

        final hari = DateTime(selesai.year, selesai.month, selesai.day);
        // Positif berarti diselesaikan sebelum tenggat.
        final awal = -selesai.difference(task.deadline).inMinutes / (60 * 24);

        if (hariOlahraga.contains(hari)) {
          awalSaatOlahraga += awal;
          jumlahOlahraga++;
        } else {
          awalSaatTidak += awal;
          jumlahTidak++;
        }
      }

      // Tiga di tiap kelompok itu ambang minimum. Di bawah itu, satu tugas
      // yang aneh sudah cukup membalik kesimpulannya.
      if (jumlahOlahraga < 3 || jumlahTidak < 3) {
        return const Answer.kosong(
          'Butuh minimal 3 tugas selesai di hari olahraga dan 3 di hari biasa '
          'sebelum ini bisa dibandingkan.',
        );
      }

      final rataOlahraga = awalSaatOlahraga / jumlahOlahraga;
      final rataTidak = awalSaatTidak / jumlahTidak;
      final selisih = rataOlahraga - rataTidak;

      if (selisih.abs() < 0.5) {
        return Answer(
          'Tidak berbeda',
          'Selisihnya di bawah setengah hari — terlalu kecil untuk berarti. '
          'Dibanding dari $jumlahOlahraga tugas di hari olahraga dan '
          '$jumlahTidak di hari biasa.',
        );
      }

      final lebihAwal = selisih > 0;
      return Answer(
        '${selisih.abs().toStringAsFixed(1).replaceAll('.', ',')} hari '
        '${lebihAwal ? 'lebih awal' : 'lebih mepet'}',
        'Di hari kamu olahraga, tugas selesai rata-rata segitu '
        '${lebihAwal ? 'lebih cepat' : 'lebih lambat'} dibanding hari biasa. '
        'Ini pola, bukan sebab-akibat. Dari $jumlahOlahraga tugas di hari '
        'olahraga dan $jumlahTidak di hari biasa.',
        tone: lebihAwal ? AnswerTone.bagus : AnswerTone.netral,
      );
    },
  ),
  Question(
    id: 'olahraga-vs-makan',
    text: 'Di hari olahraga, aku makan lebih banyak atau lebih sedikit?',
    category: QuestionCategory.lintas,
    answer: (input) {
      final hariOlahraga = _hariOlahraga(input);

      final perHari = <DateTime, double>{};
      for (final food in input.foods) {
        if (!input.baru(food.loggedOn)) continue;
        final hari = DateTime(food.loggedOn.year, food.loggedOn.month, food.loggedOn.day);
        perHari[hari] = (perHari[hari] ?? 0) + food.calories;
      }

      final saatOlahraga = <double>[];
      final saatTidak = <double>[];
      perHari.forEach((hari, kalori) {
        (hariOlahraga.contains(hari) ? saatOlahraga : saatTidak).add(kalori);
      });

      if (saatOlahraga.length < 3 || saatTidak.length < 3) {
        return const Answer.kosong(
          'Butuh minimal 3 hari olahraga dan 3 hari biasa yang catatan makannya '
          'lengkap sebelum ini bisa dibandingkan.',
        );
      }

      final rataOlahraga =
          saatOlahraga.reduce((a, b) => a + b) / saatOlahraga.length;
      final rataTidak = saatTidak.reduce((a, b) => a + b) / saatTidak.length;
      final selisih = rataOlahraga - rataTidak;

      if (selisih.abs() < 100) {
        return Answer(
          'Kurang lebih sama',
          'Selisihnya di bawah 100 kkal — terlalu kecil untuk berarti. '
          'Dari ${saatOlahraga.length} hari olahraga dan ${saatTidak.length} '
          'hari biasa.',
        );
      }

      return Answer(
        '${_angka(selisih.abs())} kkal '
        '${selisih > 0 ? 'lebih banyak' : 'lebih sedikit'}',
        'Rata-rata ${_angka(rataOlahraga)} kkal di hari olahraga, '
        '${_angka(rataTidak)} kkal di hari biasa. Ini pola, bukan sebab-akibat. '
        'Dari ${saatOlahraga.length} hari olahraga dan ${saatTidak.length} '
        'hari biasa.',
      );
    },
  ),

  // ---------- Tidur ----------
  Question(
    id: 'rata-tidur',
    text: 'Rata-rata aku tidur berapa jam?',
    category: QuestionCategory.tidur,
    answer: (input) {
      final ringkasan = summarizeSleep(input.sleep, now: input.now);
      if (ringkasan.kosong) {
        return const Answer.kosong('Belum ada catatan tidur dua minggu terakhir.');
      }

      final cukup = ringkasan.rataJam >= kSleepTargetMin;
      return Answer(
        formatJamTidur(ringkasan.rataJam),
        'Dari ${ringkasan.hariTercatat} hari yang kamu catat. Anjuran umum '
        '${kSleepTargetMin.round()}–${kSleepTargetMax.round()} jam.',
        tone: cukup ? AnswerTone.bagus : AnswerTone.perhatian,
      );
    },
  ),
  Question(
    id: 'malam-kurang-tidur',
    text: 'Berapa malam aku kurang tidur?',
    category: QuestionCategory.tidur,
    answer: (input) {
      final ringkasan = summarizeSleep(input.sleep, now: input.now);
      if (ringkasan.kosong) {
        return const Answer.kosong('Belum ada catatan tidur dua minggu terakhir.');
      }

      return Answer(
        '${ringkasan.hariKurang} dari ${ringkasan.hariTercatat} malam',
        'Kurang berarti di bawah ${kSleepTargetMin.round()} jam. Hari yang '
        'tidak kamu catat tidak ikut dihitung sebagai kurang tidur.',
        tone: ringkasan.hariKurang > ringkasan.hariCukup
            ? AnswerTone.perhatian
            : AnswerTone.netral,
      );
    },
  ),
  Question(
    id: 'tidur-vs-tugas',
    text: 'Setelah tidur cukup, tugasku selesai lebih banyak?',
    category: QuestionCategory.lintas,
    answer: (input) {
      // Tidur dicatat di tanggal bangun, jadi tidur hari X memang menjelaskan
      // produktivitas hari X. Tidak ada penggeseran tanggal di sini.
      final jamPerHari = <DateTime, double>{};
      for (final log in input.sleep) {
        if (!input.baru(log.loggedOn)) continue;
        jamPerHari[DateTime(
          log.loggedOn.year,
          log.loggedOn.month,
          log.loggedOn.day,
        )] = log.hours;
      }

      final selesaiPerHari = <DateTime, int>{};
      for (final task in input.tasks) {
        final done = task.completedAt;
        if (done == null || !input.baru(done)) continue;
        final hari = DateTime(done.year, done.month, done.day);
        selesaiPerHari[hari] = (selesaiPerHari[hari] ?? 0) + 1;
      }

      final saatCukup = <int>[];
      final saatKurang = <int>[];
      jamPerHari.forEach((hari, jam) {
        final selesai = selesaiPerHari[hari] ?? 0;
        (jam >= kSleepTargetMin ? saatCukup : saatKurang).add(selesai);
      });

      if (saatCukup.length < 3 || saatKurang.length < 3) {
        return const Answer.kosong(
          'Butuh minimal 3 hari tidur cukup dan 3 hari kurang tidur yang '
          'tercatat sebelum ini bisa dibandingkan.',
        );
      }

      final rataCukup = saatCukup.reduce((a, b) => a + b) / saatCukup.length;
      final rataKurang = saatKurang.reduce((a, b) => a + b) / saatKurang.length;
      final selisih = rataCukup - rataKurang;

      if (selisih.abs() < 0.5) {
        return Answer(
          'Tidak berbeda',
          'Selisihnya di bawah setengah tugas per hari — terlalu kecil untuk '
          'berarti. Dari ${saatCukup.length} hari cukup dan '
          '${saatKurang.length} hari kurang.',
        );
      }

      return Answer(
        selisih > 0
            ? '${selisih.toStringAsFixed(1)} tugas lebih banyak'
            : '${selisih.abs().toStringAsFixed(1)} tugas lebih sedikit',
        'Rata-rata ${rataCukup.toStringAsFixed(1)} tugas di hari tidur cukup, '
        '${rataKurang.toStringAsFixed(1)} di hari kurang tidur. Ini pola, '
        'bukan sebab-akibat. Dari ${saatCukup.length} hari cukup dan '
        '${saatKurang.length} hari kurang.',
      );
    },
  ),
];

/// Pertanyaan dikelompokkan per kategori, urutan kategori mengikuti enum.
Map<QuestionCategory, List<Question>> get questionsByCategory {
  final grouped = <QuestionCategory, List<Question>>{};
  for (final category in QuestionCategory.values) {
    final items = questionCatalog.where((q) => q.category == category).toList();
    if (items.isNotEmpty) grouped[category] = items;
  }
  return grouped;
}
