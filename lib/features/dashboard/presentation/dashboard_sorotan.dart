// Kartu sorotan: kelas atau tenggat terdekat, dengan hitung mundur.
part of 'dashboard_page.dart';

/// Satu kartu besar berisi hal yang paling perlu kamu tahu *sekarang*:
/// kelas yang sedang jalan, kelas berikutnya, tenggat yang mepet, atau
/// kabar bahwa hari ini kosong. Warnanya ikut artinya — ungu untuk kuliah,
/// koral untuk tenggat — jadi dari jauh pun kelihatan jenisnya.
///
/// Diperbarui tiap 30 detik supaya hitung mundurnya tidak basi.
class _KartuSorotan extends ConsumerStatefulWidget {
  const _KartuSorotan();

  @override
  ConsumerState<_KartuSorotan> createState() => _KartuSorotanState();
}

class _KartuSorotanState extends ConsumerState<_KartuSorotan> {
  Timer? _detak;

  @override
  void initState() {
    super.initState();
    _detak = Timer.periodic(
      const Duration(seconds: 30),
      (_) => mounted ? setState(() {}) : null,
    );
  }

  @override
  void dispose() {
    _detak?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sekarang = DateTime.now();
    final hariIni = ref.watch(todaySchedulesProvider).value ?? const [];
    final semua = ref.watch(classSchedulesProvider).value ?? const [];
    final tugas = ref.watch(tasksProvider).value ?? const <AcademicTask>[];

    DateTime pada(String jam) {
      final m = menitDariJam(jam) ?? 0;
      return DateTime(
        sekarang.year,
        sekarang.month,
        sekarang.day,
        m ~/ 60,
        m % 60,
      );
    }

    // 1. Kelas yang sedang berlangsung, lalu kelas berikutnya hari ini.
    for (final s in hariIni) {
      final mulai = pada(s.startTime);
      final selesai = pada(s.endTime);
      if (!sekarang.isBefore(mulai) && sekarang.isBefore(selesai)) {
        final total = selesai.difference(mulai).inMinutes;
        final lewat = sekarang.difference(mulai).inMinutes;
        return _TampilanSorotan(
          jenis: _JenisSorotan.berlangsung,
          label: 'Sedang berlangsung',
          judul: s.courseName,
          rincian: _rincianKelas(s),
          sudut: 'Selesai ${s.endTime.substring(0, 5)}',
          progres: total <= 0 ? null : lewat / total,
          aksi: (
            'Catat hadir',
            Icons.how_to_reg_rounded,
            () => context.push('/academic/schedule/attendance'),
          ),
          onTap: () {
            ref.read(hariJadwalProvider.notifier).pilih(DateTime.now().weekday);
            _keTab(context, kTabJadwal);
          },
        );
      }
    }
    for (final s in hariIni) {
      final mulai = pada(s.startTime);
      if (sekarang.isBefore(mulai)) {
        return _TampilanSorotan(
          jenis: _JenisSorotan.berikutnya,
          label: 'Kelas berikutnya',
          judul: s.courseName,
          rincian: _rincianKelas(s),
          sudut: _hitungMundur(mulai.difference(sekarang)),
          onTap: () {
            ref.read(hariJadwalProvider.notifier).pilih(DateTime.now().weekday);
            _keTab(context, kTabJadwal);
          },
        );
      }
    }

    // 2. Tidak ada kelas lagi: tenggat yang lewat atau jatuh dalam 2 hari.
    final mepet =
        tugas
            .where(
              (t) =>
                  !t.isDone &&
                  t.tenggatLokal.difference(sekarang) < const Duration(days: 2),
            )
            .toList()
          ..sort((a, b) => a.deadline.compareTo(b.deadline));
    if (mepet.isNotEmpty) {
      final t = mepet.first;
      final telat = t.tenggatLokal.isBefore(sekarang);
      return _TampilanSorotan(
        jenis: _JenisSorotan.tenggat,
        label: telat ? 'Sudah lewat tenggat' : 'Tenggat terdekat',
        judul: t.title,
        rincian: [
          t.courseName ?? 'Tugas pribadi',
          if (mepet.length > 1) '+${mepet.length - 1} lainnya',
        ].join(' · '),
        sudut: telat
            ? 'Terlambat'
            : _hitungMundur(t.tenggatLokal.difference(sekarang)),
        aksi: (
          'Mulai fokus',
          Icons.timer_outlined,
          () => context.push('/academic/tasks/${t.id}/fokus'),
        ),
        onTap: () => context.push('/academic/tasks/${t.id}'),
      );
    }

    // 3. Hari ini kosong: sebut kapan kuliah berikutnya.
    final berikut = _kelasBerikutnya(semua, sekarang);
    return _TampilanSorotan(
      jenis: _JenisSorotan.bebas,
      label: hariIni.isEmpty
          ? 'Tidak ada kuliah hari ini'
          : 'Kuliah hari ini selesai',
      judul: 'Waktunya buat dirimu sendiri',
      rincian: berikut == null
          ? 'Belum ada jadwal kuliah tersimpan'
          : 'Berikutnya ${weekDayName(berikut.dayOfWeek)} '
                '${berikut.startTime.substring(0, 5)} · ${berikut.courseName}',
      onTap: () {
        ref.read(hariJadwalProvider.notifier).pilih(DateTime.now().weekday);
        _keTab(context, kTabJadwal);
      },
    );
  }

  static String _rincianKelas(ClassSchedule s) => [
    s.timeRangeLabel.replaceAll(' - ', '–'),
    ?s.room,
    if (s.lecturer case final l? when l.trim().isNotEmpty) l.trim(),
  ].join(' · ');

  static ClassSchedule? _kelasBerikutnya(
    List<ClassSchedule> semua,
    DateTime sekarang,
  ) {
    final rutin = semua.where((s) => !s.isPhl).toList();
    if (rutin.isEmpty) return null;
    for (var geser = 1; geser <= 7; geser++) {
      final hari = (sekarang.weekday - 1 + geser) % 7 + 1;
      final kelas = rutin.where((s) => s.dayOfWeek == hari).toList();
      if (kelas.isNotEmpty) return kelas.first;
    }
    return null;
  }
}

String _hitungMundur(Duration d) {
  if (d.inMinutes < 1) return 'Sebentar lagi';
  if (d.inMinutes < 60) return '${d.inMinutes} menit lagi';
  if (d.inHours < 24) {
    final menit = d.inMinutes % 60;
    return menit == 0
        ? '${d.inHours} jam lagi'
        : '${d.inHours} j $menit m lagi';
  }
  return '${d.inDays} hari lagi';
}

class _TampilanSorotan extends StatelessWidget {
  const _TampilanSorotan({
    required this.jenis,
    required this.label,
    required this.judul,
    required this.rincian,
    this.sudut,
    this.progres,
    this.aksi,
    this.onTap,
  });

  final _JenisSorotan jenis;
  final String label;
  final String judul;
  final String rincian;
  final String? sudut;
  final double? progres;

  /// Tombol kecil di bawah kartu untuk langkah berikutnya yang paling wajar.
  final (String, IconData, VoidCallback)? aksi;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (warna, ikon) = switch (jenis) {
      _JenisSorotan.berlangsung => (AppColors.academic, Icons.school_rounded),
      _JenisSorotan.berikutnya => (AppColors.academic, Icons.schedule_rounded),
      _JenisSorotan.tenggat => (AppColors.deadline, Icons.flag_rounded),
      _JenisSorotan.bebas => (AppColors.workout, Icons.wb_sunny_rounded),
    };
    const putih = Colors.white;
    final redup = Colors.white.withValues(alpha: 0.78);

    return Material(
      color: warna,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            // Ikon besar samar di pojok: memberi karakter tanpa gradien.
            Positioned(
              right: -18,
              bottom: -26,
              child: Icon(
                ikon,
                size: 132,
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (jenis == _JenisSorotan.berlangsung) ...[
                        const _TitikBerdenyut(),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: Text(
                          label.toUpperCase(),
                          style: TextStyle(
                            color: redup,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.9,
                          ),
                        ),
                      ),
                      if (sudut != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            sudut!,
                            style: const TextStyle(
                              color: putih,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    judul,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: putih,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    rincian,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: redup,
                      fontSize: 13.5,
                      height: 1.35,
                    ),
                  ),
                  if (progres != null) ...[
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: progres!.clamp(0.0, 1.0),
                        minHeight: 6,
                        color: putih,
                        backgroundColor: Colors.white.withValues(alpha: 0.25),
                      ),
                    ),
                  ],
                  if (aksi case (final label, final ikon, final tekan)) ...[
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: tekan,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: warna,
                        minimumSize: const Size(0, 40),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        textStyle: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      icon: Icon(ikon, size: 18),
                      label: Text(label),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Titik putih yang berdenyut pelan: tanda "sedang live".
class _TitikBerdenyut extends StatefulWidget {
  const _TitikBerdenyut();

  @override
  State<_TitikBerdenyut> createState() => _TitikBerdenyutState();
}

class _TitikBerdenyutState extends State<_TitikBerdenyut>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.35, end: 1.0).animate(_c),
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Cincin progres
// ---------------------------------------------------------------------------
