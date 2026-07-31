import 'package:flutter/material.dart';

import '../../workout/data/models/exercise_entry.dart';

/// Panduan latihan per kelompok otot.
///
/// Datanya sengaja ditulis sebagai `const` Dart, bukan tabel Supabase: isinya
/// sama untuk semua user, tidak pernah berubah per akun, dan dengan begini
/// halamannya tetap terbuka tanpa internet.
class MuscleExercise {
  const MuscleExercise({
    required this.name,
    required this.type,
    required this.sets,
    required this.reps,
    required this.restSeconds,
    required this.cue,
  });

  final String name;
  final ExerciseType type;
  final int sets;

  /// Rentang rep atau durasi, mis. "8-12" atau "30-60 detik".
  final String reps;

  final int restSeconds;

  /// Satu petunjuk teknik yang paling sering dilanggar pemula.
  final String cue;

  String get restLabel =>
      restSeconds >= 60 ? '${restSeconds ~/ 60} menit' : '$restSeconds detik';

  /// Link pencarian YouTube, bukan URL video tetap, supaya tidak mati kalau
  /// satu video dihapus pemiliknya.
  String get videoSearchUrl =>
      'https://www.youtube.com/results?search_query=${Uri.encodeQueryComponent("cara $name yang benar")}';
}

class MuscleGroup {
  const MuscleGroup({
    required this.slug,
    required this.name,
    required this.icon,
    required this.frequencyPerWeek,
    required this.summary,
    required this.exercises,
    required this.stretching,
    required this.recovery,
  });

  final String slug;
  final String name;
  final IconData icon;
  final int frequencyPerWeek;
  final String summary;
  final List<MuscleExercise> exercises;
  final List<String> stretching;
  final List<String> recovery;
}

/// Nutrisi pendukung pertumbuhan otot.
///
/// Sengaja satu panduan untuk semua kelompok otot: tidak ada makanan yang
/// menargetkan otot tertentu. Yang menentukan otot mana yang tumbuh adalah
/// latihannya, sedangkan makanan menyediakan bahan bakunya untuk seluruh tubuh.
const muscleNutritionGuide = [
  'Protein 1.6-2.2 gram per kg berat badan per hari — ini faktor nutrisi paling menentukan.',
  'Sumber protein terjangkau: telur, dada ayam, ikan kembung, tahu, tempe, susu, ikan lele.',
  'Surplus kalori 10-15% kalau tujuannya menambah massa otot; tanpa surplus, otot sulit tumbuh.',
  'Karbohidrat cukup (nasi, kentang, oat) supaya tenaga latihan terjaga dan protein tidak dibakar jadi energi.',
  'Sebar protein ke 3-4 waktu makan, bukan menumpuk di satu waktu.',
  'Tidur 7-9 jam. Otot tumbuh saat istirahat, bukan saat latihan.',
];

const _dada = MuscleGroup(
  slug: 'dada',
  name: 'Dada',
  icon: Icons.self_improvement,
  frequencyPerWeek: 2,
  summary: 'Otot pektoral. Tumbuh dari gerakan mendorong, baik horizontal maupun miring.',
  exercises: [
    MuscleExercise(
      name: 'Bench Press',
      type: ExerciseType.beban,
      sets: 4,
      reps: '6-10',
      restSeconds: 120,
      cue: 'Tulang belikat ditarik ke belakang dan ditahan menempel bangku.',
    ),
    MuscleExercise(
      name: 'Incline Dumbbell Press',
      type: ExerciseType.beban,
      sets: 3,
      reps: '8-12',
      restSeconds: 90,
      cue: 'Sandaran sekitar 30 derajat; lebih curam justru jadi latihan bahu.',
    ),
    MuscleExercise(
      name: 'Push Up',
      type: ExerciseType.bodyweight,
      sets: 3,
      reps: '8-15',
      restSeconds: 60,
      cue: 'Badan lurus satu garis, siku sekitar 45 derajat dari badan.',
    ),
    MuscleExercise(
      name: 'Dip',
      type: ExerciseType.bodyweight,
      sets: 3,
      reps: '6-12',
      restSeconds: 90,
      cue: 'Badan dicondongkan ke depan supaya beban jatuh ke dada, bukan triceps.',
    ),
  ],
  stretching: [
    'Doorway chest stretch: tangan di kusen pintu, dada dibuka, tahan 30 detik per sisi.',
    'Peregangan dada di lantai dengan tangan terentang, tahan 30 detik.',
  ],
  recovery: [
    'Beri jeda minimal 48 jam sebelum melatih dada lagi.',
    'Nyeri di bahu depan saat bench press biasanya tanda siku terlalu melebar.',
  ],
);

const _bahu = MuscleGroup(
  slug: 'bahu',
  name: 'Bahu',
  icon: Icons.accessibility_new,
  frequencyPerWeek: 2,
  summary: 'Deltoid punya tiga sisi: depan, samping, belakang. Sisi samping dan belakang '
      'paling sering terlewat.',
  exercises: [
    MuscleExercise(
      name: 'Overhead Press',
      type: ExerciseType.beban,
      sets: 4,
      reps: '6-10',
      restSeconds: 120,
      cue: 'Perut dikencangkan supaya punggung bawah tidak melengkung berlebihan.',
    ),
    MuscleExercise(
      name: 'Lateral Raise',
      type: ExerciseType.beban,
      sets: 3,
      reps: '12-15',
      restSeconds: 60,
      cue: 'Beban ringan saja; angkat sampai sejajar bahu, jangan dihentak.',
    ),
    MuscleExercise(
      name: 'Face Pull',
      type: ExerciseType.beban,
      sets: 3,
      reps: '12-15',
      restSeconds: 60,
      cue: 'Tarik ke arah dahi sambil memutar keluar. Penting untuk kesehatan bahu.',
    ),
    MuscleExercise(
      name: 'Pike Push Up',
      type: ExerciseType.bodyweight,
      sets: 3,
      reps: '8-12',
      restSeconds: 75,
      cue: 'Pinggul diangkat tinggi supaya beban pindah ke bahu, bukan dada.',
    ),
  ],
  stretching: [
    'Cross-body shoulder stretch, tahan 30 detik per sisi.',
    'Rotasi bahu tanpa beban 20 putaran sebelum latihan.',
  ],
  recovery: [
    'Bahu punya sendi paling rentan — jangan kejar beban berat dengan teknik buruk.',
    'Kalau ada nyeri menusuk (bukan pegal), hentikan dan periksa tekniknya.',
  ],
);

const _punggung = MuscleGroup(
  slug: 'punggung',
  name: 'Punggung',
  icon: Icons.airline_seat_recline_normal,
  frequencyPerWeek: 2,
  summary: 'Latissimus dorsi, trapezius, dan rhomboid. Lebar dari gerakan menarik ke bawah, '
      'tebal dari gerakan menarik ke belakang.',
  exercises: [
    MuscleExercise(
      name: 'Pull Up',
      type: ExerciseType.bodyweight,
      sets: 4,
      reps: '5-10',
      restSeconds: 120,
      cue: 'Mulai dari bahu aktif (ditarik turun), bukan bergantung pasif.',
    ),
    MuscleExercise(
      name: 'Barbell Row',
      type: ExerciseType.beban,
      sets: 4,
      reps: '8-12',
      restSeconds: 90,
      cue: 'Punggung tetap netral; tarik ke arah pusar, bukan ke dada.',
    ),
    MuscleExercise(
      name: 'Lat Pulldown',
      type: ExerciseType.beban,
      sets: 3,
      reps: '10-12',
      restSeconds: 75,
      cue: 'Dada dibusungkan; jangan mengayun badan ke belakang.',
    ),
    MuscleExercise(
      name: 'Horizontal Row',
      type: ExerciseType.bodyweight,
      sets: 3,
      reps: '8-15',
      restSeconds: 75,
      cue: 'Badan lurus seperti plank, remas tulang belikat di puncak gerakan.',
    ),
  ],
  stretching: [
    'Lat stretch dengan berpegangan pada tiang lalu menjauhkan pinggul, 30 detik per sisi.',
    "Child's pose 45 detik.",
  ],
  recovery: [
    'Punggung otot besar — butuh 48-72 jam pulih setelah sesi berat.',
    'Genggaman biasanya menyerah lebih dulu; pakai strap kalau itu yang membatasi.',
  ],
);

const _biceps = MuscleGroup(
  slug: 'biceps',
  name: 'Biceps',
  icon: Icons.fitness_center,
  frequencyPerWeek: 2,
  summary: 'Otot kecil yang sudah ikut bekerja di semua gerakan menarik. Tidak butuh volume besar.',
  exercises: [
    MuscleExercise(
      name: 'Barbell Curl',
      type: ExerciseType.beban,
      sets: 3,
      reps: '8-12',
      restSeconds: 60,
      cue: 'Siku tetap di sisi badan; jangan pakai ayunan pinggang.',
    ),
    MuscleExercise(
      name: 'Incline Dumbbell Curl',
      type: ExerciseType.beban,
      sets: 3,
      reps: '10-12',
      restSeconds: 60,
      cue: 'Bersandar miring supaya biceps teregang penuh di posisi bawah.',
    ),
    MuscleExercise(
      name: 'Hammer Curl',
      type: ExerciseType.beban,
      sets: 3,
      reps: '10-12',
      restSeconds: 60,
      cue: 'Telapak menghadap ke dalam; ini juga melatih brachialis.',
    ),
    MuscleExercise(
      name: 'Chin Up',
      type: ExerciseType.bodyweight,
      sets: 3,
      reps: '5-10',
      restSeconds: 90,
      cue: 'Telapak menghadap badan — versi pull up yang paling kena biceps.',
    ),
  ],
  stretching: [
    'Rentangkan lengan ke belakang dengan telapak menempel tembok, 30 detik per sisi.',
  ],
  recovery: [
    'Biceps sudah terpakai di hari punggung — hindari melatihnya sehari sebelum atau sesudahnya.',
    'Volume 6-10 set per minggu sudah cukup untuk kebanyakan orang.',
  ],
);

const _triceps = MuscleGroup(
  slug: 'triceps',
  name: 'Triceps',
  icon: Icons.sports_martial_arts,
  frequencyPerWeek: 2,
  summary: 'Menyusun sekitar dua pertiga ukuran lengan atas — lebih menentukan daripada biceps '
      'kalau tujuannya lengan besar.',
  exercises: [
    MuscleExercise(
      name: 'Close Grip Bench Press',
      type: ExerciseType.beban,
      sets: 4,
      reps: '6-10',
      restSeconds: 120,
      cue: 'Pegangan selebar bahu; siku dirapatkan ke badan.',
    ),
    MuscleExercise(
      name: 'Overhead Triceps Extension',
      type: ExerciseType.beban,
      sets: 3,
      reps: '10-12',
      restSeconds: 60,
      cue: 'Posisi di atas kepala meregangkan kepala panjang triceps paling maksimal.',
    ),
    MuscleExercise(
      name: 'Triceps Pushdown',
      type: ExerciseType.beban,
      sets: 3,
      reps: '12-15',
      restSeconds: 60,
      cue: 'Siku dikunci di sisi badan, hanya lengan bawah yang bergerak.',
    ),
    MuscleExercise(
      name: 'Diamond Push Up',
      type: ExerciseType.bodyweight,
      sets: 3,
      reps: '8-12',
      restSeconds: 60,
      cue: 'Kedua telapak membentuk segitiga tepat di bawah dada.',
    ),
  ],
  stretching: [
    'Angkat siku ke atas kepala lalu tekan pelan dengan tangan lain, 30 detik per sisi.',
  ],
  recovery: [
    'Nyeri di siku biasanya karena beban terlalu berat pada gerakan overhead.',
    'Triceps ikut lelah setelah hari dada — jangan dijadwalkan berdekatan.',
  ],
);

const _forearm = MuscleGroup(
  slug: 'forearm',
  name: 'Forearm',
  icon: Icons.back_hand_outlined,
  frequencyPerWeek: 3,
  summary: 'Lengan bawah tahan lelah, jadi boleh dilatih lebih sering dengan rep tinggi.',
  exercises: [
    MuscleExercise(
      name: 'Wrist Curl',
      type: ExerciseType.beban,
      sets: 3,
      reps: '15-20',
      restSeconds: 45,
      cue: 'Lengan bawah ditumpu paha, hanya pergelangan yang bergerak.',
    ),
    MuscleExercise(
      name: 'Reverse Wrist Curl',
      type: ExerciseType.beban,
      sets: 3,
      reps: '15-20',
      restSeconds: 45,
      cue: 'Beban jauh lebih ringan daripada wrist curl biasa.',
    ),
    MuscleExercise(
      name: 'Farmer Walk',
      type: ExerciseType.beban,
      sets: 3,
      reps: '30-45 detik',
      restSeconds: 60,
      cue: 'Bahu ditarik ke belakang, jalan tegak sambil menjinjing beban berat.',
    ),
    MuscleExercise(
      name: 'Dead Hang',
      type: ExerciseType.isometrik,
      sets: 3,
      reps: '30-60 detik',
      restSeconds: 60,
      cue: 'Bergantung di palang selama mungkin; melatih genggaman sekaligus bahu.',
    ),
  ],
  stretching: [
    'Tekuk pergelangan ke bawah lalu ke atas dengan bantuan tangan lain, 20 detik tiap arah.',
  ],
  recovery: [
    'Lengan bawah pulih cepat, tapi genggaman yang lelah mengganggu latihan punggung.',
    'Latih di akhir sesi, jangan di awal.',
  ],
);

const _perut = MuscleGroup(
  slug: 'perut',
  name: 'Perut',
  icon: Icons.rectangle_outlined,
  frequencyPerWeek: 3,
  summary: 'Otot perut terlihat kalau persentase lemak rendah. Latihan membentuk, tapi '
      'yang memunculkan garisnya adalah defisit kalori.',
  exercises: [
    MuscleExercise(
      name: 'Plank',
      type: ExerciseType.isometrik,
      sets: 3,
      reps: '30-60 detik',
      restSeconds: 45,
      cue: 'Pinggul sejajar badan — jangan naik ke atas atau melorot ke bawah.',
    ),
    MuscleExercise(
      name: 'Hanging Leg Raise',
      type: ExerciseType.bodyweight,
      sets: 3,
      reps: '8-15',
      restSeconds: 60,
      cue: 'Angkat dengan perut, bukan ayunan. Panggul digulung ke atas.',
    ),
    MuscleExercise(
      name: 'Dead Bug',
      type: ExerciseType.bodyweight,
      sets: 3,
      reps: '10-12',
      restSeconds: 45,
      cue: 'Punggung bawah tetap menempel lantai sepanjang gerakan.',
    ),
    MuscleExercise(
      name: 'Cable Crunch',
      type: ExerciseType.beban,
      sets: 3,
      reps: '12-15',
      restSeconds: 60,
      cue: 'Gulung tulang belakang ke bawah; pinggul tidak ikut bergerak.',
    ),
  ],
  stretching: [
    'Cobra stretch: telungkup lalu dorong dada ke atas, tahan 30 detik.',
  ],
  recovery: [
    'Perut boleh dilatih 3x seminggu karena bebannya relatif ringan.',
    'Sit up tanpa henti tidak menghilangkan lemak perut — itu urusan defisit kalori.',
  ],
);

const _glutes = MuscleGroup(
  slug: 'glutes',
  name: 'Glutes',
  icon: Icons.airline_seat_legroom_extra,
  frequencyPerWeek: 2,
  summary: 'Otot terkuat di tubuh. Merespons paling baik pada gerakan dorong pinggul dan '
      'squat dalam.',
  exercises: [
    MuscleExercise(
      name: 'Hip Thrust',
      type: ExerciseType.beban,
      sets: 4,
      reps: '8-12',
      restSeconds: 120,
      cue: 'Dagu ditarik ke dada; remas glutes 1 detik di posisi atas.',
    ),
    MuscleExercise(
      name: 'Romanian Deadlift',
      type: ExerciseType.beban,
      sets: 3,
      reps: '8-12',
      restSeconds: 120,
      cue: 'Pinggul didorong ke belakang, lutut hampir lurus, punggung netral.',
    ),
    MuscleExercise(
      name: 'Bulgarian Split Squat',
      type: ExerciseType.bodyweight,
      sets: 3,
      reps: '8-12',
      restSeconds: 90,
      cue: 'Badan sedikit condong ke depan supaya glutes lebih terlibat.',
    ),
    MuscleExercise(
      name: 'Glute Bridge',
      type: ExerciseType.bodyweight,
      sets: 3,
      reps: '12-20',
      restSeconds: 60,
      cue: 'Dorong lewat tumit, bukan ujung kaki.',
    ),
  ],
  stretching: [
    'Pigeon pose 45 detik per sisi.',
    'Figure-4 stretch sambil telentang, 30 detik per sisi.',
  ],
  recovery: [
    'Glutes pulih relatif cepat dan tahan volume tinggi.',
    'Kalau paha belakang yang lebih terasa daripada glutes, kurangi rentang gerak di hip thrust.',
  ],
);

const _quadriceps = MuscleGroup(
  slug: 'quadriceps',
  name: 'Quadriceps',
  icon: Icons.directions_run,
  frequencyPerWeek: 2,
  summary: 'Otot paha depan. Tumbuh dari squat dalam dan gerakan dominan lutut.',
  exercises: [
    MuscleExercise(
      name: 'Back Squat',
      type: ExerciseType.beban,
      sets: 4,
      reps: '6-10',
      restSeconds: 180,
      cue: 'Turun sampai paha minimal sejajar lantai; lutut mengikuti arah ujung kaki.',
    ),
    MuscleExercise(
      name: 'Front Squat',
      type: ExerciseType.beban,
      sets: 3,
      reps: '8-10',
      restSeconds: 120,
      cue: 'Siku diangkat tinggi supaya badan tetap tegak.',
    ),
    MuscleExercise(
      name: 'Leg Press',
      type: ExerciseType.beban,
      sets: 3,
      reps: '10-15',
      restSeconds: 90,
      cue: 'Punggung bawah jangan sampai terangkat dari sandaran.',
    ),
    MuscleExercise(
      name: 'Walking Lunge',
      type: ExerciseType.bodyweight,
      sets: 3,
      reps: '10-12 per kaki',
      restSeconds: 75,
      cue: 'Langkah cukup panjang; lutut belakang turun mendekati lantai.',
    ),
  ],
  stretching: [
    'Quad stretch berdiri sambil menarik pergelangan kaki, 30 detik per sisi.',
    'Couch stretch 45 detik per sisi.',
  ],
  recovery: [
    'Squat berat butuh 72 jam pemulihan penuh.',
    'Lutut masuk ke dalam saat naik biasanya tanda glutes lemah, bukan lutut bermasalah.',
  ],
);

const _hamstring = MuscleGroup(
  slug: 'hamstring',
  name: 'Hamstring',
  icon: Icons.trending_down,
  frequencyPerWeek: 2,
  summary: 'Paha belakang. Sering tertinggal karena kalah perhatian dari paha depan.',
  exercises: [
    MuscleExercise(
      name: 'Romanian Deadlift',
      type: ExerciseType.beban,
      sets: 4,
      reps: '8-12',
      restSeconds: 120,
      cue: 'Rasakan tarikan di paha belakang; berhenti sebelum punggung membulat.',
    ),
    MuscleExercise(
      name: 'Leg Curl',
      type: ExerciseType.beban,
      sets: 3,
      reps: '10-15',
      restSeconds: 75,
      cue: 'Tahan 1 detik di puncak, turunkan perlahan.',
    ),
    MuscleExercise(
      name: 'Nordic Curl',
      type: ExerciseType.bodyweight,
      sets: 3,
      reps: '5-8',
      restSeconds: 120,
      cue: 'Turun sepelan mungkin. Gerakan sangat berat, mulai dengan bantuan.',
    ),
    MuscleExercise(
      name: 'Good Morning',
      type: ExerciseType.beban,
      sets: 3,
      reps: '10-12',
      restSeconds: 90,
      cue: 'Beban ringan; ini gerakan engsel pinggul, bukan squat.',
    ),
  ],
  stretching: [
    'Standing hamstring stretch, 30 detik per sisi.',
    'Seated forward fold 45 detik.',
  ],
  recovery: [
    'Hamstring rawan cedera kalau langsung diberi beban berat tanpa pemanasan.',
    'Nordic curl menimbulkan nyeri otot berat — cukup sekali seminggu di awal.',
  ],
);

const _betis = MuscleGroup(
  slug: 'betis',
  name: 'Betis',
  icon: Icons.directions_walk,
  frequencyPerWeek: 3,
  summary: 'Betis terbiasa menopang berat badan sepanjang hari, jadi butuh rep tinggi dan '
      'frekuensi lebih sering.',
  exercises: [
    MuscleExercise(
      name: 'Standing Calf Raise',
      type: ExerciseType.beban,
      sets: 4,
      reps: '12-20',
      restSeconds: 60,
      cue: 'Rentang gerak penuh: turun sampai tumit di bawah pijakan, naik sampai jinjit penuh.',
    ),
    MuscleExercise(
      name: 'Seated Calf Raise',
      type: ExerciseType.beban,
      sets: 3,
      reps: '15-20',
      restSeconds: 60,
      cue: 'Lutut ditekuk supaya otot soleus yang lebih terlatih.',
    ),
    MuscleExercise(
      name: 'Single Leg Calf Raise',
      type: ExerciseType.bodyweight,
      sets: 3,
      reps: '15-25',
      restSeconds: 45,
      cue: 'Tahan 1 detik di posisi jinjit tertinggi.',
    ),
    MuscleExercise(
      name: 'Jump Rope',
      type: ExerciseType.cardio,
      sets: 3,
      reps: '2-3 menit',
      restSeconds: 60,
      cue: 'Mendarat dengan telapak depan, lutut sedikit ditekuk.',
    ),
  ],
  stretching: [
    'Calf stretch menghadap tembok dengan kaki belakang lurus, 30 detik per sisi.',
    'Ulangi dengan lutut belakang ditekuk untuk menjangkau soleus.',
  ],
  recovery: [
    'Betis pulih cepat dan boleh dilatih 3x seminggu.',
    'Pertumbuhan betis sangat dipengaruhi genetik — konsistensi lebih menentukan daripada program.',
  ],
);

const muscleGroups = <MuscleGroup>[
  _dada,
  _bahu,
  _punggung,
  _biceps,
  _triceps,
  _forearm,
  _perut,
  _glutes,
  _quadriceps,
  _hamstring,
  _betis,
];

MuscleGroup? muscleGroupBySlug(String slug) {
  for (final group in muscleGroups) {
    if (group.slug == slug) return group;
  }
  return null;
}
