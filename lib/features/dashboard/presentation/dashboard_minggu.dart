// Kartu minggu ini: latihan per hari terhadap target mingguan.
part of 'dashboard_page.dart';

/// Tujuh hari dalam satu baris: hari ini ditandai, titik ungu untuk hari
/// yang ada kuliah, titik teal untuk hari yang sudah ada latihan.
class _KartuMingguIni extends ConsumerWidget {
  const _KartuMingguIni();

  static const _singkat = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final sekarang = DateTime.now();
    final awal = _awalMinggu(sekarang);
    final jadwal = ref.watch(classSchedulesProvider).value ?? const [];
    final aktif = ref.watch(activeDatesProvider);
    final tugas = ref.watch(tasksProvider).value ?? const <AcademicTask>[];

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Row(
          children: [
            for (var i = 0; i < 7; i++)
              Expanded(
                child: Builder(
                  builder: (context) {
                    final hari = awal.add(Duration(days: i));
                    final iniHari = _hariSama(hari, sekarang);
                    final lalu = hari.isBefore(
                      DateTime(sekarang.year, sekarang.month, sekarang.day),
                    );
                    final adaKuliah = jadwal.any(
                      (s) => s.isPhl
                          ? (s.specificDate != null &&
                                _hariSama(s.specificDate!, hari))
                          : s.dayOfWeek == hari.weekday,
                    );
                    final adaLatihan = aktif.any((d) => _hariSama(d, hari));
                    final adaTenggat = tugas.any(
                      (t) => !t.isDone && _hariSama(t.deadline, hari),
                    );

                    return InkWell(
                      borderRadius: BorderRadius.circular(14),
                      // Buka Jadwal tepat di hari yang diketuk.
                      onTap: () {
                        ref
                            .read(hariJadwalProvider.notifier)
                            .pilih(hari.weekday);
                        _keTab(context, kTabJadwal);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Column(
                          children: [
                            Text(
                              _singkat[i],
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: iniHari
                                    ? AppColors.dashboard
                                    : colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              width: 34,
                              height: 34,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: iniHari
                                    ? AppColors.dashboard
                                    : Colors.transparent,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${hari.day}',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: iniHari
                                      ? Colors.white
                                      : lalu
                                      ? colorScheme.onSurfaceVariant
                                      : colorScheme.onSurface,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            SizedBox(
                              height: 6,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (adaKuliah)
                                    const _Titik(AppColors.academic),
                                  if (adaTenggat)
                                    const _Titik(AppColors.deadline),
                                  if (adaLatihan)
                                    const _Titik(AppColors.workout),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Titik extends StatelessWidget {
  const _Titik(this.warna);

  final Color warna;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 5,
      height: 5,
      margin: const EdgeInsets.symmetric(horizontal: 1.5),
      decoration: BoxDecoration(color: warna, shape: BoxShape.circle),
    );
  }
}

// ---------------------------------------------------------------------------
// Judul bagian
// ---------------------------------------------------------------------------
