import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/hero_header.dart';
import '../../../core/widgets/section_header.dart';
import '../../workout/data/models/exercise_entry.dart';
import '../../workout/data/workout_repository.dart';
import '../../workout/presentation/workout_providers.dart';
import '../data/program_repository.dart';
import '../domain/bulk_program.dart';
import '../domain/pose_gerakan.dart';
import 'diagram_gerakan.dart';

const _color = AppColors.workout;

/// Program latihan untuk menaikkan berat badan.
///
/// Halaman ini menolak menjadi satu-satunya jawaban atas "gimana caranya naik
/// berat badan". Yang menaikkan berat badan itu surplus kalori; latihan yang
/// menentukan apakah tambahannya jadi otot atau lemak. Karena itu kalimat
/// pertama di halaman ini soal makan, bukan soal set dan rep — dan dia menunjuk
/// ke Kalkulator Kalori yang memang sudah menghitung angkanya.
class BulkProgramPage extends ConsumerStatefulWidget {
  const BulkProgramPage({super.key});

  @override
  ConsumerState<BulkProgramPage> createState() => _BulkProgramPageState();
}

class _BulkProgramPageState extends ConsumerState<BulkProgramPage> {
  /// Variasi yang sedang dilihat. Awalnya mengikuti yang tersimpan; sebelum
  /// memilih apa pun, versi tanpa kursi yang ditampilkan karena dia yang paling
  /// sedikit syaratnya.
  VariasiAlat? _lihat;
  bool _sibuk = false;

  @override
  Widget build(BuildContext context) {
    final aktifAsync = ref.watch(programAktifProvider);
    final aktif = aktifAsync.value;
    final variasi = _lihat ?? aktif?.variasi ?? VariasiAlat.tanpaKursi;
    final program = programNaikBerat(variasi);
    final dipakai = aktif?.variasi == variasi;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(programAktifProvider);
          ref.invalidate(workoutTemplatesProvider);
        },
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            HeroHeader.sub(
              title: 'Program Naik Berat',
              subtitle: aktif == null
                  ? 'Latihan di kos, 3× seminggu'
                  : 'Minggu ke-${mingguKe(aktif.mulai, DateTime.now())}  ·  '
                      '${aktif.variasi.label}',
              color: _color,
              leading: HeroIconButton(
                icon: Icons.arrow_back,
                tooltip: 'Kembali',
                onPressed: () => context.pop(),
              ),
              stats: [
                const HeroStatData(
                  icon: Icons.calendar_view_week_outlined,
                  value: '$kSesiPerMinggu×',
                  label: 'Per Minggu',
                ),
                HeroStatData(
                  icon: Icons.timelapse,
                  value: '${program.sesi.first.perkiraanMenit}m',
                  label: 'Per Sesi',
                ),
                HeroStatData(
                  icon: Icons.fitness_center,
                  value: '${program.sesi.first.gerakan.length}',
                  label: 'Gerakan',
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _CatatanKalori(),
                  const SizedBox(height: AppSpacing.lg),

                  const SectionHeader(
                    title: 'Alat yang kamu punya',
                    icon: Icons.chair_outlined,
                    color: _color,
                  ),
                  _PemilihVariasi(
                    terpilih: variasi,
                    dipakai: aktif?.variasi,
                    onPilih: (pilihan) => setState(() => _lihat = pilihan),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  for (final sesi in program.sesi) ...[
                    _KartuSesi(sesi: sesi),
                    const SizedBox(height: AppSpacing.md),
                  ],

                  const SizedBox(height: AppSpacing.xs),
                  const _CatatanProgresi(),
                  const SizedBox(height: AppSpacing.lg),

                  FilledButton.icon(
                    onPressed: _sibuk ? null : () => _pakai(variasi, aktif),
                    style: FilledButton.styleFrom(
                      backgroundColor: _color,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: Icon(dipakai ? Icons.check : Icons.playlist_add_check),
                    label: Text(
                      _sibuk
                          ? 'Menyiapkan...'
                          : dipakai
                              ? 'Buat ulang templatenya'
                              : 'Pakai program ini',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Kedua sesi disimpan sebagai template workout, jadi bisa '
                    'langsung dijalankan lewat Latihan Terpandu atau dicatat '
                    'ulang dari Riwayat.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.4,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),

                  if (aktif != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    TextButton(
                      onPressed: _sibuk ? null : _berhenti,
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      child: const Text('Berhenti mengikuti program'),
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

  Future<void> _pakai(VariasiAlat variasi, ProgramAktif? aktif) async {
    final userId = ref.read(currentUserProvider)?.id;
    if (userId == null) return;

    setState(() => _sibuk = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(programRepositoryProvider).pilih(
            userId: userId,
            variasi: variasi,
            pertamaKali: aktif == null,
          );

      final dibuat = await pasangTemplate(
        repo: ref.read(workoutRepositoryProvider),
        userId: userId,
        program: programNaikBerat(variasi),
        sudahAda: await ref.read(workoutTemplatesProvider.future),
      );

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            dibuat == 0
                ? 'Program dipakai. Templatenya memang sudah ada, jadi tidak dibuat ulang.'
                : 'Program dipakai. $dibuat template ditambahkan ke Workout.',
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Gagal menyimpan: $e')));
    } finally {
      if (mounted) setState(() => _sibuk = false);
    }
    ref.invalidate(programAktifProvider);
    ref.invalidate(workoutTemplatesProvider);
  }

  Future<void> _berhenti() async {
    final userId = ref.read(currentUserProvider)?.id;
    if (userId == null) return;

    final yakin = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Berhenti mengikuti?'),
        content: const Text(
          'Template yang sudah dibuat tetap ada di Workout, begitu juga sesi '
          'yang sudah kamu catat. Yang dilepas cuma penandanya di halaman ini.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Berhenti')),
        ],
      ),
    );
    if (yakin != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(programRepositoryProvider).berhenti(userId);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Gagal: $e')));
      return;
    }
    ref.invalidate(programAktifProvider);
  }
}

/// Yang menaikkan berat badan itu makanan, bukan latihan.
class _CatatanKalori extends StatelessWidget {
  const _CatatanKalori();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/workout/calories'),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.restaurant_menu, size: 18, color: _color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Yang menaikkan berat badan itu makan, bukan latihan',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tanpa surplus kalori, program sebagus apa pun tidak akan '
                      'menaikkan angka timbangan. Latihan menentukan tambahannya '
                      'jadi otot atau lemak — itu bagiannya, dan itu saja.\n\n'
                      'Buka Kalkulator Kalori untuk angka target harianmu.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.45,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 18, color: colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _CatatanProgresi extends StatelessWidget {
  const _CatatanProgresi();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.trending_up, size: 18, color: _color),
                SizedBox(width: 8),
                Text(
                  'Cara naik levelnya',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Urutannya A – B – A minggu ini, B – A – B minggu depan. Tiap '
              'gerakan kena sekitar 1,5 kali seminggu: cukup sering untuk '
              'tumbuh, cukup jarang untuk pulih.\n\n'
              'Kalau semua set tercapai dengan rapi, naikkan sedikit minggu '
              'berikutnya — beban untuk gerakan dumbbell, repetisi untuk '
              'gerakan bodyweight. App sudah menghitung sarannya sendiri begitu '
              'kamu mencatat sesi, jadi angkanya tidak perlu kamu ingat.\n\n'
              'Kalau satu gerakan mandek tiga minggu berturut-turut, biasanya '
              'yang kurang bukan latihannya — tapi makan dan tidurnya.',
              style: TextStyle(
                fontSize: 12,
                height: 1.45,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PemilihVariasi extends StatelessWidget {
  const _PemilihVariasi({
    required this.terpilih,
    required this.dipakai,
    required this.onPilih,
  });

  final VariasiAlat terpilih;
  final VariasiAlat? dipakai;
  final ValueChanged<VariasiAlat> onPilih;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        for (final variasi in VariasiAlat.values) ...[
          if (variasi != VariasiAlat.values.first) const SizedBox(height: AppSpacing.sm),
          InkWell(
            onTap: () => onPilih(variasi),
            borderRadius: BorderRadius.circular(AppTheme.radius),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: terpilih == variasi
                    ? _color.withValues(alpha: 0.10)
                    : colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(AppTheme.radius),
                border: Border.all(
                  color: terpilih == variasi ? _color : colorScheme.outlineVariant,
                  width: terpilih == variasi ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    terpilih == variasi
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    size: 18,
                    color: terpilih == variasi ? _color : colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                variasi.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            if (dipakai == variasi) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: _color.withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text(
                                  'Dipakai',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: _color,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          variasi.keterangan,
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Satu sesi beserta gerakannya. Publik supaya tata letaknya bisa digambar
/// langsung di test tampilan tanpa menghidupkan seluruh halaman.
class KartuSesiProgram extends StatelessWidget {
  const KartuSesiProgram({super.key, required this.sesi});

  final SesiProgram sesi;

  @override
  Widget build(BuildContext context) => _KartuSesi(sesi: sesi);
}

class _KartuSesi extends StatelessWidget {
  const _KartuSesi({required this.sesi});

  final SesiProgram sesi;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

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
                    sesi.nama,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: _color,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Text(
                    sesi.fokus,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            Text(
              '${sesi.gerakan.length} gerakan  ·  sekitar ${sesi.perkiraanMenit} menit',
              style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.sm),
            Divider(height: 1, color: colorScheme.outlineVariant),
            for (final (i, gerakan) in sesi.gerakan.indexed) ...[
              if (i > 0) Divider(height: 1, color: colorScheme.outlineVariant),
              _BarisGerakan(gerakan: gerakan),
            ],
          ],
        ),
      ),
    );
  }
}

class _BarisGerakan extends StatelessWidget {
  const _BarisGerakan({required this.gerakan});

  final GerakanProgram gerakan;

  IconData get _ikon => switch (gerakan.tipe) {
        ExerciseType.beban => Icons.fitness_center,
        ExerciseType.bodyweight => Icons.accessibility_new,
        ExerciseType.isometrik => Icons.hourglass_bottom,
        ExerciseType.cardio => Icons.directions_run,
      };

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final diagram = diagramGerakan(gerakan.nama);

    return InkWell(
      onTap: diagram == null ? null : () => bukaDetailGerakan(context, gerakan, diagram),
      child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Gambar pose akhir sebagai ikon. Kalau gerakannya belum digambar,
          // ikon tipe latihan yang dipakai — bukan gambar gerakan lain yang
          // mirip, karena gambar yang salah lebih menyesatkan daripada tidak
          // ada gambar.
          if (diagram != null)
            IkonGerakan(diagram: diagram, ukuran: 38)
          else
            SizedBox(
              width: 38,
              height: 38,
              child: Icon(_ikon, size: 16, color: colorScheme.onSurfaceVariant),
            ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Wrap, bukan Row: takaran seperti "3 x 30 detik / sisi"
                // tidak muat sebaris dengan namanya di layar 320dp saat huruf
                // diperbesar. Dengan Wrap dia turun utuh ke baris berikutnya —
                // dipotong elipsis berarti "/ sisi"-nya hilang, dan itu justru
                // bagian yang mengubah artinya.
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: AppSpacing.sm,
                  runSpacing: 2,
                  children: [
                    Text(
                      gerakan.nama,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    Text(
                      gerakan.takaran,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: _color,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  gerakan.cue,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.4,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  'Istirahat ${gerakan.istirahatLabel}',
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                  ),
                ),
                if (gerakan.ganti case final ganti?)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Terlalu berat? $ganti',
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.4,
                        fontStyle: FontStyle.italic,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (diagram != null)
            Icon(Icons.chevron_right, size: 16, color: colorScheme.onSurfaceVariant),
        ],
      ),
      ),
    );
  }
}

/// Gambar gerakan ukuran penuh beserta keterangannya.
///
/// Dibuka lewat ketukan, bukan ditampilkan langsung di daftar: enam gambar
/// sekaligus membuat satu kartu sesi jadi sepanjang tiga layar, dan yang kamu
/// perlukan saat membaca jadwal cuma nama beserta takarannya.
Future<void> bukaDetailGerakan(
  BuildContext context,
  GerakanProgram gerakan,
  DiagramGerakan diagram,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      final colorScheme = Theme.of(context).colorScheme;

      return Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.md,
          right: AppSpacing.md,
          bottom: MediaQuery.of(context).padding.bottom + AppSpacing.lg,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      gerakan.nama,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    gerakan.takaran,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: _color,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              GambarGerakan(diagram: diagram),
              const SizedBox(height: AppSpacing.md),

              Text(
                gerakan.cue,
                style: TextStyle(fontSize: 13, height: 1.5, color: colorScheme.onSurface),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Istirahat ${gerakan.istirahatLabel} antar set.',
                style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
              ),
              if (gerakan.ganti case final ganti?) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Terlalu berat? $ganti',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.45,
                    fontStyle: FontStyle.italic,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),

              // Gambarnya skematik: dia menunjukkan bentuk badan, bukan
              // kecepatan, napas, atau sudut yang tepat. Untuk itu video tetap
              // lebih jujur, dan tautannya berupa pencarian — bukan satu video
              // tetap yang bisa dihapus pemiliknya kapan saja.
              OutlinedButton.icon(
                onPressed: () => _bukaVideo(gerakan.nama),
                icon: const Icon(Icons.play_circle_outline, size: 18),
                label: const Text('Cari video gerakannya'),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<void> _bukaVideo(String nama) async {
  final url = Uri.parse(
    'https://www.youtube.com/results?search_query='
    '${Uri.encodeQueryComponent("cara $nama yang benar")}',
  );
  await launchUrl(url, mode: LaunchMode.externalApplication);
}
