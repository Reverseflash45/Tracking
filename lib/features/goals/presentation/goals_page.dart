import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/hero_header.dart';
import '../data/goal_repository.dart';
import '../domain/goal.dart';

const _color = AppColors.dashboard;

final _rupiah = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
final _tanggal = DateFormat('d MMM', 'id_ID');

String formatNilai(double nilai, GoalMetric metric) {
  if (metric.isRupiah) return _rupiah.format(nilai);
  // Jarak perlu satu desimal; sisanya bilangan cacah — "3,0 sesi" terbaca aneh.
  final angka = metric == GoalMetric.jarakLari
      ? nilai.toStringAsFixed(1)
      : nilai.round().toString();
  return '$angka ${metric.satuan}';
}

Color statusColor(GoalStatus status, ColorScheme colorScheme) => switch (status) {
      GoalStatus.tercapai => AppColors.statusDone,
      GoalStatus.sesuaiJalur => _color,
      GoalStatus.perluKejar => AppColors.priorityMedium,
      GoalStatus.terlampaui => colorScheme.error,
      GoalStatus.belumMulai => colorScheme.onSurfaceVariant,
    };

class GoalsPage extends ConsumerWidget {
  const GoalsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(goalProgressProvider);
    final daftar = progressAsync.value ?? const <GoalProgress>[];

    final tercapai = daftar.where((p) => p.status == GoalStatus.tercapai).length;
    final perluPerhatian = daftar
        .where((p) => p.status == GoalStatus.perluKejar || p.status == GoalStatus.terlampaui)
        .length;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _bukaForm(context, ref),
        backgroundColor: _color,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Target'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(goalsProvider),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            HeroHeader(
              title: 'Target',
              subtitle: 'Dihitung sendiri dari catatanmu',
              color: _color,
              leading: HeroIconButton(
                icon: Icons.arrow_back,
                tooltip: 'Kembali',
                onPressed: () => context.pop(),
              ),
              stats: [
                HeroStatData(
                  icon: Icons.flag_outlined,
                  value: '${daftar.length}',
                  label: 'Berjalan',
                ),
                HeroStatData(icon: Icons.check_circle_outline, value: '$tercapai', label: 'Tercapai'),
                HeroStatData(
                  icon: Icons.priority_high,
                  value: '$perluPerhatian',
                  label: 'Perlu Perhatian',
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 96),
              child: progressAsync.when(
                data: (items) => items.isEmpty
                    ? const EmptyState(
                        icon: Icons.flag_outlined,
                        title: 'Belum ada target',
                        subtitle: 'App ini sudah mengukur banyak hal. Target membuat '
                            'salah satunya jadi janji, bukan sekadar catatan.',
                        color: _color,
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final progress in items)
                            Padding(
                              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                              child: _GoalCard(progress: progress),
                            ),
                        ],
                      ),
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, _) => EmptyState(
                  icon: Icons.error_outline,
                  title: 'Gagal memuat target',
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

Future<void> _bukaForm(BuildContext context, WidgetRef ref, {Goal? goal}) async {
  final tersimpan = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _GoalSheet(goal: goal),
  );
  if (tersimpan == true) ref.invalidate(goalsProvider);
}

class _GoalCard extends ConsumerWidget {
  const _GoalCard({required this.progress});

  final GoalProgress progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final goal = progress.goal;
    final warna = statusColor(progress.status, colorScheme);

    return Dismissible(
      key: ValueKey(goal.id),
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
          title: const Text('Hapus target?'),
          content: Text('"${goal.title}" akan dihapus. Catatan yang diukurnya tetap ada.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hapus')),
          ],
        ),
      ),
      onDismissed: (_) async {
        await ref.read(goalRepositoryProvider).deleteGoal(goal.id);
        ref.invalidate(goalsProvider);
      },
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _bukaForm(context, ref, goal: goal),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: warna.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(goal.metric.icon, size: 17, color: warna),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            goal.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${goal.period.label}  ·  '
                            '${_tanggal.format(progress.window.mulai)}–'
                            '${_tanggal.format(progress.window.selesai)}',
                            style: TextStyle(fontSize: 11.5, color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: warna.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        progress.status.label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: warna,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      formatNilai(progress.nilai, goal.metric),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: warna,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '/ ${formatNilai(goal.targetValue, goal.metric)}',
                      style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                    ),
                    const Spacer(),
                    Text(
                      '${progress.persenMentah.round()}%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress.persen,
                    minHeight: 7,
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation(warna),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _catatan(progress),
                  style: TextStyle(fontSize: 11.5, color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Satu kalimat yang memberi tahu apa yang harus dilakukan, bukan sekadar
  /// mengulang angka yang sudah terlihat di atasnya.
  static String _catatan(GoalProgress progress) {
    final goal = progress.goal;

    if (progress.status == GoalStatus.belumMulai) {
      return 'Mulai ${_tanggal.format(progress.window.mulai)}.';
    }
    if (progress.status == GoalStatus.tercapai) {
      return goal.metric.arah == GoalDirection.minimal
          ? 'Sudah sampai target.'
          : 'Selesai tanpa melewati batas.';
    }
    if (progress.status == GoalStatus.terlampaui) {
      final lebih = progress.nilai - goal.targetValue;
      return 'Lewat ${formatNilai(lebih, goal.metric)} dari batas.';
    }

    if (progress.sisaHari <= 0) return 'Waktunya sudah habis.';

    final laju = progress.lajuDibutuhkan;
    if (laju != null) {
      return 'Sisa ${progress.sisaHari} hari — butuh '
          '${formatNilai(laju, goal.metric)} per hari.';
    }

    final sisaJatah = goal.targetValue - progress.nilai;
    return 'Sisa ${progress.sisaHari} hari — tersisa '
        '${formatNilai(sisaJatah, goal.metric)}.';
  }
}

class _GoalSheet extends ConsumerStatefulWidget {
  const _GoalSheet({this.goal});

  final Goal? goal;

  @override
  ConsumerState<_GoalSheet> createState() => _GoalSheetState();
}

class _GoalSheetState extends ConsumerState<_GoalSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _targetController;

  late GoalMetric _metric;
  late GoalPeriod _period;
  DateTime? _mulai;
  DateTime? _selesai;
  bool _saving = false;

  bool get _isEdit => widget.goal != null;

  @override
  void initState() {
    super.initState();
    final goal = widget.goal;
    _titleController = TextEditingController(text: goal?.title ?? '');
    _targetController = TextEditingController(
      text: goal == null
          ? ''
          : (goal.targetValue == goal.targetValue.roundToDouble()
              ? goal.targetValue.round().toString()
              : goal.targetValue.toString()),
    );
    _metric = goal?.metric ?? GoalMetric.jarakLari;
    _period = goal?.period ?? GoalPeriod.bulanan;
    _mulai = goal?.startDate;
    _selesai = goal?.endDate;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  Future<void> _pilihTanggal({required bool awal}) async {
    final sekarang = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (awal ? _mulai : _selesai) ?? sekarang,
      firstDate: sekarang.subtract(const Duration(days: 365)),
      lastDate: sekarang.add(const Duration(days: 730)),
    );
    if (picked == null) return;
    setState(() {
      if (awal) {
        _mulai = picked;
      } else {
        _selesai = picked;
      }
    });
  }

  Future<void> _simpan() async {
    if (!_formKey.currentState!.validate()) return;

    if (_period == GoalPeriod.sekali) {
      if (_mulai == null || _selesai == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Target sekali jalan butuh tanggal mulai dan selesai')),
        );
        return;
      }
      if (_selesai!.isBefore(_mulai!)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tanggal selesai harus setelah tanggal mulai')),
        );
        return;
      }
    }

    final userId = ref.read(currentUserProvider)?.id;
    if (userId == null) return;

    setState(() => _saving = true);
    try {
      await ref.read(goalRepositoryProvider).saveGoal(
            userId: userId,
            id: widget.goal?.id,
            title: _titleController.text.trim(),
            metric: _metric,
            targetValue: double.parse(_targetController.text.trim().replaceAll(',', '.')),
            period: _period,
            startDate: _mulai,
            endDate: _selesai,
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
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        top: AppSpacing.md,
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
                _isEdit ? 'Edit Target' : 'Target Baru',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _titleController,
                autofocus: !_isEdit,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Nama target',
                  hintText: 'Misal: Lari rutin bulan ini',
                  prefixIcon: Icon(Icons.flag_outlined),
                ),
                validator: (value) =>
                    (value == null || value.trim().isEmpty) ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<GoalMetric>(
                initialValue: _metric,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Yang diukur',
                  prefixIcon: Icon(Icons.straighten),
                ),
                items: [
                  for (final metric in GoalMetric.values)
                    DropdownMenuItem(
                      value: metric,
                      child: Text(
                        metric.arah == GoalDirection.maksimal
                            ? '${metric.label} (maksimal)'
                            : metric.label,
                      ),
                    ),
                ],
                onChanged: (value) => setState(() => _metric = value ?? _metric),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _targetController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: _metric.arah == GoalDirection.maksimal
                      ? 'Batas (${_metric.satuan})'
                      : 'Target (${_metric.satuan})',
                  prefixIcon: const Icon(Icons.numbers),
                ),
                validator: (value) {
                  final angka = double.tryParse((value ?? '').trim().replaceAll(',', '.'));
                  if (angka == null) return 'Isi angka';
                  if (angka <= 0) return 'Harus lebih dari nol';
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.md),
              SegmentedButton<GoalPeriod>(
                segments: [
                  for (final period in GoalPeriod.values)
                    ButtonSegment(value: period, label: Text(period.label)),
                ],
                selected: {_period},
                showSelectedIcon: false,
                onSelectionChanged: (value) => setState(() => _period = value.first),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                _period == GoalPeriod.sekali
                    ? 'Diukur sekali di rentang tanggal yang kamu pilih.'
                    : 'Jendelanya berpindah sendiri — periode berikutnya mulai dari nol lagi.',
                style: TextStyle(fontSize: 11.5, color: colorScheme.onSurfaceVariant),
              ),
              if (_period == GoalPeriod.sekali) ...[
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _pilihTanggal(awal: true),
                        child: Text(_mulai == null ? 'Mulai' : _tanggal.format(_mulai!)),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _pilihTanggal(awal: false),
                        child: Text(_selesai == null ? 'Selesai' : _tanggal.format(_selesai!)),
                      ),
                    ),
                  ],
                ),
              ],
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
      ),
    );
  }
}
