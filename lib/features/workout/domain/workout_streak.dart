import '../data/models/workout_session.dart';

/// Berapa hari istirahat berturut-turut yang masih menyambung streak.
///
/// Dua dipilih karena itu batas pemulihan yang wajar — otot butuh 24–48 jam
/// setelah latihan berat. Hari ketiga tanpa bergerak bukan pemulihan lagi, itu
/// berhenti. Kalau apinya tetap menyala di situ, angkanya berhenti berarti apa
/// pun, dan streak yang tidak berarti tidak menahan siapa-siapa.
const int kMaxConsecutiveRestDays = 2;

class WorkoutStreak {
  const WorkoutStreak({
    required this.current,
    required this.best,
    this.restInCurrent = 0,
  });

  /// Panjang rantai hari berturut-turut yang masih berjalan.
  final int current;

  final int best;

  /// Berapa dari [current] yang berupa hari istirahat, bukan hari latihan.
  ///
  /// Ditampilkan apa adanya supaya angka streak tidak terbaca sebagai jumlah
  /// hari kamu berlatih — karena bukan itu.
  final int restInCurrent;

  /// Hari yang benar-benar ada gerakannya.
  int get activeInCurrent => current - restInCurrent;
}

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

/// Streak workout dihitung dari tanggal sesi unik. Streak "aktif" boleh punya
/// grace 1 hari (kalau belum sempat workout hari ini tapi kemarin masih jalan).
WorkoutStreak calculateWorkoutStreak(List<WorkoutSession> sessions) =>
    calculateStreakFromDates(sessions.map((s) => s.sessionDate));

/// Streak dari kumpulan tanggal aktif apa pun.
///
/// Dipisah dari [calculateWorkoutStreak] supaya hari lari bisa ikut dihitung.
/// Lari 10 km lalu streak-nya putus karena tidak mencatat sesi angkat beban itu
/// jelas salah — yang dihitung "hari kamu bergerak", bukan "hari kamu ke gym".
///
/// [restDates] adalah hari yang kamu tandai sendiri sebagai hari istirahat.
/// Hari itu menyambung rantai, tapi tidak pernah dianggap hari latihan:
/// rantai yang isinya hanya istirahat tetap bernilai nol, dan istirahat yang
/// menggantung di pangkal rantai (belum ada latihan sebelumnya) tidak dihitung.
WorkoutStreak calculateStreakFromDates(
  Iterable<DateTime> dates, {
  Iterable<DateTime> restDates = const [],
  DateTime? now,
}) {
  final active = dates.map(_dateOnly).toSet();
  // Hari yang ternyata ada latihannya bukan hari istirahat, meski terlanjur
  // ditandai. Yang benar-benar terjadi menang atas yang direncanakan.
  final rest = restDates.map(_dateOnly).toSet().difference(active);

  if (active.isEmpty) return const WorkoutStreak(current: 0, best: 0);

  final chain = _current(active, rest, _dateOnly(now ?? DateTime.now()));
  return WorkoutStreak(
    current: chain.length,
    best: _best(active, rest),
    restInCurrent: chain.rest,
  );
}

/// Berapa hari istirahat berturut-turut yang sudah kamu pakai sampai hari ini.
///
/// Dipakai untuk memberi tahu sebelum apinya padam, bukan sesudah.
int consecutiveRestDays({
  required Iterable<DateTime> restDates,
  required Iterable<DateTime> activeDates,
  DateTime? now,
}) {
  final active = activeDates.map(_dateOnly).toSet();
  final rest = restDates.map(_dateOnly).toSet().difference(active);

  var cursor = _dateOnly(now ?? DateTime.now());
  var count = 0;
  while (rest.contains(cursor)) {
    count++;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return count;
}

typedef _Chain = ({int length, int rest});

/// Telusuri mundur dari hari ini (atau kemarin, sebagai grace satu hari).
_Chain _current(Set<DateTime> active, Set<DateTime> rest, DateTime today) {
  final yesterday = today.subtract(const Duration(days: 1));

  DateTime? cursor;
  if (active.contains(today) || rest.contains(today)) {
    cursor = today;
  } else if (active.contains(yesterday) || rest.contains(yesterday)) {
    cursor = yesterday;
  }
  if (cursor == null) return (length: 0, rest: 0);

  var length = 0;
  var restCount = 0;
  var activeCount = 0;
  var consecutiveRest = 0;

  while (true) {
    if (active.contains(cursor!)) {
      consecutiveRest = 0;
      activeCount++;
      length++;
    } else if (rest.contains(cursor)) {
      consecutiveRest++;
      if (consecutiveRest > kMaxConsecutiveRestDays) {
        // Hari ini tidak ikut terhitung, dan jatah istirahat sudah lewat.
        consecutiveRest--;
        break;
      }
      restCount++;
      length++;
    } else {
      break;
    }
    cursor = cursor.subtract(const Duration(days: 1));
  }

  // Streak dimulai dari hari latihan. Hari istirahat yang tersisa di ujung
  // belakang tidak menyambung ke apa pun, jadi tidak ikut dihitung.
  length -= consecutiveRest;
  restCount -= consecutiveRest;

  if (activeCount == 0) return (length: 0, rest: 0);
  return (length: length, rest: restCount);
}

/// Rantai terpanjang sepanjang riwayat, dengan aturan yang sama.
int _best(Set<DateTime> active, Set<DateTime> rest) {
  final all = {...active, ...rest}.toList()..sort();

  var best = 0;
  var run = 0;
  var runActive = 0;
  var consecutiveRest = 0;
  DateTime? prev;

  for (final day in all) {
    if (prev != null && day.difference(prev).inDays != 1) {
      run = 0;
      runActive = 0;
      consecutiveRest = 0;
    }

    if (active.contains(day)) {
      consecutiveRest = 0;
      run++;
      runActive++;
    } else {
      consecutiveRest++;
      if (consecutiveRest > kMaxConsecutiveRestDays) {
        run = 0;
        runActive = 0;
      } else {
        run++;
      }
    }

    // Rantai yang belum berisi satu pun hari latihan belum jadi streak.
    if (runActive > 0 && run > best) best = run;
    prev = day;
  }

  return best;
}
