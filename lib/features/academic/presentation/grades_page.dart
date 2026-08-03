import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/hero_header.dart';
import '../../../core/widgets/section_header.dart';
import '../data/academic_repository.dart';
import '../domain/grade.dart';
import 'academic_providers.dart';
import 'grade_providers.dart';

const _color = AppColors.academic;

String _ip(double? nilai) => nilai == null ? '—' : nilai.toStringAsFixed(2);

class GradesPage extends ConsumerWidget {
  const GradesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gradesAsync = ref.watch(courseGradesProvider);
    final scale = ref.watch(gradeScaleProvider);
    final ipk = ref.watch(ipkProvider).value;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(coursesProvider);
          ref.invalidate(gradeComponentsProvider);
        },
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            HeroHeader.sub(
              title: 'Nilai & IPK',
              subtitle: 'Dihitung dari komponen yang sudah keluar',
              color: _color,
              leading: HeroIconButton(
                icon: Icons.arrow_back,
                tooltip: 'Kembali',
                onPressed: () => context.pop(),
              ),
              trailing: HeroIconButton(
                icon: Icons.document_scanner_outlined,
                tooltip: 'Import dari foto KHS',
                onPressed: () => context.push('/academic/schedule/grades/import'),
              ),
              stats: [
                HeroStatData(
                  icon: Icons.workspace_premium_outlined,
                  value: _ip(ipk?.ip),
                  label: 'IPK',
                ),
                HeroStatData(
                  icon: Icons.confirmation_number_outlined,
                  value: '${ipk?.sksDinilai ?? 0}',
                  label: 'SKS Dinilai',
                ),
                HeroStatData(
                  icon: Icons.menu_book_outlined,
                  value: '${ipk?.matkulTotal ?? 0}',
                  label: 'Mata Kuliah',
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 48),
              child: gradesAsync.when(
                data: (courses) => courses.isEmpty
                    ? const EmptyState(
                        icon: Icons.workspace_premium_outlined,
                        title: 'Belum ada mata kuliah',
                        subtitle: 'Tambahkan jadwal kuliah dulu — mata kuliahnya '
                            'otomatis muncul di sini untuk diberi sks dan nilai.',
                        color: _color,
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _SkalaPicker(scale: scale),
                          if (ipk != null && ipk.sebagian) ...[
                            const SizedBox(height: AppSpacing.sm),
                            _CatatanSebagian(summary: ipk),
                          ],
                          const SizedBox(height: AppSpacing.md),
                          for (final entry in groupBySemester(courses).entries) ...[
                            _SemesterHeader(
                              nama: entry.key,
                              summary: summarizeGrades(entry.value, scale),
                            ),
                            for (final course in entry.value)
                              Padding(
                                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                                child: _CourseTile(course: course, scale: scale),
                              ),
                            const SizedBox(height: AppSpacing.md),
                          ],
                        ],
                      ),
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, _) => EmptyState(
                  icon: Icons.error_outline,
                  title: 'Gagal memuat nilai',
                  subtitle: '$error',
                  color: _color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkalaPicker extends ConsumerWidget {
  const _SkalaPicker({required this.scale});

  final GradeScale scale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Skala huruf kampusmu',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(height: AppSpacing.sm),
            SegmentedButton<GradeScale>(
              segments: [
                for (final pilihan in GradeScale.values)
                  ButtonSegment(
                    value: pilihan,
                    label: Text(pilihan.label, style: const TextStyle(fontSize: 12)),
                  ),
              ],
              selected: {scale},
              showSelectedIcon: false,
              onSelectionChanged: (value) =>
                  ref.read(gradeScaleProvider.notifier).set(value.first),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Ambang hurufnya mengikuti yang paling umum dipakai, bukan aturan '
              'resmi tiap kampus. Kalau kampusmu berbeda, angka skornya tetap '
              'benar — yang bergeser cuma hurufnya.',
              style: TextStyle(fontSize: 12, height: 1.4, color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _CatatanSebagian extends StatelessWidget {
  const _CatatanSebagian({required this.summary});

  final GradeSummary summary;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final belum = summary.matkulTotal - summary.matkulDinilai;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 16, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'IPK ini dihitung dari ${summary.matkulDinilai} mata kuliah. '
              '$belum lainnya belum punya sks atau belum ada nilainya, jadi '
              'belum ikut terhitung.',
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SemesterHeader extends StatelessWidget {
  const _SemesterHeader({required this.nama, required this.summary});

  final String nama;
  final GradeSummary summary;

  @override
  Widget build(BuildContext context) {
    return SectionHeader(
      title: nama,
      icon: Icons.calendar_month_outlined,
      color: _color,
      trailing: Text(
        summary.ip == null
            ? '${summary.sksTotal} sks'
            : 'IPS ${_ip(summary.ip)}  ·  ${summary.sksDinilai} sks',
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: _color),
      ),
    );
  }
}

class _CourseTile extends ConsumerWidget {
  const _CourseTile({required this.course, required this.scale});

  final CourseGrade course;
  final GradeScale scale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final huruf = course.huruf(scale);
    final skor = course.skor;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          final berubah = await showModalBottomSheet<bool>(
            context: context,
            isScrollControlled: true,
            builder: (context) => _CourseGradeSheet(course: course, scale: scale),
          );
          if (berubah == true) {
            ref.invalidate(coursesProvider);
            ref.invalidate(gradeComponentsProvider);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: (huruf == null ? colorScheme.onSurfaceVariant : _color)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  huruf?.huruf ?? '–',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: huruf == null ? colorScheme.onSurfaceVariant : _color,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      course.courseName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        course.sks == null ? 'sks belum diisi' : '${course.sks} sks',
                        // Kalau nilainya resmi dari KHS, skor komponen cuma
                        // perkiraan lama yang sudah tidak menentukan apa pun.
                        if (course.resmi)
                          'Nilai akhir dari KHS'
                        else ...[
                          if (skor != null) 'Skor ${skor.toStringAsFixed(1)}',
                          if (course.components.isEmpty)
                            'Belum ada komponen'
                          else if (!course.lengkap)
                            'Sementara · ${(course.porsiTerisi * 100).round()}% penilaian',
                        ],
                      ].join('  ·  '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                    ),
                    if (course.bobotJanggal) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Bobot komponen berjumlah ${course.totalBobot.toStringAsFixed(0)}%, '
                        'bukan 100%',
                        style: TextStyle(fontSize: 12, color: colorScheme.error),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _CourseGradeSheet extends ConsumerStatefulWidget {
  const _CourseGradeSheet({required this.course, required this.scale});

  final CourseGrade course;
  final GradeScale scale;

  @override
  ConsumerState<_CourseGradeSheet> createState() => _CourseGradeSheetState();
}

class _CourseGradeSheetState extends ConsumerState<_CourseGradeSheet> {
  late final TextEditingController _sksController;
  late final TextEditingController _semesterController;
  bool _berubah = false;

  @override
  void initState() {
    super.initState();
    _sksController = TextEditingController(text: widget.course.sks?.toString() ?? '');
    _semesterController = TextEditingController(text: widget.course.semester ?? '');
  }

  @override
  void dispose() {
    _sksController.dispose();
    _semesterController.dispose();
    super.dispose();
  }

  Future<void> _simpanMatkul() async {
    final sks = int.tryParse(_sksController.text.trim());
    final semester = _semesterController.text.trim();

    await ref.read(academicRepositoryProvider).updateCourseAkademik(
          id: widget.course.courseId,
          sks: sks,
          semester: semester.isEmpty ? null : semester,
        );
    _berubah = true;
  }

  Future<void> _setHuruf(String? huruf) async {
    await ref
        .read(academicRepositoryProvider)
        .setCourseFinalLetter(widget.course.courseId, huruf);
    _berubah = true;
    ref.invalidate(coursesProvider);
  }

  Future<void> _komponenSheet({GradeComponent? komponen}) async {
    final hasil = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _ComponentSheet(
        courseId: widget.course.courseId,
        komponen: komponen,
      ),
    );

    // Sheet ini sengaja tidak ikut ditutup: daftar komponennya diambil dari
    // provider yang diawasi, jadi cukup disegarkan. Menutupnya akan membuang
    // sks dan semester yang sudah diketik tapi belum ditekan Simpan.
    if (hasil == true) {
      _berubah = true;
      ref.invalidate(gradeComponentsProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Versi terbaru dari provider, supaya komponen yang baru ditambah langsung
    // terlihat. Kembali ke snapshot awal kalau mata kuliahnya sudah tidak ada.
    final daftar = ref.watch(courseGradesProvider).value;
    final course = daftar?.where((c) => c.courseId == widget.course.courseId).firstOrNull ??
        widget.course;

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        top: AppSpacing.md,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.md,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              course.courseName,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _sksController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'SKS',
                      prefixIcon: Icon(Icons.confirmation_number_outlined),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _semesterController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Semester',
                      hintText: '2026/2027 Ganjil',
                      prefixIcon: Icon(Icons.calendar_month_outlined),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            const Text(
              'Nilai akhir (dari KHS)',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final huruf in semuaHuruf)
                  ChoiceChip(
                    label: Text(huruf),
                    selected: course.finalLetter == huruf,
                    // Menekan huruf yang sudah terpilih akan melepasnya —
                    // hitungannya kembali ke komponen.
                    onSelected: (pilih) => _setHuruf(pilih ? huruf : null),
                    selectedColor: _color.withValues(alpha: 0.18),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: course.finalLetter == huruf
                          ? _color
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              course.resmi
                  ? 'Huruf ini yang dipakai menghitung IPK. Komponen di bawah '
                      'jadi catatan saja.'
                  : 'Kosongkan kalau nilainya belum keluar — IPK akan memakai '
                      'hitungan dari komponen di bawah.',
              style: TextStyle(fontSize: 12, height: 1.4, color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Komponen penilaian',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _komponenSheet(),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Tambah'),
                ),
              ],
            ),
            if (course.components.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Text(
                  'Misalnya Tugas 20%, UTS 30%, UAS 50%. Komponen yang belum '
                  'keluar nilainya biarkan kosong — dia tidak akan dihitung nol.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              for (final komponen in course.components)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(komponen.name, style: const TextStyle(fontSize: 14)),
                  subtitle: Text(
                    '${komponen.weight.toStringAsFixed(0)}%',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        komponen.score?.toStringAsFixed(1) ?? 'belum',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: komponen.dinilai ? _color : colorScheme.onSurfaceVariant,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20),
                        tooltip: 'Hapus komponen',
                        onPressed: () async {
                          await ref
                              .read(academicRepositoryProvider)
                              .deleteGradeComponent(komponen.id);
                          _berubah = true;
                          ref.invalidate(gradeComponentsProvider);
                        },
                      ),
                    ],
                  ),
                  onTap: () => _komponenSheet(komponen: komponen),
                ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: () async {
                await _simpanMatkul();
                if (context.mounted) Navigator.pop(context, _berubah);
              },
              style: FilledButton.styleFrom(
                backgroundColor: _color,
                minimumSize: const Size.fromHeight(48),
              ),
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComponentSheet extends ConsumerStatefulWidget {
  const _ComponentSheet({required this.courseId, this.komponen});

  final String courseId;
  final GradeComponent? komponen;

  @override
  ConsumerState<_ComponentSheet> createState() => _ComponentSheetState();
}

class _ComponentSheetState extends ConsumerState<_ComponentSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _weightController;
  late final TextEditingController _scoreController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final komponen = widget.komponen;
    _nameController = TextEditingController(text: komponen?.name ?? '');
    _weightController =
        TextEditingController(text: komponen?.weight.toStringAsFixed(0) ?? '');
    _scoreController = TextEditingController(
      text: komponen?.score == null ? '' : komponen!.score!.toStringAsFixed(1),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _weightController.dispose();
    _scoreController.dispose();
    super.dispose();
  }

  double? _angka(String teks) => double.tryParse(teks.trim().replaceAll(',', '.'));

  Future<void> _simpan() async {
    if (!_formKey.currentState!.validate()) return;

    final userId = ref.read(currentUserProvider)?.id;
    if (userId == null) return;

    setState(() => _saving = true);
    try {
      await ref.read(academicRepositoryProvider).saveGradeComponent(
            userId: userId,
            id: widget.komponen?.id,
            courseId: widget.courseId,
            name: _nameController.text.trim(),
            weight: _angka(_weightController.text)!,
            // Kosong berarti belum keluar nilainya, dan itu disimpan sebagai
            // null — bukan nol.
            score: _angka(_scoreController.text),
          );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        top: AppSpacing.md,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.md,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.komponen == null ? 'Komponen Baru' : 'Edit Komponen',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _nameController,
              autofocus: widget.komponen == null,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nama komponen',
                hintText: 'Misal: UTS',
                prefixIcon: Icon(Icons.label_outline),
              ),
              validator: (value) =>
                  (value == null || value.trim().isEmpty) ? 'Wajib diisi' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _weightController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Bobot (%)',
                prefixIcon: Icon(Icons.percent),
              ),
              validator: (value) {
                final angka = _angka(value ?? '');
                if (angka == null) return 'Isi angka';
                if (angka <= 0 || angka > 100) return 'Antara 1 dan 100';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _scoreController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Nilai (0–100)',
                hintText: 'Kosongkan kalau belum keluar',
                prefixIcon: Icon(Icons.grade_outlined),
              ),
              validator: (value) {
                final teks = (value ?? '').trim();
                if (teks.isEmpty) return null;
                final angka = _angka(teks);
                if (angka == null) return 'Isi angka';
                if (angka < 0 || angka > 100) return 'Antara 0 dan 100';
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: _saving ? null : _simpan,
              style: FilledButton.styleFrom(
                backgroundColor: _color,
                minimumSize: const Size.fromHeight(48),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }
}
