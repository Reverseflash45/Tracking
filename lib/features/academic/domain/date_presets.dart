/// Deadline default jatuh di akhir hari, bukan jam saat tombol ditekan, supaya
/// tugas tidak langsung dianggap telat beberapa jam setelah dibuat.
DateTime endOfDay(DateTime date) => DateTime(date.year, date.month, date.day, 23, 59);

/// Pilihan deadline cepat yang dipakai bersama oleh form tugas dan Quick Capture.
enum DeadlinePreset {
  hariIni('Hari ini', 0),
  besok('Besok', 1),
  satuMinggu('1 minggu', 7);

  const DeadlinePreset(this.label, this.daysFromNow);

  final String label;
  final int daysFromNow;

  DateTime resolve([DateTime? now]) =>
      endOfDay((now ?? DateTime.now()).add(Duration(days: daysFromNow)));
}
