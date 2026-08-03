import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/hero_header.dart';
import '../data/vehicle_repository.dart';
import '../domain/vehicle.dart';

const _color = AppColors.vehicle;
final _tanggalFormat = DateFormat('d MMM y', 'id_ID');

class VehiclePage extends ConsumerWidget {
  const VehiclePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehiclesAsync = ref.watch(vehiclesProvider);
    final semuaPengingat = ref.watch(pengingatKendaraanProvider);
    final lewat = semuaPengingat.where((p) => p.pengingat.lewat).length;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => bukaFormKendaraan(context, ref),
        backgroundColor: _color,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Kendaraan'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(vehiclesProvider);
          ref.invalidate(vehicleServicesProvider);
        },
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            HeroHeader.sub(
              title: 'Kendaraan',
              subtitle: 'Servis dan pajak',
              color: _color,
              leading: HeroIconButton(
                icon: Icons.arrow_back,
                tooltip: 'Kembali',
                onPressed: () => context.pop(),
              ),
              stats: [
                HeroStatData(
                  icon: Icons.two_wheeler,
                  value: '${vehiclesAsync.value?.length ?? 0}',
                  label: 'Kendaraan',
                ),
                HeroStatData(
                  icon: Icons.warning_amber_rounded,
                  value: '$lewat',
                  label: 'Sudah Lewat',
                ),
                HeroStatData(
                  icon: Icons.schedule,
                  value: '${semuaPengingat.length - lewat}',
                  label: 'Segera',
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 96),
              child: vehiclesAsync.when(
                data: (items) => items.isEmpty
                    ? const EmptyState(
                        icon: Icons.two_wheeler,
                        title: 'Belum ada kendaraan',
                        subtitle: 'Catat motor atau mobilmu, lalu isi tanggal '
                            'pajak dari STNK. Setiap kali servis dicatat, '
                            'jadwal berikutnya dihitung sendiri.',
                        color: _color,
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final vehicle in items)
                            Padding(
                              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                              child: _KartuKendaraan(vehicle: vehicle),
                            ),
                        ],
                      ),
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, _) => EmptyState(
                  icon: Icons.error_outline,
                  title: 'Gagal memuat kendaraan',
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

class _KartuKendaraan extends ConsumerWidget {
  const _KartuKendaraan({required this.vehicle});

  final Vehicle vehicle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final logs = ref.watch(servicesForVehicleProvider(vehicle.id));
    final now = DateTime.now();
    final pengingat = daftarPengingat(vehicle: vehicle, logs: logs, now: now);
    final odo = perkiraanOdometer(vehicle, logs, now: now);
    final laju = lajuKmPerHari(vehicle, logs);

    // Cuma tiga teratas di kartu. Sisanya di halaman kendaraannya — daftar
    // sembilan baris di kartu ringkasan membuat yang mendesak tenggelam.
    final utama = pengingat.take(3).toList();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/vehicle/${vehicle.id}'),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(vehicle.type.icon, size: 16, color: _color),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          vehicle.judul,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          odo == null
                              ? 'Odometer belum dicatat'
                              : laju == null
                                  ? '$odo km  ·  catatan terakhirmu'
                                  : '± $odo km  ·  perkiraan hari ini',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 20),
                ],
              ),
              if (utama.isEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Belum ada yang bisa dihitung. Isi tanggal pajak, atau catat '
                  'servis pertama lewat halaman kendaraan ini.',
                  style: TextStyle(fontSize: 14, height: 1.4, color: colorScheme.onSurfaceVariant),
                ),
              ] else ...[
                const SizedBox(height: AppSpacing.sm),
                for (final item in utama)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: _BarisPengingat(pengingat: item, ringkas: true),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

Color _warnaStatus(BuildContext context, StatusTempo status) => switch (status) {
      StatusTempo.lewat => AppColors.priorityHigh,
      StatusTempo.segera => AppColors.priorityMedium,
      StatusTempo.aman => Theme.of(context).colorScheme.onSurfaceVariant,
    };

/// Kalimat sisa waktu/jarak. Dipisah supaya kartu dan halaman detail tidak
/// pernah menuliskan hal yang sama dengan kata yang berbeda.
String ringkasanSisa(Pengingat pengingat) {
  final bagian = <String>[];

  if (pengingat.sisaHari case final hari?) {
    bagian.add(switch (hari) {
      < 0 => 'lewat ${-hari} hari',
      0 => 'hari ini',
      1 => 'besok',
      _ => '$hari hari lagi',
    });
  }

  if (pengingat.sisaKm case final km?) {
    bagian.add(km < 0 ? 'lewat ${-km} km' : '$km km lagi');
  }

  if (bagian.isEmpty) return 'belum bisa dihitung';
  return bagian.join('  ·  ');
}

class _BarisPengingat extends StatelessWidget {
  const _BarisPengingat({required this.pengingat, this.ringkas = false});

  final Pengingat pengingat;
  final bool ringkas;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final warna = _warnaStatus(context, pengingat.status);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(pengingat.icon, size: 16, color: warna),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      pengingat.judul,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: pengingat.lewat ? FontWeight.w800 : FontWeight.w600,
                        color: pengingat.lewat ? warna : null,
                      ),
                    ),
                  ),
                  Text(
                    ringkasanSisa(pengingat),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: warna),
                  ),
                ],
              ),
              if (!ringkas) ...[
                const SizedBox(height: 2),
                Text(
                  pengingat.tanggal == null
                      ? pengingat.dasar
                      : '${_tanggalFormat.format(pengingat.tanggal!)}  ·  ${pengingat.dasar}',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

Future<void> bukaFormKendaraan(
  BuildContext context,
  WidgetRef ref, {
  Vehicle? vehicle,
}) async {
  final tersimpan = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _SheetKendaraan(vehicle: vehicle),
  );
  if (tersimpan == true) ref.invalidate(vehiclesProvider);
}

class _SheetKendaraan extends ConsumerStatefulWidget {
  const _SheetKendaraan({this.vehicle});

  final Vehicle? vehicle;

  @override
  ConsumerState<_SheetKendaraan> createState() => _SheetKendaraanState();
}

class _SheetKendaraanState extends ConsumerState<_SheetKendaraan> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _plateController;
  late final TextEditingController _yearController;
  late final TextEditingController _odoController;

  late VehicleType _type;
  DateTime? _pajak;
  DateTime? _plat;
  bool _saving = false;

  bool get _isEdit => widget.vehicle != null;

  @override
  void initState() {
    super.initState();
    final v = widget.vehicle;
    _nameController = TextEditingController(text: v?.name ?? '');
    _plateController = TextEditingController(text: v?.plate ?? '');
    _yearController = TextEditingController(text: v?.year?.toString() ?? '');
    _odoController = TextEditingController(text: v?.odometerKm?.toString() ?? '');
    _type = v?.type ?? VehicleType.motor;
    _pajak = v?.taxDueOn;
    _plat = v?.plateDueOn;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _plateController.dispose();
    _yearController.dispose();
    _odoController.dispose();
    super.dispose();
  }

  Future<void> _pilihTanggal({required bool pajak}) async {
    final sekarang = DateTime.now();
    final awal = (pajak ? _pajak : _plat) ?? sekarang;

    final hasil = await showDatePicker(
      context: context,
      initialDate: awal,
      firstDate: DateTime(sekarang.year - 10),
      lastDate: DateTime(sekarang.year + 15),
      helpText: pajak ? 'Jatuh tempo pajak tahunan' : 'Jatuh tempo ganti plat',
    );
    if (hasil == null) return;

    setState(() {
      if (pajak) {
        _pajak = hasil;
      } else {
        _plat = hasil;
      }
    });
  }

  Future<void> _simpan() async {
    if (!_formKey.currentState!.validate()) return;

    final userId = ref.read(currentUserProvider)?.id;
    if (userId == null) return;

    setState(() => _saving = true);
    try {
      final plate = _plateController.text.trim();
      final odo = int.tryParse(_odoController.text.trim());

      await ref.read(vehicleRepositoryProvider).saveVehicle(
            userId: userId,
            id: widget.vehicle?.id,
            name: _nameController.text.trim(),
            type: _type,
            plate: plate.isEmpty ? null : plate,
            year: int.tryParse(_yearController.text.trim()),
            odometerKm: odo,
            // Odometer yang tidak diubah tetap memakai tanggal lamanya. Kalau
            // tanggalnya ikut dimajukan tiap kali form disimpan, laju km/hari
            // akan menyusut sendiri tanpa kamu jalan ke mana-mana.
            odometerOn: odo == widget.vehicle?.odometerKm
                ? widget.vehicle?.odometerOn
                : DateTime.now(),
            taxDueOn: _pajak,
            plateDueOn: _plat,
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
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.md,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _isEdit ? 'Edit Kendaraan' : 'Kendaraan Baru',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
              ),
              const SizedBox(height: AppSpacing.md),
              SegmentedButton<VehicleType>(
                segments: [
                  for (final type in VehicleType.values)
                    ButtonSegment(value: type, label: Text(type.label), icon: Icon(type.icon)),
                ],
                selected: {_type},
                onSelectionChanged: (nilai) => setState(() => _type = nilai.first),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _nameController,
                autofocus: !_isEdit,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nama',
                  hintText: 'Misal: Beat Hitam',
                  prefixIcon: Icon(Icons.label_outline),
                ),
                validator: (value) =>
                    (value == null || value.trim().isEmpty) ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _plateController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Nopol',
                        hintText: 'L 1234 AB',
                        prefixIcon: Icon(Icons.pin_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: TextFormField(
                      controller: _yearController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Tahun',
                        prefixIcon: Icon(Icons.calendar_today_outlined),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _odoController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Odometer sekarang (km)',
                  hintText: 'boleh kosong',
                  prefixIcon: Icon(Icons.speed_outlined),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _PilihTanggal(
                label: 'Jatuh tempo pajak tahunan',
                icon: Icons.receipt_long_outlined,
                tanggal: _pajak,
                onTap: () => _pilihTanggal(pajak: true),
                onHapus: _pajak == null ? null : () => setState(() => _pajak = null),
              ),
              const SizedBox(height: AppSpacing.sm),
              _PilihTanggal(
                label: 'Jatuh tempo ganti plat',
                icon: Icons.badge_outlined,
                tanggal: _plat,
                onTap: () => _pilihTanggal(pajak: false),
                onHapus: _plat == null ? null : () => setState(() => _plat = null),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Dua tanggal ini ada di STNK-mu. Yang lima tahunan paling '
                'sering terlewat justru karena jaraknya jauh sekali.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed: _saving ? null : _simpan,
                style: FilledButton.styleFrom(backgroundColor: _color),
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(_saving ? 'Menyimpan...' : 'Simpan'),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        ),
      ),
    );
  }
}

class _PilihTanggal extends StatelessWidget {
  const _PilihTanggal({
    required this.label,
    required this.icon,
    required this.tanggal,
    required this.onTap,
    this.onHapus,
  });

  final String label;
  final IconData icon;
  final DateTime? tanggal;
  final VoidCallback onTap;
  final VoidCallback? onHapus;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radius),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          suffixIcon: onHapus == null
              ? null
              : IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  tooltip: 'Kosongkan',
                  onPressed: onHapus,
                ),
        ),
        child: Text(
          tanggal == null ? 'Belum diisi' : _tanggalFormat.format(tanggal!),
          style: TextStyle(
            fontSize: 14,
            color: tanggal == null ? colorScheme.onSurfaceVariant : null,
          ),
        ),
      ),
    );
  }
}
