import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/offline/pending_writes.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/hero_header.dart';
import '../../../core/widgets/section_header.dart';
import '../../finance/data/finance_repository.dart';
import '../../finance/domain/finance_stats.dart';
import '../../finance/domain/transaction.dart';
import '../data/vehicle_repository.dart';
import '../domain/vehicle.dart';
import 'vehicle_page.dart';

const _color = AppColors.vehicle;
final _tanggalFormat = DateFormat('d MMM y', 'id_ID');

class VehicleDetailPage extends ConsumerWidget {
  const VehicleDetailPage({super.key, required this.vehicleId});

  final String vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicles = ref.watch(vehiclesProvider).value ?? const <Vehicle>[];
    final vehicle = vehicles.where((v) => v.id == vehicleId).firstOrNull;

    if (vehicle == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Kendaraan')),
        body: const EmptyState(
          icon: Icons.search_off,
          title: 'Kendaraan tidak ditemukan',
          subtitle: 'Mungkin sudah dihapus dari perangkat lain.',
          color: _color,
        ),
      );
    }

    final logs = ref.watch(servicesForVehicleProvider(vehicleId));
    final now = DateTime.now();
    final pengingat = daftarPengingat(vehicle: vehicle, logs: logs, now: now);
    final odo = perkiraanOdometer(vehicle, logs, now: now);
    final laju = lajuKmPerHari(vehicle, logs);
    final biaya = biayaKendaraan(logs, sejak: DateTime(now.year, 1, 1));

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _catatServis(context, ref, vehicle),
        backgroundColor: _color,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.build_outlined),
        label: const Text('Catat Servis'),
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
              title: vehicle.name,
              subtitle: vehicle.plate?.toUpperCase() ?? vehicle.type.label,
              color: _color,
              leading: HeroIconButton(
                icon: Icons.arrow_back,
                tooltip: 'Kembali',
                onPressed: () => context.pop(),
              ),
              trailing: HeroIconButton(
                icon: Icons.edit_outlined,
                tooltip: 'Edit kendaraan',
                onPressed: () => bukaFormKendaraan(context, ref, vehicle: vehicle),
              ),
              stats: [
                HeroStatData(
                  icon: Icons.speed_outlined,
                  value: odo == null ? '—' : '$odo',
                  label: odo == null
                      ? 'Odometer'
                      : (laju == null ? 'Km Tercatat' : 'Km Perkiraan'),
                ),
                HeroStatData(
                  icon: Icons.build_outlined,
                  value: '${logs.length}',
                  label: 'Servis Tercatat',
                ),
                HeroStatData(
                  icon: Icons.payments_outlined,
                  value: formatRupiahRingkas(biaya.total),
                  label: 'Biaya ${now.year}',
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 96),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (laju != null)
                    _Catatan(
                      'Perkiraan odometer memakai laju ${laju.toStringAsFixed(1)} km/hari, '
                      'dihitung dari jarak antara catatan odometer pertama dan terakhirmu.',
                    ),
                  if (biaya.tanpaBiaya > 0)
                    _Catatan(
                      '${biaya.tanpaBiaya} servis tahun ini tidak dicatat biayanya, '
                      'jadi totalnya lebih besar daripada yang tertulis di atas.',
                    ),
                  const SectionHeader(
                    title: 'Jadwal Berikutnya',
                    icon: Icons.event_available_outlined,
                    color: _color,
                  ),
                  if (pengingat.isEmpty)
                    const _Kartu(
                      child: Text(
                        'Belum ada yang bisa dihitung. Isi tanggal pajak lewat tombol '
                        'edit di atas, atau catat servis pertamamu.',
                        style: TextStyle(fontSize: 14, height: 1.45),
                      ),
                    )
                  else
                    _Kartu(
                      child: Column(
                        children: [
                          for (var i = 0; i < pengingat.length; i++) ...[
                            if (i > 0) const Divider(height: AppSpacing.lg),
                            _BarisJadwal(
                              pengingat: pengingat[i],
                              vehicle: vehicle,
                            ),
                          ],
                        ],
                      ),
                    ),
                  const SizedBox(height: AppSpacing.md),
                  SectionHeader(
                    title: 'Riwayat Servis',
                    icon: Icons.history,
                    color: _color,
                    trailing: logs.isEmpty ? null : Text('${logs.length}'),
                  ),
                  if (logs.isEmpty)
                    const EmptyState(
                      icon: Icons.build_outlined,
                      title: 'Belum ada servis tercatat',
                      subtitle: 'Catat sekali saja, dan jadwal berikutnya '
                          'dihitung sendiri dari situ.',
                      color: _color,
                      compact: true,
                    )
                  else
                    for (final log in logs)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: _KartuServis(log: log, vehicle: vehicle),
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

class _Kartu extends StatelessWidget {
  const _Kartu({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(child: Padding(padding: const EdgeInsets.all(AppSpacing.md), child: child));
  }
}

class _Catatan extends StatelessWidget {
  const _Catatan(this.teks);

  final String teks;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(AppTheme.radius),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, size: 16, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                teks,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.45,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BarisJadwal extends ConsumerWidget {
  const _BarisJadwal({required this.pengingat, required this.vehicle});

  final Pengingat pengingat;
  final Vehicle vehicle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final warna = switch (pengingat.status) {
      StatusTempo.lewat => AppColors.priorityHigh,
      StatusTempo.segera => AppColors.priorityMedium,
      StatusTempo.aman => colorScheme.onSurfaceVariant,
    };
    final pajak = pengingat.judul == 'Pajak tahunan';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(pengingat.icon, size: 16, color: warna),
        const SizedBox(width: AppSpacing.sm),
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
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    ringkasanSisa(pengingat),
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: warna),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                pengingat.tanggal == null
                    ? pengingat.dasar
                    : '${_tanggalFormat.format(pengingat.tanggal!)}  ·  ${pengingat.dasar}',
                style: TextStyle(fontSize: 12, height: 1.4, color: colorScheme.onSurfaceVariant),
              ),
              if (pajak && vehicle.taxDueOn != null) ...[
                const SizedBox(height: 4),
                TextButton.icon(
                  onPressed: () => _bayarPajak(context, ref, vehicle),
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Sudah dibayar', style: TextStyle(fontSize: 14)),
                  style: TextButton.styleFrom(
                    foregroundColor: _color,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
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

Future<void> _bayarPajak(BuildContext context, WidgetRef ref, Vehicle vehicle) async {
  final tempo = vehicle.taxDueOn;
  if (tempo == null) return;

  final berikutnya = DateTime(tempo.year + 1, tempo.month, tempo.day);

  final lanjut = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Pajak sudah dibayar?'),
      content: Text(
        'Jatuh tempo berikutnya akan dimajukan ke '
        '${_tanggalFormat.format(berikutnya)} — satu tahun dari tempo yang '
        'sekarang, bukan dari hari ini, supaya tanggalnya tidak bergeser '
        'sedikit demi sedikit tiap tahun.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Ya')),
      ],
    ),
  );

  if (lanjut != true) return;

  await ref.read(vehicleRepositoryProvider).perpanjangPajak(vehicle.id, tempo);
  ref.invalidate(vehiclesProvider);
}

class _KartuServis extends ConsumerWidget {
  const _KartuServis({required this.log, required this.vehicle});

  final ServiceLog log;
  final Vehicle vehicle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return Dismissible(
      key: ValueKey(log.id),
      direction: DismissDirection.endToStart,
      background: Container(
        decoration: BoxDecoration(
          color: colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(AppTheme.radius),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Icon(Icons.delete_outline, color: colorScheme.onErrorContainer),
      ),
      confirmDismiss: (_) => showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Hapus catatan servis?'),
          content: Text(
            '${log.kind.label} tanggal ${_tanggalFormat.format(log.doneOn)} akan '
            'dihapus, dan jadwal berikutnya ikut berubah.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hapus')),
          ],
        ),
      ),
      onDismissed: (_) async {
        await ref.read(vehicleRepositoryProvider).deleteService(log.id);
        ref.invalidate(vehicleServicesProvider);
      },
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _catatServis(context, ref, vehicle, log: log),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Icon(log.kind.icon, size: 16, color: _color),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        log.kind.label,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          _tanggalFormat.format(log.doneOn),
                          if (log.odometerKm case final km?) '$km km',
                          if (log.note case final n? when n.trim().isNotEmpty) n.trim(),
                        ].join('  ·  '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Text(
                  log.cost == null ? '—' : formatRupiahRingkas(log.cost!),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _catatServis(
  BuildContext context,
  WidgetRef ref,
  Vehicle vehicle, {
  ServiceLog? log,
}) async {
  final tersimpan = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _SheetServis(vehicle: vehicle, log: log),
  );
  if (tersimpan == true) {
    ref.invalidate(vehicleServicesProvider);
    ref.invalidate(transactionsProvider);
  }
}

class _SheetServis extends ConsumerStatefulWidget {
  const _SheetServis({required this.vehicle, this.log});

  final Vehicle vehicle;
  final ServiceLog? log;

  @override
  ConsumerState<_SheetServis> createState() => _SheetServisState();
}

class _SheetServisState extends ConsumerState<_SheetServis> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _odoController;
  late final TextEditingController _costController;
  late final TextEditingController _noteController;

  late ServiceKind _kind;
  late DateTime _tanggal;
  bool _catatPengeluaran = true;
  bool _saving = false;

  bool get _isEdit => widget.log != null;

  @override
  void initState() {
    super.initState();
    final log = widget.log;
    _odoController = TextEditingController(text: log?.odometerKm?.toString() ?? '');
    _costController = TextEditingController(text: log?.cost?.round().toString() ?? '');
    _noteController = TextEditingController(text: log?.note ?? '');
    _kind = log?.kind ?? ServiceKind.oli;
    _tanggal = log?.doneOn ?? DateTime.now();
    // Servis lama tidak ditawari pencatatan ulang: transaksinya sudah dibuat
    // waktu pertama kali disimpan, dan membuatnya lagi berarti dobel.
    _catatPengeluaran = !_isEdit;
  }

  @override
  void dispose() {
    _odoController.dispose();
    _costController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _simpan() async {
    if (!_formKey.currentState!.validate()) return;

    final userId = ref.read(currentUserProvider)?.id;
    if (userId == null) return;

    setState(() => _saving = true);
    try {
      final biaya = double.tryParse(
        _costController.text.trim().replaceAll(RegExp(r'[.,\s]'), ''),
      );
      final catatan = _noteController.text.trim();
      final odo = int.tryParse(_odoController.text.trim());

      await ref.read(vehicleRepositoryProvider).saveService(
            userId: userId,
            id: widget.log?.id,
            vehicleId: widget.vehicle.id,
            kind: _kind,
            doneOn: _tanggal,
            odometerKm: odo,
            cost: biaya,
            note: catatan.isEmpty ? null : catatan,
          );

      if (_catatPengeluaran && biaya != null && biaya > 0) {
        await ref.read(financeRepositoryProvider).addTransaction(
              userId,
              Transaction(
                id: '',
                occurredOn: _tanggal,
                kind: TxKind.pengeluaran,
                category: TxCategory.transport,
                amount: biaya,
                product: '${_kind.label} ${widget.vehicle.name}',
                note: 'Dari catatan kendaraan',
              ),
              queue: ref.read(pendingWriteQueueProvider),
            );
      }

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
    final colorScheme = Theme.of(context).colorScheme;
    final type = widget.vehicle.type;
    final km = _kind.intervalKm(type);
    final bulan = _kind.intervalBulan(type);

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
                _isEdit ? 'Edit Servis' : 'Catat Servis',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<ServiceKind>(
                initialValue: _kind,
                decoration: const InputDecoration(
                  labelText: 'Jenis',
                  prefixIcon: Icon(Icons.build_outlined),
                ),
                items: [
                  for (final kind in ServiceKind.values)
                    DropdownMenuItem(
                      value: kind,
                      child: Row(
                        children: [
                          Icon(kind.icon, size: 16),
                          const SizedBox(width: AppSpacing.sm),
                          Text(kind.label),
                        ],
                      ),
                    ),
                ],
                onChanged: (nilai) => setState(() => _kind = nilai ?? _kind),
              ),
              const SizedBox(height: 4),
              Text(
                // Patokannya disebut di form, bukan disembunyikan sampai
                // jadwalnya muncul — supaya kamu tahu angka mana yang dipakai
                // dan bisa membandingkannya dengan buku servismu sendiri.
                switch ((km, bulan)) {
                  (final k?, final b?) => 'Patokan ${type.label.toLowerCase()}: '
                      'tiap $k km atau $b bulan, mana yang lebih dulu.',
                  (final k?, null) => 'Patokan: tiap $k km.',
                  (null, final b?) => 'Patokan: tiap $b bulan.',
                  _ => 'Jenis ini tidak punya patokan jadwal — dicatat saja '
                      'sebagai riwayat.',
                },
                style: TextStyle(fontSize: 12, height: 1.4, color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.md),
              InkWell(
                onTap: () async {
                  final hasil = await showDatePicker(
                    context: context,
                    initialDate: _tanggal,
                    firstDate: DateTime(DateTime.now().year - 10),
                    lastDate: DateTime.now(),
                  );
                  if (hasil != null) setState(() => _tanggal = hasil);
                },
                borderRadius: BorderRadius.circular(AppTheme.radius),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Tanggal servis',
                    prefixIcon: Icon(Icons.event_outlined),
                  ),
                  child: Text(_tanggalFormat.format(_tanggal), style: const TextStyle(fontSize: 14)),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _odoController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Odometer (km)',
                  hintText: km == null ? 'opsional' : 'perlu, supaya jadwal km bisa dihitung',
                  prefixIcon: const Icon(Icons.speed_outlined),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _costController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Biaya',
                  hintText: 'boleh kosong',
                  prefixIcon: Icon(Icons.payments_outlined),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (!_isEdit)
                CheckboxListTile(
                  value: _catatPengeluaran,
                  onChanged: (nilai) => setState(() => _catatPengeluaran = nilai ?? false),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text(
                    'Catat juga sebagai pengeluaran',
                    style: TextStyle(fontSize: 14),
                  ),
                  subtitle: const Text(
                    'Masuk kategori Transport di Keuangan',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: _noteController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Catatan',
                  hintText: 'Bengkel mana, merek olinya apa',
                  prefixIcon: Icon(Icons.notes),
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
