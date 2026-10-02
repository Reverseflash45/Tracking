import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../data/berkala_repository.dart';
import '../domain/berkala.dart';
import 'routine_form_sheet.dart' show jamDb, jamDari, jamTampil;

const _color = AppColors.dashboard;

/// Form satu rutinitas berkala.
class BerkalaFormSheet extends ConsumerStatefulWidget {
  const BerkalaFormSheet({super.key, this.awal});

  /// Yang sedang diubah. Null berarti menambah baru.
  final RutinitasBerkala? awal;

  @override
  ConsumerState<BerkalaFormSheet> createState() => _BerkalaFormSheetState();
}

class _BerkalaFormSheetState extends ConsumerState<BerkalaFormSheet> {
  late final _judul = TextEditingController(text: widget.awal?.title ?? '');
  late final _jarak = TextEditingController(text: '${widget.awal?.intervalDays ?? 25}');
  late final _catatan = TextEditingController(text: widget.awal?.note ?? '');

  late DateTime _terakhir = widget.awal?.lastDoneOn ?? DateTime.now();
  late TimeOfDay? _jam = widget.awal?.remindAt == null ? null : jamDari(widget.awal!.remindAt!);

  bool _menyimpan = false;

  bool get _mengubah => widget.awal != null;

  int? get _jarakHari {
    final nilai = int.tryParse(_jarak.text.trim());
    if (nilai == null || nilai < 1 || nilai > 3650) return null;
    return nilai;
  }

  @override
  void dispose() {
    _judul.dispose();
    _jarak.dispose();
    _catatan.dispose();
    super.dispose();
  }

  Future<void> _pilihTanggal() async {
    final sekarang = DateTime.now();
    final pilihan = await showDatePicker(
      context: context,
      initialDate: _terakhir.isAfter(sekarang) ? sekarang : _terakhir,
      firstDate: DateTime(sekarang.year - 10),
      lastDate: sekarang,
      helpText: 'Terakhir dilakukan',
    );
    if (pilihan != null) setState(() => _terakhir = pilihan);
  }

  Future<void> _pilihJam() async {
    final pilihan = await showTimePicker(
      context: context,
      initialTime: _jam ?? const TimeOfDay(hour: 8, minute: 0),
    );
    if (pilihan != null) setState(() => _jam = pilihan);
  }

  Future<void> _simpan() async {
    final userId = ref.read(currentUserProvider)?.id;
    if (userId == null) return;

    final messenger = ScaffoldMessenger.of(context);
    final judul = _judul.text.trim();
    if (judul.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('Nama rutinitas wajib diisi')));
      return;
    }
    final jarak = _jarakHari;
    if (jarak == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Jarak harinya harus antara 1 dan 3650')),
      );
      return;
    }

    setState(() => _menyimpan = true);
    try {
      await ref.read(berkalaRepositoryProvider).simpan(
            userId: userId,
            id: widget.awal?.id,
            title: judul,
            intervalDays: jarak,
            lastDoneOn: _terakhir,
            remindAt: _jam == null ? null : jamDb(_jam!),
            note: _catatan.text,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _menyimpan = false);
      messenger.showSnackBar(SnackBar(content: Text('Gagal menyimpan: $e')));
    }
  }

  Future<void> _hapus() async {
    final awal = widget.awal;
    if (awal == null) return;

    final yakin = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus rutinitas?'),
        content: Text('"${awal.title}" dan pengingatnya akan dihapus.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hapus')),
        ],
      ),
    );
    if (yakin != true || !mounted) return;

    setState(() => _menyimpan = true);
    try {
      await ref.read(berkalaRepositoryProvider).hapus(awal.id);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _menyimpan = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Gagal menghapus: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final redup = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: colorScheme.onSurfaceVariant,
    );

    final jarak = _jarakHari;
    final berikutnya = jarak == null
        ? null
        : DateTime(_terakhir.year, _terakhir.month, _terakhir.day).add(Duration(days: jarak));

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _mengubah ? 'Ubah rutinitas berkala' : 'Rutinitas berkala baru',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: AppSpacing.md),

            TextField(
              controller: _judul,
              autofocus: !_mengubah,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Rutinitas',
                hintText: 'Misal: Absen akun Telkomsel',
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            Text('Ulangi tiap', style: redup),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                SizedBox(
                  width: 96,
                  child: TextField(
                    controller: _jarak,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(suffixText: 'hari'),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      for (final hari in kPilihanJarakHari)
                        ChoiceChip(
                          label: Text('$hari'),
                          visualDensity: VisualDensity.compact,
                          selected: jarak == hari,
                          onSelected: (_) => setState(() => _jarak.text = '$hari'),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            OutlinedButton.icon(
              onPressed: _pilihTanggal,
              icon: const Icon(Icons.event_available_outlined, size: 18),
              label: Text(
                'Terakhir dilakukan: ${DateFormat('EEEE, d MMM yyyy', 'id_ID').format(_terakhir)}',
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pilihJam,
                    icon: const Icon(Icons.alarm, size: 18),
                    label: Text(
                      _jam == null ? 'Jam pengingat: ikut Profil' : 'Ingatkan ${jamTampil(_jam!)}',
                    ),
                  ),
                ),
                if (_jam != null)
                  IconButton(
                    tooltip: 'Ikut jam pengingat di Profil',
                    onPressed: () => setState(() => _jam = null),
                    icon: const Icon(Icons.close, size: 18),
                  ),
              ],
            ),
            if (berikutnya != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text(
                  'Jatuh tempo berikutnya: '
                  '${DateFormat('EEEE, d MMM yyyy', 'id_ID').format(berikutnya)}',
                  style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                ),
              ),
            const SizedBox(height: AppSpacing.md),

            TextField(
              controller: _catatan,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Catatan (opsional)',
                hintText: 'Misal: login lewat aplikasi, cukup buka saja',
              ),
            ),
            if (widget.awal case final awal?) ...[
              const SizedBox(height: AppSpacing.md),
              _Riwayat(routineId: awal.id),
            ],
            const SizedBox(height: AppSpacing.lg),

            FilledButton(
              onPressed: _menyimpan ? null : _simpan,
              style: FilledButton.styleFrom(backgroundColor: _color),
              child: Text(_menyimpan ? 'Menyimpan...' : 'Simpan'),
            ),
            if (_mengubah)
              TextButton.icon(
                onPressed: _menyimpan ? null : _hapus,
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Hapus rutinitas'),
                style: TextButton.styleFrom(foregroundColor: colorScheme.error),
              ),
          ],
        ),
      ),
    );
  }
}

/// Riwayat selesai satu rutinitas: kapan saja, dan berapa kali telat.
class _Riwayat extends ConsumerWidget {
  const _Riwayat({required this.routineId});

  final String routineId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final redup = TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant);

    return ref.watch(riwayatBerkalaProvider(routineId)).when(
          data: (logs) {
            if (logs.isEmpty) {
              return Text(
                'Belum ada riwayat. Tiap kali kamu menekan "Sudah", tanggalnya tercatat di sini.',
                style: redup,
              );
            }
            final ringkas = ringkasRiwayat(logs);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Riwayat · tepat waktu ${ringkas.tepat} dari ${ringkas.total}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                for (final log in logs.take(8))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Icon(
                          log.telatHari == 0 ? Icons.check_circle_outline : Icons.schedule,
                          size: 16,
                          color: log.telatHari == 0 ? AppColors.statusDone : AppColors.deadline,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            DateFormat('EEEE, d MMM yyyy', 'id_ID').format(log.doneOn),
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        Text(
                          log.telatHari == 0 ? 'Tepat waktu' : 'Telat ${log.telatHari} hari',
                          style: TextStyle(
                            fontSize: 12,
                            color: log.telatHari == 0
                                ? colorScheme.onSurfaceVariant
                                : AppColors.deadline,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
          loading: () => const LinearProgressIndicator(),
          // Riwayat cuma pelengkap; gagal memuatnya (misal tanpa sinyal)
          // tidak boleh menghalangi kamu mengubah rutinitasnya.
          error: (_, _) => Text('Riwayat tidak bisa dimuat sekarang.', style: redup),
        );
  }
}
