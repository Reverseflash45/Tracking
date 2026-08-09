import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/hero_header.dart';
import '../../academic/data/academic_repository.dart';
import '../../academic/data/models/class_schedule.dart';
import '../../academic/data/models/course.dart';
import '../../academic/domain/matkul_aktif.dart';
import '../../academic/presentation/academic_providers.dart';
import '../data/attendance_repository.dart';
import '../domain/attendance.dart';

const _color = AppColors.academic;
final _tanggalPendek = DateFormat('d MMM', 'id_ID');
final _tanggalPanjang = DateFormat('EEEE, d MMMM y', 'id_ID');

/// Absensi kuliah.
///
/// Yang paling ingin diketahui bukan "sudah bolos berapa kali", tapi "boleh
/// bolos berapa kali lagi". Angka pertama menjelaskan masa lalu; angka kedua
/// yang menentukan apa yang kamu lakukan besok pagi.
class AttendancePage extends ConsumerWidget {
  const AttendancePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coursesAsync = ref.watch(coursesProvider);
    final catatanAsync = ref.watch(attendanceProvider);

    final semuaCourses = coursesAsync.value ?? const <Course>[];
    final catatan = catatanAsync.value ?? const <Attendance>[];
    final jadwal = ref.watch(classSchedulesProvider).value ?? const <ClassSchedule>[];

    // Hanya mata kuliah semester ini. Daftar `courses` menumpuk terus karena
    // mata kuliah lama tidak pernah dihapus — nilainya masih dipakai menghitung
    // IPK — jadi tanpa saringan ini halamannya berisi puluhan mata kuliah yang
    // sudah tamat dan absensinya tidak lagi bisa berubah.
    //
    // Yang sudah punya catatan tetap ikut walau jadwalnya sudah lewat: kalau
    // tidak, catatan kehadiran semester lalu jadi tidak bisa dibuka lagi.
    final courses = matkulAktif(
      semuaCourses,
      jadwal,
      tetap: {for (final c in catatan) c.courseId},
    );
    final tersembunyi = semuaCourses.length - courses.length;

    final nama = {for (final c in courses) c.id: c.name};
    final rekap = urutkanRekap(
      rekapKehadiran(
        catatan: catatan,
        courseIds: [for (final c in courses) c.id],
        totalPertemuan: {for (final c in courses) c.id: c.totalMeetings},
        maksAbsenPersen: {for (final c in courses) c.id: c.maxAbsencePercent},
      ),
      (id) => nama[id] ?? '',
    );

    final perluDiperhatikan = rekap
        .where((r) =>
            r.statusJatah == StatusJatah.lewat || r.statusJatah == StatusJatah.hampir)
        .length;
    final belumDiisi = rekap.where((r) => r.totalPertemuan == null).length;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(attendanceProvider);
          ref.invalidate(coursesProvider);
          ref.invalidate(classSchedulesProvider);
        },
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            HeroHeader.sub(
              title: 'Absensi',
              subtitle: 'Kehadiran dan sisa jatah per mata kuliah',
              color: _color,
              leading: HeroIconButton(
                icon: Icons.arrow_back,
                tooltip: 'Kembali',
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              stats: [
                HeroStatData(
                  icon: Icons.event_available_outlined,
                  value: '${catatan.length}',
                  label: 'Pertemuan Dicatat',
                ),
                HeroStatData(
                  icon: Icons.warning_amber_outlined,
                  value: '$perluDiperhatikan',
                  label: 'Perlu Dijaga',
                ),
                HeroStatData(
                  icon: Icons.menu_book_outlined,
                  value: '${courses.length}',
                  label: 'Mata Kuliah',
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.xl,
              ),
              child: courses.isEmpty
                  ? const EmptyState(
                      icon: Icons.how_to_reg_outlined,
                      title: 'Belum ada mata kuliah',
                      subtitle: 'Tambahkan jadwal kuliah dulu, absensinya mengikuti dari situ',
                      color: _color,
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (belumDiisi > 0) ...[
                          _CatatanJatah(jumlah: belumDiisi),
                          const SizedBox(height: AppSpacing.md),
                        ],
                        for (final r in rekap) ...[
                          _KartuMataKuliah(
                            rekap: r,
                            nama: nama[r.courseId] ?? '-',
                            catatan: [
                              for (final c in catatan)
                                if (c.courseId == r.courseId) c
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                        ],
                        if (tersembunyi > 0) _CatatanSemesterLama(jumlah: tersembunyi),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Keterangan bahwa daftarnya memang tidak memuat seluruh mata kuliah.
///
/// Tanpa ini, hilangnya puluhan mata kuliah dari daftar terbaca sebagai data
/// yang rusak. Yang dijelaskan bukan cuma "disembunyikan", tapi dasarnya:
/// jadwal kelas.
class _CatatanSemesterLama extends StatelessWidget {
  const _CatatanSemesterLama({required this.jumlah});

  final int jumlah;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
      child: Text(
        '$jumlah mata kuliah semester lalu tidak ditampilkan — yang muncul di '
        'sini hanya yang punya jadwal kelas semester ini. Yang sudah terlanjur '
        'punya catatan kehadiran tetap ikut.',
        style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant, height: 1.4),
      ),
    );
  }
}

/// Keterangan kenapa sebagian mata kuliah tidak menampilkan sisa jatah.
class _CatatanJatah extends StatelessWidget {
  const _CatatanJatah({required this.jumlah});

  final int jumlah;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, size: 18, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '$jumlah mata kuliah belum punya jumlah pertemuan, jadi sisa jatah '
                'tidak masuknya belum bisa dihitung. Isi lewat tombol pensil — '
                'angkanya tidak ditebak, karena jatah bolos yang salah lebih '
                'berbahaya daripada tidak ada angka sama sekali.',
                style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KartuMataKuliah extends ConsumerWidget {
  const _KartuMataKuliah({
    required this.rekap,
    required this.nama,
    required this.catatan,
  });

  final RekapKehadiran rekap;
  final String nama;
  final List<Attendance> catatan;

  Color _warnaStatus(ColorScheme scheme) => switch (rekap.statusJatah) {
        StatusJatah.lewat => AppColors.priorityHigh,
        StatusJatah.hampir => AppColors.priorityMedium,
        StatusJatah.aman => AppColors.priorityLow,
        StatusJatah.belumDiketahui => scheme.onSurfaceVariant,
      };

  String _labelJatah() => switch (rekap.statusJatah) {
        StatusJatah.belumDiketahui => 'Jumlah pertemuan belum diisi',
        StatusJatah.lewat => 'Lewat ${-rekap.sisaJatah!} pertemuan dari batas',
        _ => 'Sisa jatah ${rekap.sisaJatah} pertemuan',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final warna = _warnaStatus(colorScheme);
    final persen = rekap.persenKehadiran;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    nama,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  tooltip: 'Atur jumlah pertemuan',
                  onPressed: () => _aturPertemuan(context, ref),
                ),
              ],
            ),
            Text(
              _labelJatah(),
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: warna),
            ),
            const SizedBox(height: 12),

            // Rincian dipisah dan diberi nama masing-masing. Izin dan sakit ikut
            // memakan jatah di sini, dan sebagian kampus tidak begitu — jadi
            // angkanya harus bisa kamu urai sendiri, bukan cuma satu total.
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                _Angka(label: 'Hadir', nilai: '${rekap.hadir}', warna: AppColors.priorityLow),
                _Angka(label: 'Izin', nilai: '${rekap.izin}'),
                _Angka(label: 'Sakit', nilai: '${rekap.sakit}'),
                _Angka(label: 'Alpa', nilai: '${rekap.alpa}', warna: AppColors.priorityHigh),
                if (persen != null)
                  _Angka(label: 'Kehadiran', nilai: '${persen.round()}%'),
                if (rekap.belumTercatat case final belum? when belum > 0)
                  _Angka(label: 'Belum dicatat', nilai: '$belum'),
              ],
            ),

            if (catatan.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 8),
              for (final item in catatan.take(3)) _BarisCatatan(item: item),
              if (catatan.length > 3)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '+${catatan.length - 3} pertemuan lain',
                    style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                  ),
                ),
            ],

            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _catatPertemuan(context, ref),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Catat pertemuan'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _catatPertemuan(BuildContext context, WidgetRef ref) async {
    final hasil = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _FormPertemuan(courseId: rekap.courseId, nama: nama),
    );
    if (hasil == true) ref.invalidate(attendanceProvider);
  }

  Future<void> _aturPertemuan(BuildContext context, WidgetRef ref) async {
    final hasil = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _FormPertemuanSemester(rekap: rekap, nama: nama),
    );
    if (hasil == true) ref.invalidate(coursesProvider);
  }
}

class _Angka extends StatelessWidget {
  const _Angka({required this.label, required this.nilai, this.warna});

  final String label;
  final String nilai;
  final Color? warna;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          nilai,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: warna ?? colorScheme.onSurface,
          ),
        ),
        Text(label, style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant)),
      ],
    );
  }
}

class _BarisCatatan extends StatelessWidget {
  const _BarisCatatan({required this.item});

  final Attendance item;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 52,
            child: Text(
              _tanggalPendek.format(item.meetingDate),
              style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
            ),
          ),
          SizedBox(
            width: 48,
            child: Text(
              item.status.label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: item.status.masuk ? AppColors.priorityLow : AppColors.priorityMedium,
              ),
            ),
          ),
          Expanded(
            child: Text(
              item.note ?? '-',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

/// Form catat satu pertemuan.
class _FormPertemuan extends ConsumerStatefulWidget {
  const _FormPertemuan({required this.courseId, required this.nama});

  final String courseId;
  final String nama;

  @override
  ConsumerState<_FormPertemuan> createState() => _FormPertemuanState();
}

class _FormPertemuanState extends ConsumerState<_FormPertemuan> {
  DateTime _tanggal = DateTime.now();
  StatusKehadiran _status = StatusKehadiran.hadir;
  final _catatan = TextEditingController();
  bool _menyimpan = false;

  @override
  void dispose() {
    _catatan.dispose();
    super.dispose();
  }

  Future<void> _simpan() async {
    final userId = ref.read(currentUserProvider)?.id;
    if (userId == null) return;

    setState(() => _menyimpan = true);
    try {
      await ref.read(attendanceRepositoryProvider).simpan(
            userId: userId,
            courseId: widget.courseId,
            meetingDate: _tanggal,
            status: _status,
            note: _catatan.text,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _menyimpan = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Gagal menyimpan: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.nama,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: AppSpacing.md),

          OutlinedButton.icon(
            onPressed: () async {
              final pilihan = await showDatePicker(
                context: context,
                initialDate: _tanggal,
                firstDate: DateTime(DateTime.now().year - 1),
                lastDate: DateTime(DateTime.now().year + 1, 12, 31),
              );
              if (pilihan != null) setState(() => _tanggal = pilihan);
            },
            icon: const Icon(Icons.calendar_today_outlined, size: 18),
            label: Text(_tanggalPanjang.format(_tanggal)),
          ),
          const SizedBox(height: AppSpacing.md),

          SegmentedButton<StatusKehadiran>(
            segments: [
              for (final s in StatusKehadiran.values)
                ButtonSegment(value: s, label: Text(s.label)),
            ],
            selected: {_status},
            onSelectionChanged: (v) => setState(() => _status = v.first),
            showSelectedIcon: false,
          ),
          const SizedBox(height: AppSpacing.md),

          TextField(
            controller: _catatan,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Catatan',
              hintText: 'Materi yang dibahas, alasan tidak masuk, titipan teman',
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          FilledButton(
            onPressed: _menyimpan ? null : _simpan,
            child: Text(_menyimpan ? 'Menyimpan...' : 'Simpan'),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Mencatat tanggal yang sama berarti mengoreksi catatan sebelumnya, '
            'bukan menambah pertemuan kedua.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Form atur jumlah pertemuan dan batas absen satu mata kuliah.
class _FormPertemuanSemester extends ConsumerStatefulWidget {
  const _FormPertemuanSemester({required this.rekap, required this.nama});

  final RekapKehadiran rekap;
  final String nama;

  @override
  ConsumerState<_FormPertemuanSemester> createState() => _FormPertemuanSemesterState();
}

class _FormPertemuanSemesterState extends ConsumerState<_FormPertemuanSemester> {
  late final _total = TextEditingController(
    text: widget.rekap.totalPertemuan?.toString() ?? '',
  );
  late final _persen = TextEditingController(
    text: widget.rekap.maksAbsenPersen?.toString() ?? '',
  );
  bool _menyimpan = false;

  @override
  void dispose() {
    _total.dispose();
    _persen.dispose();
    super.dispose();
  }

  Future<void> _simpan() async {
    setState(() => _menyimpan = true);
    try {
      await ref.read(academicRepositoryProvider).setCourseAbsensi(
            id: widget.rekap.courseId,
            totalMeetings: int.tryParse(_total.text.trim()),
            maxAbsencePercent: int.tryParse(_persen.text.trim()),
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _menyimpan = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Gagal menyimpan: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.nama, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _total,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Jumlah pertemuan satu semester',
              hintText: 'Biasanya 14 atau 16',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _persen,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Batas tidak hadir (%)',
              hintText: 'Kosongkan untuk memakai $kMaksAbsenPersenBawaan%',
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: _menyimpan ? null : _simpan,
            child: Text(_menyimpan ? 'Menyimpan...' : 'Simpan'),
          ),
        ],
      ),
    );
  }
}
