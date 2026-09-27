import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/domain/achievements.dart';
import '../../../core/offline/offline_banner.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/hero_header.dart';
import '../../../core/widgets/menu_list.dart';
import '../../academic/data/models/class_schedule.dart';
import '../../academic/data/models/task.dart';
import '../../academic/domain/schedule_conflict.dart';
import '../../academic/presentation/academic_providers.dart';
import '../../body/data/body_repository.dart';
import '../../body/domain/calorie_calculator.dart';
import '../../finance/data/finance_repository.dart';
import '../../finance/domain/finance_stats.dart';
import '../../finance/presentation/transaction_sheet.dart';
import '../../nutrition/data/nutrition_repository.dart';
import '../../nutrition/presentation/food_form_sheet.dart';
import '../../profile/data/profile_repository.dart';
import '../../workout/presentation/workout_providers.dart';

final _dayFormat = DateFormat('EEEE, d MMMM', 'id_ID');

/// Warna cincin asupan. Lima warna tab sudah terpakai untuk arti lain, dan
/// asupan butuh rona hangat yang tidak tertukar dengan koral tenggat.
const Color _warnaAsupan = Color(0xFFE8812C);

/// Target hari bergerak per minggu kalau belum ada target sendiri — batas
/// bawah anjuran aktivitas fisik orang dewasa (3–5 hari seminggu).
const int _targetLatihanMingguan = 4;

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _bukaCatatCepat(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Catat'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(classSchedulesProvider);
          ref.invalidate(tasksProvider);
          ref.invalidate(workoutSessionsProvider);
          ref.invalidate(profileProvider);
          ref.invalidate(foodLogsProvider);
          ref.invalidate(waterLogsProvider);
        },
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.md,
            MediaQuery.of(context).padding.top + 14,
            AppSpacing.md,
            AppSpacing.xl,
          ),
          children: const [
            _Sapaan(),
            SizedBox(height: 18),
            // Ditaruh di atas: catatan yang tertahan harus terlihat sebelum
            // kamu menganggap semuanya sudah tersimpan.
            OfflineBanner(),
            _KartuSorotan(),
            SizedBox(height: AppSpacing.md),
            _KartuCincin(),
            SizedBox(height: AppSpacing.md),
            _KartuMingguIni(),
            _AchievementsRow(),
            _Judul('Tenggat', aksi: 'Semua', tab: kTabTugas),
            _DaftarTenggat(),
            _Judul('Uang', aksi: 'Detail', tab: kTabKeuangan),
            _KartuUang(),
            _Judul('Lainnya'),
            _PintasanLainnya(),
            SizedBox(height: 72),
          ],
        ),
      ),
    );
  }
}

/// Pindah ke tab lain, bukan menumpuk halamannya di atas Beranda.
///
/// Kalau di-push, bar bawah tetap menunjuk Beranda padahal kamu sudah ada di
/// Jadwal, dan tombol kembali jadi satu-satunya jalan keluar.
void _keTab(BuildContext context, int tab) {
  StatefulNavigationShell.of(context).goBranch(tab);
}

bool _hariSama(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

DateTime _awalMinggu(DateTime t) {
  final hari = DateTime(t.year, t.month, t.day);
  return hari.subtract(Duration(days: hari.weekday - 1));
}

// ---------------------------------------------------------------------------
// Sapaan
// ---------------------------------------------------------------------------

/// Tanggal, sapaan, dan satu kalimat yang merangkum hari ini — bukan tiga
/// angka tanpa konteks.
class _Sapaan extends ConsumerWidget {
  const _Sapaan();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final user = ref.watch(currentUserProvider);
    final profile = ref.watch(profileProvider).value;
    final fullName = profile?.fullName;
    final nama = (fullName != null && fullName.trim().isNotEmpty)
        ? fullName.trim().split(' ').first
        : (user?.email?.split('@').first ?? 'Mahasiswa');
    final avatarUrl = profile?.avatarUrl;

    final jam = DateTime.now().hour;
    final salam = jam < 11
        ? 'Selamat pagi'
        : jam < 15
        ? 'Selamat siang'
        : jam < 19
        ? 'Selamat sore'
        : 'Selamat malam';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _dayFormat.format(DateTime.now()),
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  '$salam, $nama',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 26,
                    height: 1.15,
                    letterSpacing: -0.8,
                  ),
                ),
              ),
            ],
          ),
        ),
        HeroIconButton(
          icon: Icons.search,
          tooltip: 'Cari',
          onPressed: () => context.push('/search'),
        ),
        const SizedBox(width: 2),
        Semantics(
          button: true,
          label: 'Buka profil',
          child: InkWell(
            onTap: () => context.push('/profile'),
            customBorder: const CircleBorder(),
            child: CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.dashboard,
              backgroundImage: avatarUrl != null
                  ? NetworkImage(avatarUrl)
                  : null,
              child: avatarUrl == null
                  ? Text(
                      nama.isNotEmpty ? nama[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    )
                  : null,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Kartu sorotan: satu hal terpenting sekarang
// ---------------------------------------------------------------------------

enum _JenisSorotan { berlangsung, berikutnya, tenggat, bebas }

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
          onTap: () => _keTab(context, kTabJadwal),
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
          onTap: () => _keTab(context, kTabJadwal),
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
        onTap: () => _keTab(context, kTabTugas),
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
      onTap: () => _keTab(context, kTabJadwal),
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
    this.onTap,
  });

  final _JenisSorotan jenis;
  final String label;
  final String judul;
  final String rincian;
  final String? sudut;
  final double? progres;
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

class _DataCincin {
  const _DataCincin({
    required this.label,
    required this.nilai,
    required this.target,
    required this.satuan,
    required this.warna,
    required this.onTap,
  });

  final String label;
  final double nilai;
  final double target;
  final String satuan;
  final Color warna;
  final VoidCallback onTap;

  double get rasio => target <= 0 ? 0 : (nilai / target).clamp(0.0, 1.0);
}

/// Tiga cincin konsentris ala Apple Fitness: latihan minggu ini, asupan hari
/// ini, dan tugas minggu ini. Satu gambar yang langsung menjawab "sudah
/// seberapa jauh aku", dengan angka persisnya di samping.
class _KartuCincin extends ConsumerWidget {
  const _KartuCincin();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sekarang = DateTime.now();
    final awal = _awalMinggu(sekarang);
    final akhir = awal.add(const Duration(days: 7));

    // Latihan dihitung tujuh hari terakhir, bukan pekan kalender: di hari
    // Senin pekan kalender selalu nol padahal kamu baru latihan kemarin.
    final hariIni = DateTime(sekarang.year, sekarang.month, sekarang.day);
    final tujuhHari = hariIni.subtract(const Duration(days: 6));
    final aktif = ref.watch(activeDatesProvider);
    final hariLatihan = {
      for (final d in aktif)
        if (!DateTime(d.year, d.month, d.day).isBefore(tujuhHari) &&
            !d.isAfter(sekarang))
          DateTime(d.year, d.month, d.day),
    }.length;

    final asupan = ref.watch(todayNutritionProvider).value;
    final profil = ref.watch(bodyProfileProvider).value;
    final berat = ref.watch(currentWeightProvider).value;
    final targetKkal = (profil == null || berat == null)
        ? null
        : calculateCalories(
            profile: profil,
            weightKg: berat,
            now: sekarang,
          ).goalKcal;

    final tugas = ref.watch(tasksProvider).value ?? const <AcademicTask>[];
    final tugasMinggu = tugas
        .where((t) => !t.tenggatLokal.isBefore(awal) && t.tenggatLokal.isBefore(akhir))
        .toList();
    final tugasBeres = tugasMinggu.where((t) => t.isDone).length;

    final cincin = [
      _DataCincin(
        label: 'Latihan · 7 hari',
        nilai: hariLatihan.toDouble(),
        target: _targetLatihanMingguan.toDouble(),
        satuan: '/$_targetLatihanMingguan hari',
        warna: AppColors.workout,
        onTap: () => _keTab(context, kTabWorkout),
      ),
      _DataCincin(
        label: 'Asupan',
        nilai: asupan?.calories ?? 0,
        target: (targetKkal ?? 2000).toDouble(),
        satuan: targetKkal == null ? ' kkal' : '/${_ribuan(targetKkal)} kkal',
        warna: _warnaAsupan,
        onTap: () => context.push('/workout/nutrition'),
      ),
      _DataCincin(
        label: 'Tugas',
        nilai: tugasBeres.toDouble(),
        target: tugasMinggu.length.toDouble(),
        satuan: '/${tugasMinggu.length} pekan ini',
        warna: AppColors.deadline,
        onTap: () => _keTab(context, kTabTugas),
      ),
    ];

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
        child: Row(
          children: [
            SizedBox.square(
              dimension: 116,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutCubic,
                builder: (context, t, _) => CustomPaint(
                  painter: _LukisCincin(cincin: cincin, t: t),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                children: [for (final c in cincin) _BarisCincin(c)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _ribuan(num n) => NumberFormat.decimalPattern('id_ID').format(n.round());

class _BarisCincin extends StatelessWidget {
  const _BarisCincin(this.c);

  final _DataCincin c;

  @override
  Widget build(BuildContext context) {
    final redup = Theme.of(context).colorScheme.onSurfaceVariant;
    return InkWell(
      onTap: c.onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 30,
              decoration: BoxDecoration(
                color: c.warna,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.label,
                    style: TextStyle(fontSize: 12, color: redup, height: 1.2),
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: _ribuan(c.nilai),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                            ),
                          ),
                          TextSpan(
                            text: c.satuan,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: redup,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      style: const TextStyle(
                        height: 1.25,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LukisCincin extends CustomPainter {
  _LukisCincin({required this.cincin, required this.t});

  final List<_DataCincin> cincin;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    const tebal = 12.0;
    const jarak = 3.5;
    final pusat = size.center(Offset.zero);
    var jari = size.shortestSide / 2 - tebal / 2;

    for (final c in cincin) {
      final kotak = Rect.fromCircle(center: pusat, radius: jari);
      final kuas = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = tebal
        ..strokeCap = StrokeCap.round;

      canvas.drawCircle(
        pusat,
        jari,
        kuas..color = c.warna.withValues(alpha: 0.18),
      );
      final sudut = 2 * math.pi * c.rasio * t;
      if (sudut > 0) {
        canvas.drawArc(
          kotak,
          -math.pi / 2,
          sudut,
          false,
          kuas..color = c.warna,
        );
      }
      jari -= tebal + jarak;
    }
  }

  @override
  bool shouldRepaint(_LukisCincin old) => old.t != t || old.cincin != cincin;
}

// ---------------------------------------------------------------------------
// Minggu ini
// ---------------------------------------------------------------------------

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
                      onTap: () => _keTab(context, kTabJadwal),
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

class _Judul extends StatelessWidget {
  const _Judul(this.teks, {this.aksi, this.tab});

  final String teks;
  final String? aksi;
  final int? tab;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 26, 0, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              teks,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
          ),
          if (aksi != null && tab != null)
            TextButton(
              onPressed: () => _keTab(context, tab!),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: Text(aksi!),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tenggat
// ---------------------------------------------------------------------------

/// Empat tenggat terdekat. Tanggalnya jadi blok di kiri seperti kalender
/// meja; yang mepet (hari ini, besok, atau lewat) diwarnai koral.
class _DaftarTenggat extends ConsumerWidget {
  const _DaftarTenggat();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tugasAsync = ref.watch(tasksProvider);
    return tugasAsync.when(
      data: (semua) {
        final belum = semua.where((t) => !t.isDone).toList()
          ..sort((a, b) => a.deadline.compareTo(b.deadline));
        if (belum.isEmpty) {
          return const _KartuKosong(
            ikon: Icons.celebration_outlined,
            teks: 'Semua tugas beres. Nikmati waktumu.',
          );
        }
        return Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (final (i, t) in belum.take(4).indexed) ...[
                if (i > 0) const Divider(height: 1, indent: 72),
                _BarisTenggat(t),
              ],
            ],
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: LinearProgressIndicator(),
      ),
      error: (error, _) => const _KartuKosong(
        ikon: Icons.error_outline,
        teks: 'Tugas gagal dimuat.',
      ),
    );
  }
}

class _BarisTenggat extends StatelessWidget {
  const _BarisTenggat(this.t);

  final AcademicTask t;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final sekarang = DateTime.now();
    final hari = DateTime(
      t.deadline.year,
      t.deadline.month,
      t.deadline.day,
    ).difference(DateTime(sekarang.year, sekarang.month, sekarang.day)).inDays;
    final telat = t.tenggatLokal.isBefore(sekarang);
    final mepet = telat || hari <= 1;
    final kapan = telat
        ? 'Terlambat'
        : hari == 0
        ? 'Hari ini ${DateFormat('HH.mm').format(t.deadline)}'
        : hari == 1
        ? 'Besok'
        : '$hari hari lagi';

    final warnaBlok = mepet ? AppColors.deadline : colorScheme.onSurface;

    return InkWell(
      onTap: () => context.push('/academic/tasks/${t.id}'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 48,
              decoration: BoxDecoration(
                color: mepet
                    ? AppColors.deadline.withValues(alpha: 0.12)
                    : colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('MMM', 'id_ID').format(t.deadline).toUpperCase(),
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      color: warnaBlok,
                    ),
                  ),
                  Text(
                    '${t.deadline.day}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                      color: warnaBlok,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    t.courseName ?? 'Tugas pribadi',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              kapan,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: mepet
                    ? AppColors.deadline
                    : colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KartuKosong extends StatelessWidget {
  const _KartuKosong({required this.ikon, required this.teks});

  final IconData ikon;
  final String teks;

  @override
  Widget build(BuildContext context) {
    final redup = Theme.of(context).colorScheme.onSurfaceVariant;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Icon(ikon, size: 20, color: redup),
            const SizedBox(width: 12),
            Expanded(
              child: Text(teks, style: TextStyle(fontSize: 13.5, color: redup)),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Uang
// ---------------------------------------------------------------------------

/// Yang ditonjolkan jatah harian, bukan total pengeluaran — "boleh habis
/// berapa hari ini" lebih menentukan keputusanmu siang ini.
class _KartuUang extends ConsumerWidget {
  const _KartuUang();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final summaryAsync = ref.watch(financeSummaryProvider);

    return summaryAsync.when(
      data: (summary) {
        final jatah = summary.jatahHarian;
        final budget = summary.budget;
        if (jatah == null || budget == null || budget <= 0) {
          return _KartuKosong(
            ikon: Icons.account_balance_wallet_outlined,
            teks: summary.kosong
                ? 'Belum ada catatan keuangan.'
                : 'Keluar ${formatRupiah(summary.pengeluaran)} periode ini.',
          );
        }
        final kebobolan = (summary.sisaBudget ?? 0) <= 0;
        final rasio = (summary.pengeluaran / budget).clamp(0.0, 1.0);
        final warna = kebobolan
            ? AppColors.priorityHigh
            : rasio > 0.8
            ? AppColors.priorityMedium
            : AppColors.finance;

        return Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _keTab(context, kTabKeuangan),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              kebobolan ? 'Lewat anggaran' : 'Jatah hari ini',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 2),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                formatRupiah(
                                  kebobolan ? summary.sisaBudget!.abs() : jatah,
                                ),
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.8,
                                  color: kebobolan
                                      ? warna
                                      : colorScheme.onSurface,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: warna.withValues(alpha: 0.14),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.account_balance_wallet_rounded,
                          color: warna,
                          size: 21,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: rasio,
                      minHeight: 8,
                      color: warna,
                      backgroundColor: warna.withValues(alpha: 0.15),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        '${formatRupiahRingkas(summary.pengeluaran)} dari '
                        '${formatRupiahRingkas(budget)}',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${summary.sisaHari} hari lagi',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => const SizedBox(
        height: 60,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (error, _) => const _KartuKosong(
        ikon: Icons.error_outline,
        teks: 'Gagal memuat keuangan.',
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pintasan
// ---------------------------------------------------------------------------

/// Fitur yang tidak punya tab sendiri, sebagai deretan ubin berwarna yang
/// bisa digeser — seperti pintasan di aplikasi dompet atau ojek daring.
class _PintasanLainnya extends StatelessWidget {
  const _PintasanLainnya();

  static const _isi = [
    MenuItemData(
      icon: Icons.schedule_rounded,
      label: 'Rutinitas',
      rute: '/routine',
      warna: AppColors.dashboard,
    ),
    MenuItemData(
      icon: Icons.sticky_note_2_rounded,
      label: 'Catatan',
      rute: '/notes',
      warna: AppColors.note,
    ),
    MenuItemData(
      icon: Icons.flag_rounded,
      label: 'Target',
      rute: '/goals',
      warna: AppColors.deadline,
    ),
    MenuItemData(
      icon: Icons.favorite_rounded,
      label: 'Wishlist',
      rute: '/wishlist',
      warna: AppColors.finance,
    ),
    MenuItemData(
      icon: Icons.movie_rounded,
      label: 'Watchlist',
      rute: '/watchlist',
      warna: AppColors.watchlist,
    ),
    MenuItemData(
      icon: Icons.two_wheeler_rounded,
      label: 'Kendaraan',
      rute: '/vehicle',
      warna: AppColors.vehicle,
    ),
    MenuItemData(
      icon: Icons.badge_rounded,
      label: 'Dokumen',
      rute: '/documents',
      warna: AppColors.document,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: _isi.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final item = _isi[i];
          final warna = item.warna ?? AppColors.dashboard;
          return Material(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(18),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => context.push(item.rute),
              child: Container(
                width: 84,
                decoration: BoxDecoration(
                  border: Border.all(color: colorScheme.outlineVariant),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: warna.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(item.icon, color: warna, size: 22),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Lencana
// ---------------------------------------------------------------------------

class _AchievementsRow extends ConsumerWidget {
  const _AchievementsRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Badge "Workout 30 Hari" harus berarti 30 hari latihan. Hari istirahat
    // menyambung streak, tapi tidak boleh ikut mengisi lencananya.
    final workoutStreak =
        ref.watch(workoutStreakProvider).value?.activeInCurrent ?? 0;
    final deadlineStreak =
        ref.watch(deadlineStreakProvider).value?.current ?? 0;
    final achievements = computeAchievements(
      workoutStreak: workoutStreak,
      deadlineStreak: deadlineStreak,
    );

    if (achievements.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          for (final achievement in achievements)
            Chip(
              avatar: Icon(
                achievement.icon,
                size: 18,
                color: AppColors.workout,
              ),
              label: Text(achievement.label),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Catat cepat
// ---------------------------------------------------------------------------

/// Satu pintu untuk empat catatan yang paling sering: tidak perlu pindah tab
/// dulu hanya untuk mencatat jajan atau tugas yang baru diumumkan dosen.
Future<void> _bukaCatatCepat(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheet) {
      Future<void> pilih(Future<void> Function() aksi) async {
        Navigator.pop(sheet);
        await aksi();
      }

      final isi = [
        (
          'Tugas',
          'Tenggat baru',
          Icons.assignment_rounded,
          AppColors.deadline,
          () => pilih(() async {
            await context.push('/academic/tasks/new');
            ref.invalidate(tasksProvider);
          }),
        ),
        (
          'Pengeluaran',
          'Jajan, ongkos, tagihan',
          Icons.payments_rounded,
          AppColors.finance,
          () => pilih(() => showTransactionSheet(context)),
        ),
        (
          'Makan',
          'Kalori & makro',
          Icons.restaurant_rounded,
          _warnaAsupan,
          () => pilih(() => showFoodFormSheet(context)),
        ),
        (
          'Latihan',
          'Sesi workout',
          Icons.fitness_center_rounded,
          AppColors.workout,
          () => pilih(() async {
            await context.push('/workout/new');
            ref.invalidate(workoutSessionsProvider);
          }),
        ),
      ];

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 4, bottom: 12),
                child: Text(
                  'Catat cepat',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                ),
              ),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.55,
                children: [
                  for (final (judul, sub, ikon, warna, aksi) in isi)
                    Material(
                      color: warna.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(18),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: aksi,
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: warna,
                                  borderRadius: BorderRadius.circular(11),
                                ),
                                child: Icon(ikon, color: Colors.white, size: 20),
                              ),
                              const Spacer(),
                              Text(
                                judul,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                sub,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(sheet).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}
