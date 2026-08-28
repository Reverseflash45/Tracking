import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../academic/data/models/class_schedule.dart';
import '../data/routine_repository.dart';
import '../domain/routine.dart';

const _color = AppColors.dashboard;

String jamDb(TimeOfDay jam) =>
    '${jam.hour.toString().padLeft(2, '0')}:${jam.minute.toString().padLeft(2, '0')}:00';

TimeOfDay jamDari(String teks) {
  final bagian = teks.split(':');
  return TimeOfDay(hour: int.parse(bagian[0]), minute: int.parse(bagian[1]));
}

String jamTampil(TimeOfDay jam) =>
    '${jam.hour.toString().padLeft(2, '0')}:${jam.minute.toString().padLeft(2, '0')}';

/// Form satu kegiatan. Bentuknya sheet, bukan halaman penuh: satu hari berisi
/// belasan baris, dan setiap perpindahan halaman menambah dua ketukan pada
/// pekerjaan yang memang berulang-ulang.
class RoutineFormSheet extends ConsumerStatefulWidget {
  const RoutineFormSheet({super.key, required this.hari, this.awal});

  final int hari;

  /// Kegiatan yang sedang diubah. Null berarti menambah baru.
  final RoutineItem? awal;

  @override
  ConsumerState<RoutineFormSheet> createState() => _RoutineFormSheetState();
}

class _RoutineFormSheetState extends ConsumerState<RoutineFormSheet> {
  late final _judul = TextEditingController(text: widget.awal?.title ?? '');
  late final _catatan = TextEditingController(text: widget.awal?.note ?? '');

  late int _hari = widget.awal?.dayOfWeek ?? widget.hari;
  late KategoriRutinitas _kategori = widget.awal?.category ?? KategoriRutinitas.lainnya;
  late TimeOfDay _mulai =
      widget.awal == null ? TimeOfDay.now() : jamDari(widget.awal!.startTime);
  late TimeOfDay? _selesai =
      widget.awal?.endTime == null ? null : jamDari(widget.awal!.endTime!);

  bool _menyimpan = false;

  bool get _mengubah => widget.awal != null;

  @override
  void dispose() {
    _judul.dispose();
    _catatan.dispose();
    super.dispose();
  }

  Future<void> _pilihJam({required bool awal}) async {
    final pilihan = await showTimePicker(
      context: context,
      initialTime: awal ? _mulai : (_selesai ?? _mulai),
    );
    if (pilihan == null) return;
    setState(() {
      if (awal) {
        _mulai = pilihan;
      } else {
        _selesai = pilihan;
      }
    });
  }

  Future<void> _simpan() async {
    final userId = ref.read(currentUserProvider)?.id;
    if (userId == null) return;

    final judul = _judul.text.trim();
    if (judul.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Judul kegiatan wajib diisi')));
      return;
    }

    setState(() => _menyimpan = true);
    try {
      await ref.read(routineRepositoryProvider).simpan(
            userId: userId,
            id: widget.awal?.id,
            dayOfWeek: _hari,
            startTime: jamDb(_mulai),
            endTime: _selesai == null ? null : jamDb(_selesai!),
            title: judul,
            category: _kategori,
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

  Future<void> _hapus() async {
    final awal = widget.awal;
    if (awal == null) return;

    final yakin = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus kegiatan?'),
        content: Text('"${awal.title}" akan dihapus dari ${weekDayName(awal.dayOfWeek)}.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hapus')),
        ],
      ),
    );
    if (yakin != true || !mounted) return;

    setState(() => _menyimpan = true);
    try {
      await ref.read(routineRepositoryProvider).hapus(awal.id);
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
              _mengubah ? 'Ubah kegiatan' : 'Kegiatan baru',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: AppSpacing.md),

            TextField(
              controller: _judul,
              autofocus: !_mengubah,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Kegiatan',
                hintText: 'Misal: Sarapan — omelet + roti',
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pilihJam(awal: true),
                    icon: const Icon(Icons.schedule, size: 18),
                    label: Text('Mulai ${jamTampil(_mulai)}'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pilihJam(awal: false),
                    icon: const Icon(Icons.schedule_outlined, size: 18),
                    label: Text(
                      _selesai == null ? 'Sampai —' : 'Sampai ${jamTampil(_selesai!)}',
                    ),
                  ),
                ),
              ],
            ),
            if (_selesai != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => setState(() => _selesai = null),
                  icon: const Icon(Icons.close, size: 14),
                  label: const Text('Tanpa jam selesai', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.sm),

            Text(
              'Jenis',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                for (final jenis in KategoriRutinitas.values)
                  ChoiceChip(
                    label: Text(jenis.label),
                    selected: _kategori == jenis,
                    onSelected: (_) => setState(() => _kategori = jenis),
                    selectedColor: _color.withValues(alpha: 0.18),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _kategori == jenis ? _color : colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            DropdownButtonFormField<int>(
              initialValue: _hari,
              decoration: const InputDecoration(
                labelText: 'Hari',
                prefixIcon: Icon(Icons.today_outlined),
              ),
              items: [
                for (var hari = 1; hari <= 7; hari++)
                  DropdownMenuItem(value: hari, child: Text(weekDayName(hari))),
              ],
              onChanged: (value) => setState(() => _hari = value ?? _hari),
            ),
            const SizedBox(height: AppSpacing.md),

            TextField(
              controller: _catatan,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Catatan (opsional)',
                hintText: 'Misal: sela kelas, sudah disiapkan Minggu malam',
              ),
            ),
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
                label: const Text('Hapus kegiatan'),
                style: TextButton.styleFrom(foregroundColor: colorScheme.error),
              ),
          ],
        ),
      ),
    );
  }
}
