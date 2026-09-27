import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/warna_matkul.dart';
import '../../../core/widgets/daftar_bergaris.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/hero_header.dart';
import '../data/academic_repository.dart';
import '../data/models/class_schedule.dart';
import '../domain/schedule_conflict.dart';
import 'academic_providers.dart';

final _phlDateFormat = DateFormat('d MMM', 'id_ID');

class SchedulePage extends ConsumerStatefulWidget {
  const SchedulePage({super.key});

  @override
  ConsumerState<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends ConsumerState<SchedulePage> {
  /// 1 = Senin ... 7 = Minggu. Awalnya hari ini.
  int _hari = DateTime.now().weekday;

  /// Tampilan per hari (timeline) atau sepekan (daftar ringkas).
  bool _sepekan = false;

  Timer? _detak;

  @override
  void initState() {
    super.initState();
    // Garis "sekarang" dan status "sedang berlangsung" ikut bergeser.
    _detak = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _detak?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final schedulesAsync = ref.watch(classSchedulesProvider);
    final semua = schedulesAsync.value ?? const <ClassSchedule>[];

    // Mata kuliah yang punya jadwal = yang kamu jalani semester ini.
    //
    // Sengaja tidak memakai kolom `semester` di tabel courses: mata kuliah
    // hasil import KRS tidak mengisinya. Jadwal kelas cuma ada untuk semester
    // yang sedang diambil, dan itu bukti yang lebih dapat dipercaya.
    final matkulSemesterIni = semua.map((s) => s.courseId).toSet().length;
    final rutin = semua.where((s) => !s.isPhl).length;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/academic/schedule/new');
          ref.invalidate(classSchedulesProvider);
        },
        icon: const Icon(Icons.add),
        label: const Text('Jadwal'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(classSchedulesProvider);
          ref.invalidate(coursesProvider);
        },
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            HeroHeader(
              title: 'Jadwal',
              subtitle: '$rutin kelas sepekan · $matkulSemesterIni mata kuliah',
              color: AppColors.academic,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  HeroIconButton(
                    icon: Icons.how_to_reg_outlined,
                    tooltip: 'Absensi',
                    onPressed: () => context.push('/academic/schedule/attendance'),
                  ),
                  HeroIconButton(
                    icon: Icons.workspace_premium_outlined,
                    tooltip: 'Nilai & IPK',
                    onPressed: () => context.push('/academic/schedule/grades'),
                  ),
                  HeroIconButton(
                    icon: Icons.document_scanner_outlined,
                    tooltip: 'Import dari foto KRS',
                    onPressed: () => context.push('/academic/schedule/import'),
                  ),
                  HeroIconButton(
                    icon: Icons.calendar_month,
                    tooltip: 'Kalender',
                    onPressed: () => context.push('/academic/schedule/calendar'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, 0),
              child: _PemilihHari(
                jadwal: semua,
                terpilih: _sepekan ? null : _hari,
                onPilih: (h) => setState(() {
                  _hari = h;
                  _sepekan = false;
                }),
                onSepekan: () => setState(() => _sepekan = !_sepekan),
                sepekan: _sepekan,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 96),
              child: schedulesAsync.when(
                data: (items) => items.isEmpty
                    ? const EmptyState(
                        icon: Icons.event_note_outlined,
                        title: 'Belum ada jadwal kuliah',
                        subtitle: 'Tekan tombol + atau import dari foto KRS',
                        color: AppColors.academic,
                      )
                    : _sepekan
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _buildDayGroups(context, ref, items),
                      )
                    : _TimelineHari(hari: _hari, semua: items),
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, stackTrace) => EmptyState(
                  icon: Icons.error_outline,
                  title: 'Gagal memuat jadwal',
                  subtitle: '$error',
                  color: AppColors.academic,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildDayGroups(BuildContext context, WidgetRef ref, List<ClassSchedule> items) {
    final byDay = <int, List<ClassSchedule>>{};
    for (final schedule in items) {
      byDay.putIfAbsent(schedule.dayOfWeek, () => []).add(schedule);
    }
    final days = byDay.keys.toList()..sort();
    final today = DateTime.now().weekday;
    final bentrok = conflictMap(items);

    final widgets = <Widget>[];
    if (bentrok.isNotEmpty) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: _ConflictBanner(pasangan: totalPasanganBentrok(bentrok)),
        ),
      );
    }

    for (final day in days) {
      widgets.add(_DayHeader(day: day, count: byDay[day]!.length, isToday: day == today));
      widgets.add(
        DaftarBergaris(
          // Garis pemisah mulai sejajar nama mata kuliah, melewati kolom jam.
          indentGaris: AppSpacing.md + _lebarJam + AppSpacing.md,
          children: [
            for (final schedule in byDay[day]!)
              ScheduleTile(schedule: schedule, conflicts: bentrok[schedule.id] ?? const []),
          ],
        ),
      );
      widgets.add(const SizedBox(height: AppSpacing.lg));
    }
    return widgets;
  }
}

/// Tanggal (di pekan ini) untuk hari ke-[hari], 1 = Senin.
DateTime _tanggalPekanIni(int hari) {
  final n = DateTime.now();
  final senin = DateTime(n.year, n.month, n.day).subtract(Duration(days: n.weekday - 1));
  return senin.add(Duration(days: hari - 1));
}

bool _hariSama(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// Kelas yang jatuh pada hari ke-[hari] pekan ini: kelas rutin di hari itu,
/// ditambah kelas pengganti (PHL) yang tanggalnya persis hari itu.
List<ClassSchedule> _kelasPada(List<ClassSchedule> semua, int hari) {
  final tanggal = _tanggalPekanIni(hari);
  return [
    for (final s in semua)
      if (s.isPhl
          ? (s.specificDate != null && _hariSama(s.specificDate!, tanggal))
          : s.dayOfWeek == hari)
        s,
  ]..sort((a, b) => (menitDariJam(a.startTime) ?? 0).compareTo(menitDariJam(b.startTime) ?? 0));
}

/// Tujuh pil hari plus tombol "Sepekan". Tiap pil menunjukkan tanggal dan
/// titik sebanyak kelasnya, jadi hari padat kelihatan tanpa dibuka.
class _PemilihHari extends StatelessWidget {
  const _PemilihHari({
    required this.jadwal,
    required this.terpilih,
    required this.onPilih,
    required this.onSepekan,
    required this.sepekan,
  });

  final List<ClassSchedule> jadwal;
  final int? terpilih;
  final ValueChanged<int> onPilih;
  final VoidCallback onSepekan;
  final bool sepekan;

  static const _singkat = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hariIni = DateTime.now().weekday;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (var h = 1; h <= 7; h++)
              Expanded(
                child: Builder(
                  builder: (context) {
                    final pilih = terpilih == h;
                    final jumlah = _kelasPada(jadwal, h).length;
                    final warnaTeks = pilih ? Colors.white : colorScheme.onSurface;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Material(
                        color: pilih
                            ? AppColors.academic
                            : (h == hariIni
                                  ? AppColors.academic.withValues(alpha: 0.1)
                                  : colorScheme.surface),
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => onPilih(h),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Column(
                              children: [
                                Text(
                                  _singkat[h - 1],
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: pilih
                                        ? Colors.white.withValues(alpha: 0.85)
                                        : (h == hariIni
                                              ? AppColors.academic
                                              : colorScheme.onSurfaceVariant),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${_tanggalPekanIni(h).day}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: warnaTeks,
                                    fontFeatures: const [FontFeature.tabularFigures()],
                                  ),
                                ),
                                const SizedBox(height: 5),
                                SizedBox(
                                  height: 5,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      for (var i = 0; i < math.min(jumlah, 3); i++)
                                        Container(
                                          width: 5,
                                          height: 5,
                                          margin: const EdgeInsets.symmetric(horizontal: 1),
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: pilih ? Colors.white : AppColors.academic,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: Text(
                sepekan
                    ? 'Semua kelas sepekan'
                    : '${weekDayName(terpilih ?? hariIni)}, '
                          '${DateFormat('d MMMM', 'id_ID').format(_tanggalPekanIni(terpilih ?? hariIni))}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
            TextButton.icon(
              onPressed: onSepekan,
              icon: Icon(sepekan ? Icons.view_day_outlined : Icons.view_week_outlined, size: 18),
              label: Text(sepekan ? 'Per hari' : 'Sepekan'),
            ),
          ],
        ),
      ],
    );
  }
}

/// Satu hari sebagai garis waktu: blok kelas berwarna per mata kuliah, jeda
/// di antaranya disebut panjangnya, dan — kalau hari ini — garis "sekarang".
class _TimelineHari extends StatelessWidget {
  const _TimelineHari({required this.hari, required this.semua});

  final int hari;
  final List<ClassSchedule> semua;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final kelas = _kelasPada(semua, hari);
    final sekarang = DateTime.now();
    final hariIni = hari == sekarang.weekday;
    final menitSekarang = sekarang.hour * 60 + sekarang.minute;
    final bentrok = conflictMap(semua);

    if (kelas.isEmpty) {
      return Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
          child: Column(
            children: [
              Icon(
                Icons.weekend_outlined,
                size: 40,
                color: AppColors.academic.withValues(alpha: 0.7),
              ),
              const SizedBox(height: 12),
              Text(
                'Tidak ada kuliah hari ${weekDayName(hari)}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                'Waktu kosong untuk tugas, latihan, atau istirahat.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    final anak = <Widget>[];
    int? akhirSebelum;
    var garisSudah = !hariIni;

    void pasangGaris() {
      anak.add(_GarisSekarang(jam: DateFormat('HH.mm').format(sekarang)));
      garisSudah = true;
    }

    for (final s in kelas) {
      final mulai = menitDariJam(s.startTime) ?? 0;
      final selesai = menitDariJam(s.endTime) ?? mulai;

      if (!garisSudah && menitSekarang < mulai) pasangGaris();

      if (akhirSebelum != null && mulai - akhirSebelum >= 20) {
        anak.add(_Jeda(menit: mulai - akhirSebelum));
      }

      final status = !hariIni
          ? _StatusKelas.nanti
          : menitSekarang >= selesai
          ? _StatusKelas.selesai
          : menitSekarang >= mulai
          ? _StatusKelas.berlangsung
          : _StatusKelas.nanti;

      anak.add(
        _BlokKelas(
          schedule: s,
          status: status,
          progres: status == _StatusKelas.berlangsung && selesai > mulai
              ? (menitSekarang - mulai) / (selesai - mulai)
              : null,
          bentrok: bentrok[s.id] ?? const [],
        ),
      );
      if (status == _StatusKelas.berlangsung) garisSudah = true;
      akhirSebelum = selesai;
    }
    if (!garisSudah) pasangGaris();

    final totalMenit = kelas.fold<int>(
      0,
      (n, s) => n + ((menitDariJam(s.endTime) ?? 0) - (menitDariJam(s.startTime) ?? 0)),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...anak,
        const SizedBox(height: AppSpacing.sm),
        Text(
          '${kelas.length} kelas · ${_durasi(totalMenit)} di kampus',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12.5, color: colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

String _durasi(int menit) {
  final j = menit ~/ 60;
  final m = menit % 60;
  if (j == 0) return '$m menit';
  if (m == 0) return '$j jam';
  return '$j j $m m';
}

enum _StatusKelas { selesai, berlangsung, nanti }

class _BlokKelas extends StatelessWidget {
  const _BlokKelas({
    required this.schedule,
    required this.status,
    this.progres,
    this.bentrok = const [],
  });

  final ClassSchedule schedule;
  final _StatusKelas status;
  final double? progres;
  final List<ScheduleConflict> bentrok;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final warna = warnaMatkul(schedule.courseId);
    final selesai = status == _StatusKelas.selesai;
    final jalan = status == _StatusKelas.berlangsung;
    final mulai = menitDariJam(schedule.startTime) ?? 0;
    final akhir = menitDariJam(schedule.endTime) ?? mulai;

    final isi = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 50,
          child: Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  schedule.startTime.substring(0, 5),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  schedule.endTime.substring(0, 5),
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: Material(
            color: jalan ? warna : warna.withValues(alpha: 0.11),
            borderRadius: BorderRadius.circular(18),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => context.push('/academic/schedule/${schedule.id}/edit'),
              child: Container(
                constraints: BoxConstraints(minHeight: 64 + (akhir - mulai) * 0.35),
                decoration: BoxDecoration(
                  border: Border(left: BorderSide(color: warna, width: 5)),
                ),
                padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            schedule.courseName,
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                              height: 1.25,
                              color: jalan ? Colors.white : colorScheme.onSurface,
                            ),
                          ),
                        ),
                        if (jalan)
                          const _Lencana('Berlangsung', latar: Colors.white24, teks: Colors.white)
                        else if (schedule.isPhl)
                          _Lencana(
                            schedule.specificDate != null
                                ? 'PHL ${_phlDateFormat.format(schedule.specificDate!)}'
                                : 'PHL',
                            latar: warna.withValues(alpha: 0.18),
                            teks: warna,
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    _InfoKelas(
                      ikon: Icons.schedule_rounded,
                      teks: _durasi(akhir - mulai),
                      putih: jalan,
                    ),
                    if (schedule.room case final r? when r.trim().isNotEmpty)
                      _InfoKelas(ikon: Icons.place_outlined, teks: r.trim(), putih: jalan),
                    if (schedule.lecturer case final l? when l.trim().isNotEmpty)
                      _InfoKelas(ikon: Icons.person_outline, teks: l.trim(), putih: jalan),
                    if (bentrok.isNotEmpty)
                      _InfoKelas(
                        ikon: Icons.warning_amber_rounded,
                        teks: 'Bentrok: ${bentrok.map((c) => c.lawan.courseName).join(', ')}',
                        warna: jalan ? Colors.white : colorScheme.error,
                      ),
                    if (progres != null) ...[
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: progres!.clamp(0.0, 1.0),
                          minHeight: 5,
                          color: Colors.white,
                          backgroundColor: Colors.white24,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Selesai ${akhir - (DateTime.now().hour * 60 + DateTime.now().minute)} menit lagi',
                        style: const TextStyle(fontSize: 12, color: Colors.white),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Opacity(opacity: selesai ? 0.5 : 1, child: isi),
    );
  }
}

class _InfoKelas extends StatelessWidget {
  const _InfoKelas({required this.ikon, required this.teks, this.putih = false, this.warna});

  final IconData ikon;
  final String teks;
  final bool putih;
  final Color? warna;

  @override
  Widget build(BuildContext context) {
    final c =
        warna ??
        (putih
            ? Colors.white.withValues(alpha: 0.9)
            : Theme.of(context).colorScheme.onSurfaceVariant);
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        children: [
          Icon(ikon, size: 14, color: c),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              teks,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, color: c),
            ),
          ),
        ],
      ),
    );
  }
}

class _Lencana extends StatelessWidget {
  const _Lencana(this.label, {required this.latar, required this.teks});

  final String label;
  final Color latar;
  final Color teks;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: latar, borderRadius: BorderRadius.circular(99)),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: teks),
      ),
    );
  }
}

class _Jeda extends StatelessWidget {
  const _Jeda({required this.menit});

  final int menit;

  @override
  Widget build(BuildContext context) {
    final redup = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(left: 50, bottom: 10),
      child: Row(
        children: [
          Icon(Icons.coffee_outlined, size: 15, color: redup),
          const SizedBox(width: 6),
          Text(
            'Jeda ${_durasi(menit)}',
            style: TextStyle(fontSize: 12.5, color: redup, fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 10),
          Expanded(child: Divider(color: Theme.of(context).colorScheme.outlineVariant)),
        ],
      ),
    );
  }
}

class _GarisSekarang extends StatelessWidget {
  const _GarisSekarang({required this.jam});

  final String jam;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 50,
            child: Text(
              jam,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: AppColors.deadline,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          Container(
            width: 9,
            height: 9,
            decoration: const BoxDecoration(color: AppColors.deadline, shape: BoxShape.circle),
          ),
          const Expanded(child: Divider(color: AppColors.deadline, thickness: 1.5, height: 1.5)),
        ],
      ),
    );
  }
}

class _ConflictBanner extends StatelessWidget {
  const _ConflictBanner({required this.pasangan});

  /// Jumlah pasangan yang bertabrakan, bukan jumlah jadwal: dua kelas yang
  /// saling menimpa itu satu masalah.
  final int pasangan;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, size: 18, color: colorScheme.error),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pasangan == 1
                      ? 'Ada 1 jadwal yang bertabrakan'
                      : 'Ada $pasangan jadwal yang bertabrakan',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: colorScheme.onErrorContainer,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Kartunya ditandai di bawah. Biasanya ini sisa import KRS '
                  'yang terlanjur dijalankan dua kali.',
                  style: TextStyle(fontSize: 12, height: 1.35, color: colorScheme.onErrorContainer),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.day, required this.count, required this.isToday});

  final int day;
  final int count;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final redup = TextStyle(fontSize: 12.5, color: colorScheme.onSurfaceVariant);

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            weekDayName(day),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: -0.3),
          ),
          if (isToday) ...[
            const SizedBox(width: AppSpacing.sm),
            Text(
              'Hari ini',
              style: redup.copyWith(color: colorScheme.primary, fontWeight: FontWeight.w600),
            ),
          ],
          const Spacer(),
          Text('$count kelas', style: redup),
        ],
      ),
    );
  }
}

/// Lebar kolom jam. Cukup untuk "08:00" dalam angka tabular pada ukuran
/// huruf 1.3x tanpa patah baris.
const double _lebarJam = 50;

/// Satu baris jadwal. Publik supaya tata letaknya bisa digambar langsung di
/// test tampilan tanpa perlu menghidupkan seluruh halaman beserta Supabase-nya.
class ScheduleTile extends ConsumerWidget {
  const ScheduleTile({super.key, required this.schedule, this.conflicts = const []});

  final ClassSchedule schedule;
  final List<ScheduleConflict> conflicts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return Dismissible(
      key: ValueKey(schedule.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: colorScheme.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Icon(Icons.delete_outline, color: colorScheme.onErrorContainer),
      ),
      confirmDismiss: (_) => showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Hapus jadwal?'),
          content: Text('Jadwal ${schedule.courseName} akan dihapus.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hapus')),
          ],
        ),
      ),
      onDismissed: (_) async {
        await ref.read(academicRepositoryProvider).deleteSchedule(schedule.id);
        ref.invalidate(classSchedulesProvider);
      },
      child: InkWell(
        onTap: () => context.push('/academic/schedule/${schedule.id}/edit'),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm + 4,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: _lebarJam,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        schedule.startTime.substring(0, 5),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          height: 1.3,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        schedule.endTime.substring(0, 5),
                        style: TextStyle(
                          fontSize: 12.5,
                          color: colorScheme.onSurfaceVariant,
                          height: 1.3,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      schedule.courseName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Ruangan dan kode berbagi satu baris. Keduanya pendek,
                    // dan menaruhnya sendiri-sendiri membuat kartunya tinggi
                    // tanpa menambah apa pun yang bisa dibaca.
                    Row(
                      children: [
                        Flexible(
                          child: _MetaLine(
                            icon: Icons.place_outlined,
                            text: schedule.room ?? 'Ruangan belum diatur',
                          ),
                        ),
                        // Kode mata kuliah dan kode kelas yang dipakai saat
                        // mencocokkan dengan portal kampus atau grup kelas.
                        // Nama mata kuliah saja sering tidak cukup kalau satu
                        // mata kuliah dibuka untuk beberapa kelas.
                        if (_kodeGabungan(schedule) case final kode?) ...[
                          const SizedBox(width: 10),
                          Flexible(
                            child: _MetaLine(icon: Icons.tag, text: kode),
                          ),
                        ],
                      ],
                    ),
                    if (schedule.lecturer != null && schedule.lecturer!.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      _MetaLine(icon: Icons.person_outline, text: schedule.lecturer!),
                    ],
                    if (conflicts.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      _MetaLine(
                        icon: Icons.warning_amber_rounded,
                        // Nama lawannya disebut, bukan cuma "bentrok" —
                        // supaya kamu tahu mana yang harus dihapus tanpa
                        // membandingkan jam satu per satu.
                        text:
                            'Bentrok: '
                            '${conflicts.map((c) => c.lawan.courseName).join(', ')}',
                        color: colorScheme.error,
                      ),
                    ],
                  ],
                ),
              ),
              if (schedule.isPhl)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    border: Border.all(color: colorScheme.outlineVariant),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    schedule.specificDate != null
                        ? 'PHL ${_phlDateFormat.format(schedule.specificDate!)}'
                        : 'PHL',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.icon, required this.text, this.color});

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    // Menyusut mengikuti isinya, bukan melebar memenuhi baris: dua baris meta
    // bisa berdampingan tanpa yang pertama mendorong yang kedua keluar layar.
    // Teksnya tetap dipotong dengan elipsis kalau ruangnya memang kurang.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: color),
          ),
        ),
      ],
    );
  }
}

/// "SIC204 · TI-B2", atau salah satunya saja kalau yang lain kosong.
/// Null kalau dua-duanya belum ada, supaya tidak ada baris kosong menggantung.
String? _kodeGabungan(ClassSchedule schedule) {
  final bagian = [
    if (schedule.courseCode case final kode? when kode.trim().isNotEmpty) kode.trim(),
    if (schedule.classCode case final kode? when kode.trim().isNotEmpty) kode.trim(),
  ];
  return bagian.isEmpty ? null : bagian.join('  ·  ');
}
