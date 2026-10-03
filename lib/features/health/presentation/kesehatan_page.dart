import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/hero_header.dart';
import '../../../core/widgets/section_header.dart';
import '../../sleep/data/sleep_repository.dart';
import '../data/health_connect.dart';
import '../domain/kesehatan.dart';

const _color = AppColors.workout;
final _angka = NumberFormat.decimalPattern('id_ID');
final _hari = DateFormat('E', 'id_ID');

/// Langkah, detak jantung, dan tidur dari jam atau gelang pintar lewat
/// Health Connect.
class KesehatanPage extends ConsumerStatefulWidget {
  const KesehatanPage({super.key});

  @override
  ConsumerState<KesehatanPage> createState() => _KesehatanPageState();
}

class _KesehatanPageState extends ConsumerState<KesehatanPage> {
  bool _sibuk = false;

  void _pesan(String teks) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(teks)));
  }

  Future<void> _sambungkan() async {
    setState(() => _sibuk = true);
    try {
      final ok = await ref.read(healthConnectProvider).mintaIzin();
      if (!ok) {
        _pesan('Izin langkah dan tidur belum diberikan.');
      } else {
        await _imporTidur(diam: true);
      }
    } catch (e) {
      _pesan('Gagal membuka Health Connect: $e');
    } finally {
      ref.invalidate(ringkasanKesehatanProvider);
      if (mounted) setState(() => _sibuk = false);
    }
  }

  Future<void> _imporTidur({bool diam = false}) async {
    final userId = ref.read(currentUserProvider)?.id;
    if (userId == null) return;
    try {
      final jumlah = await imporTidurHealthConnect(
        hc: ref.read(healthConnectProvider),
        repo: ref.read(sleepRepositoryProvider),
        userId: userId,
      );
      if (jumlah > 0) ref.invalidate(sleepLogsProvider);
      if (!diam || jumlah > 0) {
        _pesan(jumlah == 0 ? 'Tidak ada tidur baru.' : '$jumlah malam tidur diimpor');
      }
    } catch (e) {
      _pesan('Gagal mengimpor tidur: $e');
    }
  }

  Future<void> _putuskan() async {
    final yakin = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Putuskan Health Connect?'),
        content: const Text(
          'Izin membaca dicabut. Catatan tidur yang sudah diimpor tetap ada.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Putuskan')),
        ],
      ),
    );
    if (yakin != true) return;
    await ref.read(healthConnectProvider).putuskan();
    ref.invalidate(ringkasanKesehatanProvider);
  }

  @override
  Widget build(BuildContext context) {
    final ringkasan = ref.watch(ringkasanKesehatanProvider);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(ringkasanKesehatanProvider),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            HeroHeader.sub(
              title: 'Kesehatan',
              subtitle: 'Dari jam atau gelang pintar lewat Health Connect',
              color: _color,
              leading: HeroIconButton(
                icon: Icons.arrow_back,
                tooltip: 'Kembali',
                onPressed: () => context.pop(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: ringkasan.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(AppSpacing.xl),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Text('Gagal membaca Health Connect: $e'),
                data: (r) => switch (r.status) {
                  StatusHealthConnect.tidakDidukung => const _Info(
                      ikon: Icons.phone_android,
                      judul: 'Hanya di Android',
                      isi: 'Health Connect adalah layanan Android.',
                    ),
                  StatusHealthConnect.perluPasang => _Info(
                      ikon: Icons.download_outlined,
                      judul: 'Pasang Health Connect dulu',
                      isi: 'Di Android 13 ke bawah, Health Connect adalah app terpisah '
                          'dari Play Store. Setelah terpasang, sambungkan juga app jam '
                          'tanganmu (Mi Fitness, Galaxy Wearable, Fitbit, dll.) ke sana.',
                      tombol: 'Buka Play Store',
                      onTombol: () => ref.read(healthConnectProvider).pasang(),
                    ),
                  StatusHealthConnect.perluIzin => _Info(
                      ikon: Icons.favorite_outline,
                      judul: 'Sambungkan Health Connect',
                      isi: 'Langkah dan tidur dari jam tanganmu masuk otomatis — tidur '
                          'tidak perlu dicatat manual lagi. App ini hanya MEMBACA; '
                          'tidak ada yang ditulis balik ke Health Connect.',
                      tombol: _sibuk ? 'Menyambungkan...' : 'Sambungkan',
                      onTombol: _sibuk ? null : _sambungkan,
                    ),
                  StatusHealthConnect.siap => _Tersambung(
                      ringkasan: r,
                      onImpor: () => _imporTidur(),
                      onPutuskan: _putuskan,
                    ),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info({
    required this.ikon,
    required this.judul,
    required this.isi,
    this.tombol,
    this.onTombol,
  });

  final IconData ikon;
  final String judul;
  final String isi;
  final String? tombol;
  final VoidCallback? onTombol;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(ikon, size: 36, color: _color),
            const SizedBox(height: AppSpacing.md),
            Text(
              judul,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              isi,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, height: 1.45, color: colorScheme.onSurfaceVariant),
            ),
            if (tombol != null) ...[
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                onPressed: onTombol,
                style: FilledButton.styleFrom(
                  backgroundColor: _color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
                child: Text(tombol!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Tersambung extends StatelessWidget {
  const _Tersambung({required this.ringkasan, required this.onImpor, required this.onPutuskan});

  final RingkasanKesehatan ringkasan;
  final VoidCallback onImpor;
  final VoidCallback onPutuskan;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final rata = rataRataLangkah(ringkasan.langkah);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _Angka(
                label: 'Langkah hari ini',
                nilai: _angka.format(ringkasan.langkahHariIni ?? 0),
                ikon: Icons.directions_walk,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _Angka(
                label: 'Detak istirahat',
                nilai: ringkasan.detakIstirahat == null ? '–' : '${ringkasan.detakIstirahat} bpm',
                ikon: Icons.favorite_outline,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        const SectionHeader(title: '7 hari terakhir', icon: Icons.bar_chart, color: _color),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rata == null ? 'Belum ada langkah tercatat' : 'Rata-rata ${_angka.format(rata)} langkah',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                ),
                const SizedBox(height: AppSpacing.md),
                _GrafikLangkah(hari: ringkasan.langkah),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        const SectionHeader(title: 'Tidur', icon: Icons.bedtime_outlined, color: _color),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.sync, color: _color),
                title: const Text('Impor tidur sekarang', style: TextStyle(fontSize: 14)),
                subtitle: const Text(
                  'Otomatis tiap app dibuka. Catatan tidur yang kamu isi sendiri '
                  'tidak ditimpa.',
                  style: TextStyle(fontSize: 12),
                ),
                onTap: onImpor,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        TextButton(
          onPressed: onPutuskan,
          style: TextButton.styleFrom(foregroundColor: colorScheme.error),
          child: const Text('Putuskan Health Connect'),
        ),
      ],
    );
  }
}

class _Angka extends StatelessWidget {
  const _Angka({required this.label, required this.nilai, required this.ikon});

  final String label;
  final String nilai;
  final IconData ikon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(ikon, size: 20, color: _color),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(nilai, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            ),
            Text(label, style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _GrafikLangkah extends StatelessWidget {
  const _GrafikLangkah({required this.hari});

  final List<LangkahHarian> hari;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tertinggi = hari.fold<int>(0, (m, h) => h.langkah > m ? h.langkah : m);

    return SizedBox(
      height: 120,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final h in hari)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: FractionallySizedBox(
                          heightFactor: tertinggi == 0 ? 0.02 : (h.langkah / tertinggi).clamp(0.02, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              color: h == hari.last ? _color : _color.withValues(alpha: 0.45),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _hari.format(h.tanggal),
                      style: TextStyle(fontSize: 10.5, color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
