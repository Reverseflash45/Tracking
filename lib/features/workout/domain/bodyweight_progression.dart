/// Tangga progresi untuk latihan tanpa beban.
///
/// Latihan bodyweight tidak bisa dinaikkan dengan menambah kilogram, jadi
/// sumbu progresinya adalah kesulitan gerakan: perbanyak rep dulu sampai batas
/// atas, lalu naik ke variasi yang lebih berat dan rep dimulai lagi dari bawah.
class ProgressionStep {
  const ProgressionStep(this.name, [this.cue]);

  final String name;

  /// Petunjuk singkat cara melakukannya.
  final String? cue;
}

class ProgressionLadder {
  const ProgressionLadder(this.family, this.steps);

  final String family;
  final List<ProgressionStep> steps;

  /// Langkah pada [level], dibatasi supaya tidak keluar dari rentang tangga.
  ProgressionStep stepAt(int level) => steps[level.clamp(0, steps.length - 1)];

  bool isLast(int level) => level >= steps.length - 1;
}

const _pushUp = ProgressionLadder('Push Up', [
  ProgressionStep('Wall Push Up', 'Tangan di tembok, badan lurus'),
  ProgressionStep('Incline Push Up', 'Tangan di meja atau kursi'),
  ProgressionStep('Knee Push Up', 'Lutut menempel lantai'),
  ProgressionStep('Push Up', 'Badan lurus dari kepala sampai tumit'),
  ProgressionStep('Push Up Tempo', 'Turun 3 detik, naik 1 detik'),
  ProgressionStep('Push Up Pause', 'Tahan 2 detik di posisi bawah'),
  ProgressionStep('Diamond Push Up', 'Kedua telapak membentuk segitiga'),
  ProgressionStep('Archer Push Up', 'Berat bertumpu bergantian ke satu sisi'),
  ProgressionStep('One Arm Push Up', 'Kaki dibuka lebar untuk keseimbangan'),
]);

const _pullUp = ProgressionLadder('Pull Up', [
  ProgressionStep('Dead Hang', 'Bergantung, bahu aktif'),
  ProgressionStep('Negative Pull Up', 'Turun perlahan 3-5 detik'),
  ProgressionStep('Band Pull Up', 'Pakai resistance band sebagai bantuan'),
  ProgressionStep('Pull Up', 'Dagu melewati palang'),
  ProgressionStep('Wide Pull Up', 'Pegangan lebih lebar dari bahu'),
  ProgressionStep('Archer Pull Up', 'Satu tangan lurus menyamping'),
  ProgressionStep('One Arm Pull Up Progression', 'Satu tangan memegang pergelangan'),
]);

const _squat = ProgressionLadder('Squat', [
  ProgressionStep('Assisted Squat', 'Berpegangan pada tiang atau kusen'),
  ProgressionStep('Squat', 'Paha sampai sejajar lantai'),
  ProgressionStep('Squat Tempo', 'Turun 3 detik, tahan sebentar'),
  ProgressionStep('Split Squat', 'Kaki depan-belakang, badan tegak'),
  ProgressionStep('Bulgarian Split Squat', 'Kaki belakang diangkat di kursi'),
  ProgressionStep('Shrimp Squat', 'Kaki belakang dipegang tangan'),
  ProgressionStep('Pistol Squat', 'Satu kaki lurus ke depan'),
]);

const _dip = ProgressionLadder('Dip', [
  ProgressionStep('Bench Dip', 'Tangan di kursi, kaki menapak lantai'),
  ProgressionStep('Bench Dip Kaki Lurus', 'Kaki diluruskan ke depan'),
  ProgressionStep('Band Dip', 'Pakai resistance band sebagai bantuan'),
  ProgressionStep('Dip', 'Siku ditekuk sampai 90 derajat'),
  ProgressionStep('Dip Tempo', 'Turun 3 detik, tahan di bawah'),
  ProgressionStep('Weighted Dip', 'Tambah beban di rompi atau dip belt'),
]);

const _row = ProgressionLadder('Row', [
  ProgressionStep('Incline Row', 'Palang setinggi pinggang, badan miring'),
  ProgressionStep('Horizontal Row', 'Badan hampir sejajar lantai'),
  ProgressionStep('Row Kaki Diangkat', 'Kaki ditumpu di kursi'),
  ProgressionStep('Wide Row', 'Pegangan lebih lebar'),
  ProgressionStep('Archer Row', 'Tarik bergantian ke satu sisi'),
  ProgressionStep('One Arm Row', 'Satu tangan penuh'),
]);

const _lunge = ProgressionLadder('Lunge', [
  ProgressionStep('Static Lunge', 'Kaki tidak berpindah, turun naik di tempat'),
  ProgressionStep('Walking Lunge', 'Melangkah maju bergantian'),
  ProgressionStep('Reverse Lunge', 'Melangkah mundur, lutut depan stabil'),
  ProgressionStep('Deficit Lunge', 'Kaki depan di atas step'),
  ProgressionStep('Jumping Lunge', 'Tukar kaki dengan lompatan'),
]);

const _gluteBridge = ProgressionLadder('Glute Bridge', [
  ProgressionStep('Glute Bridge', 'Dorong lewat tumit, remas glutes di atas'),
  ProgressionStep('Glute Bridge Pause', 'Tahan 3 detik di posisi atas'),
  ProgressionStep('Feet Elevated Bridge', 'Kaki ditumpu di kursi'),
  ProgressionStep('Hip Thrust', 'Punggung atas bertumpu di kursi'),
  ProgressionStep('Single Leg Hip Thrust', 'Satu kaki diangkat lurus'),
]);

const _legRaise = ProgressionLadder('Leg Raise', [
  ProgressionStep('Knee Raise Lantai', 'Lutut ditekuk, punggung menempel'),
  ProgressionStep('Leg Raise Lantai', 'Kaki lurus, pinggang tetap menempel'),
  ProgressionStep('Hanging Knee Raise', 'Bergantung, angkat lutut ke dada'),
  ProgressionStep('Hanging Leg Raise', 'Kaki lurus sampai sejajar pinggang'),
  ProgressionStep('Toes to Bar', 'Ujung kaki menyentuh palang'),
]);

const _plank = ProgressionLadder('Plank', [
  ProgressionStep('Knee Plank', 'Lutut menempel lantai'),
  ProgressionStep('Plank', 'Siku di bawah bahu, pinggul sejajar'),
  ProgressionStep('Long Lever Plank', 'Siku digeser lebih maju'),
  ProgressionStep('Single Leg Plank', 'Satu kaki diangkat'),
  ProgressionStep('RKC Plank', 'Kencangkan seluruh badan maksimal'),
]);

const _wallSit = ProgressionLadder('Wall Sit', [
  ProgressionStep('Wall Sit Tinggi', 'Lutut ditekuk sekitar 120 derajat'),
  ProgressionStep('Wall Sit', 'Paha sejajar lantai'),
  ProgressionStep('Single Leg Wall Sit', 'Satu kaki diangkat'),
]);

const _allLadders = [
  _pushUp,
  _pullUp,
  _squat,
  _dip,
  _row,
  _lunge,
  _gluteBridge,
  _legRaise,
  _plank,
  _wallSit,
];

/// Cari tangga yang cocok untuk [exerciseName].
///
/// Pencocokan dilakukan terhadap nama tiap langkah, bukan hanya nama keluarga,
/// supaya "Diamond Push Up" tetap dikenali sebagai keluarga Push Up.
ProgressionLadder? ladderFor(String exerciseName) {
  final name = exerciseName.trim().toLowerCase();
  if (name.isEmpty) return null;

  for (final ladder in _allLadders) {
    for (final step in ladder.steps) {
      if (step.name.toLowerCase() == name) return ladder;
    }
  }

  // Fallback: cocokkan lewat nama keluarga yang terkandung di dalam nama
  // latihan, mis. "Push Up Deficit" -> keluarga Push Up.
  for (final ladder in _allLadders) {
    if (name.contains(ladder.family.toLowerCase())) return ladder;
  }

  return null;
}

/// Posisi [exerciseName] di dalam [ladder], atau `null` kalau tidak persis cocok.
int? levelOf(ProgressionLadder ladder, String exerciseName) {
  final name = exerciseName.trim().toLowerCase();
  for (var i = 0; i < ladder.steps.length; i++) {
    if (ladder.steps[i].name.toLowerCase() == name) return i;
  }
  return null;
}
