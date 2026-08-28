import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/hero_header.dart';
import '../../academic/data/models/class_schedule.dart';
import '../../academic/presentation/academic_providers.dart';
import '../data/routine_repository.dart';
import '../domain/routine.dart';
import 'routine_form_sheet.dart';

const _color = AppColors.dashboard;

/// Nama pendek untuk pemilih hari, supaya tujuh-tujuhnya muat sebaris.
const _hariPendek = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

IconData ikonKategori(KategoriRutinitas? kategori) => switch (kategori) {
      null => Icons.school_outlined,
      KategoriRutinitas.bangun => Icons.wb_twilight,
      KategoriRutinitas.makan => Icons.restaurant,
      KategoriRutinitas.kerja => Icons.work_outline,
      KategoriRutinitas.workout => Icons.fitness_center,
      KategoriRutinitas.ibadah => Icons.mosque_outlined,
      KategoriRutinitas.santai => Icons.weekend_outlined,
      KategoriRutinitas.tidur => Icons.bedtime_outlined,
      KategoriRutinitas.lainnya => Icons.label_outline,
    };

/// Rutinitas harian: jadwal pribadi yang berulang tiap minggu.
///
/// Kelas dari Jadwal Kuliah ikut ditampilkan supaya satu hari bisa dibaca utuh
/// dari bangun sampai tidur — tapi tidak disalin ke sini. Baris kelas datang
/// dari KRS dan tidak bisa diubah dari halaman ini; kalau disalin, dua
/// salinannya mulai berbeda begitu jadwal kuliahnya berubah.
class RoutinePage extends ConsumerStatefulWidget {
  const RoutinePage({super.key});

  @override
  ConsumerState<RoutinePage> createState() => _RoutinePageState();
}

class _RoutinePageState extends ConsumerState<RoutinePage> {
  int _hari = DateTime.now().weekday;

  @override
  Widget build(BuildContext context) {
    final rutinitasAsync = ref.watch(routinesProvider);
    final rutinitas = rutinitasAsync.value ?? const <RoutineItem>[];
    final jadwal = ref.watch(classSchedulesProvider).value ?? const <ClassSchedule>[];

    final baris = lineMasaHarian(hari: _hari, rutinitas: rutinitas, jadwal: jadwal);
    final terisi = hariTerisi(rutinitas);
    final punyaKelas = baris.where((b) => b.dariKuliah).length;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _bukaForm(),
        backgroundColor: _color,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Kegiatan'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(routinesProvider);
          ref.invalidate(classSchedulesProvider);
        },
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            HeroHeader.sub(
              title: 'Rutinitas',
              subtitle: 'Jadwal harianmu di luar kuliah',
              color: _color,
              leading: HeroIconButton(
                icon: Icons.arrow_back,
                tooltip: 'Kembali',
                onPressed: () => context.pop(),
              ),
              trailing: HeroIconButton(
                icon: Icons.copy_all_outlined,
                tooltip: 'Salin dari hari lain',
                onPressed: () => _salinDariHariLain(rutinitas),
              ),
              stats: [
                HeroStatData(
                  icon: Icons.list_alt_outlined,
                  value: '${baris.length}',
                  label: 'Kegiatan',
                ),
                HeroStatData(
                  icon: Icons.timelapse,
                  value: labelDurasi(menitTerisi(baris)),
                  label: 'Terisi',
                ),
                HeroStatData(
                  icon: Icons.calendar_view_week_outlined,
                  value: '${terisi.length}',
                  label: 'Hari Diisi',
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (var hari = 1; hari <= 7; hari++) ...[
                      if (hari > 1) const SizedBox(width: AppSpacing.sm),
                      _ChipHari(
                        hari: hari,
                        terpilih: _hari == hari,
                        // Titik kecil untuk hari yang sudah punya isi, supaya
                        // kamu tahu mana yang belum disusun tanpa membukanya
                        // satu per satu.
                        berisi: terisi.contains(hari),
                        onTap: () => setState(() => _hari = hari),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, 96),
              child: rutinitasAsync.when(
                data: (_) => baris.isEmpty
                    ? EmptyState(
                        icon: Icons.schedule_outlined,
                        title: '${weekDayName(_hari)} masih kosong',
                        subtitle: 'Tekan + untuk menambah kegiatan, atau salin '
                            'susunan dari hari lain lewat tombol di atas',
                        color: _color,
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final item in baris)
                            Padding(
                              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                              child: BarisRutinitas(
                                baris: item,
                                onTap: item.dariKuliah
                                    ? null
                                    : () => _bukaForm(_cari(rutinitas, item.routineId!)),
                              ),
                            ),
                          if (punyaKelas > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: AppSpacing.xs),
                              child: Text(
                                '$punyaKelas kelas diambil dari Jadwal Kuliah dan '
                                'tidak bisa diubah dari sini. Kelas pengganti (PHL) '
                                'tidak ikut, karena dia terjadi sekali, bukan tiap minggu.',
                                style: TextStyle(
                                  fontSize: 11,
                                  height: 1.4,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                        ],
                      ),
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, stackTrace) => EmptyState(
                  icon: Icons.error_outline,
                  title: 'Gagal memuat rutinitas',
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

  RoutineItem? _cari(List<RoutineItem> rutinitas, String id) {
    for (final item in rutinitas) {
      if (item.id == id) return item;
    }
    return null;
  }

  Future<void> _bukaForm([RoutineItem? awal]) async {
    final hasil = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => RoutineFormSheet(hari: _hari, awal: awal),
    );
    if (hasil == true) ref.invalidate(routinesProvider);
  }

  Future<void> _salinDariHariLain(List<RoutineItem> rutinitas) async {
    final terisi = hariTerisi(rutinitas)..remove(_hari);
    if (terisi.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Belum ada hari lain yang bisa disalin')),
      );
      return;
    }

    final asal = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('Salin ke ${weekDayName(_hari)} dari'),
        children: [
          for (final hari in terisi.toList()..sort())
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, hari),
              child: Text(
                '${weekDayName(hari)}  ·  '
                '${rutinitas.where((r) => r.dayOfWeek == hari).length} kegiatan',
              ),
            ),
        ],
      ),
    );
    if (asal == null || !mounted) return;

    final item = [
      for (final r in rutinitas)
        if (r.dayOfWeek == asal) r,
    ];
    final sudahAda = rutinitas.where((r) => r.dayOfWeek == _hari).length;

    final yakin = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Salin kegiatan?'),
        content: Text(
          '${item.length} kegiatan dari ${weekDayName(asal)} akan '
          'ditambahkan ke ${weekDayName(_hari)}.'
          '${sudahAda > 0 ? '\n\n${weekDayName(_hari)} sudah punya $sudahAda kegiatan, '
              'dan itu tidak dihapus — kalau ada yang kembar, hapus sendiri setelahnya.' : ''}',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Salin')),
        ],
      ),
    );
    if (yakin != true || !mounted) return;

    final userId = ref.read(currentUserProvider)?.id;
    if (userId == null) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      final jumlah = await ref
          .read(routineRepositoryProvider)
          .salinKeHari(userId: userId, item: item, keHari: _hari);
      messenger.showSnackBar(
        SnackBar(content: Text('$jumlah kegiatan disalin ke ${weekDayName(_hari)}')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Gagal menyalin: $e')));
      return;
    }
    ref.invalidate(routinesProvider);
  }
}

class _ChipHari extends StatelessWidget {
  const _ChipHari({
    required this.hari,
    required this.terpilih,
    required this.berisi,
    required this.onTap,
  });

  final int hari;
  final bool terpilih;
  final bool berisi;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final iniHariIni = hari == DateTime.now().weekday;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: terpilih ? _color.withValues(alpha: 0.16) : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: terpilih ? _color : colorScheme.outlineVariant,
            width: terpilih ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _hariPendek[hari - 1],
              style: TextStyle(
                fontSize: 13,
                fontWeight: iniHariIni || terpilih ? FontWeight.w800 : FontWeight.w600,
                color: terpilih ? _color : colorScheme.onSurfaceVariant,
              ),
            ),
            if (berisi) ...[
              const SizedBox(width: 5),
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: terpilih ? _color : colorScheme.onSurfaceVariant,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Satu baris lini masa. Publik supaya tata letaknya bisa digambar langsung di
/// test tampilan tanpa menghidupkan seluruh halaman.
class BarisRutinitas extends StatelessWidget {
  const BarisRutinitas({super.key, required this.baris, this.onTap});

  final BarisHarian baris;

  /// Null untuk baris kelas — sumbernya Jadwal Kuliah, bukan halaman ini.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Warna cuma untuk dua hal yang memang perlu dibedakan: kelas yang datang
    // dari tempat lain, dan workout yang juga kamu catat di tempat lain.
    // Sisanya netral, supaya lini masanya tidak berubah jadi pelangi.
    final warna = switch (baris.kategori) {
      null => AppColors.academic,
      KategoriRutinitas.workout => AppColors.workout,
      _ => colorScheme.onSurfaceVariant,
    };
    final durasi = baris.durasiMenit;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm + 2,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 44,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      baris.mulai,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        height: 1.2,
                        color: baris.dariKuliah ? AppColors.academic : colorScheme.onSurface,
                      ),
                    ),
                    if (baris.selesai case final akhir?)
                      Text(
                        akhir,
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.2,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                width: 3,
                height: 34,
                margin: const EdgeInsets.only(right: AppSpacing.sm + 4),
                decoration: BoxDecoration(
                  color: warna.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Icon(ikonKategori(baris.kategori), size: 16, color: warna),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      baris.judul,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    if (baris.keterangan case final teks?)
                      Text(
                        teks,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                      ),
                  ],
                ),
              ),
              if (baris.dariKuliah)
                Icon(Icons.lock_outline, size: 14, color: colorScheme.onSurfaceVariant)
              else if (durasi != null) ...[
                const SizedBox(width: AppSpacing.xs),
                Text(
                  labelDurasi(durasi),
                  style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
