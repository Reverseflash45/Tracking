import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/hero_header.dart';
import '../../../core/widgets/save_bar.dart';
import '../../../core/widgets/section_header.dart';
import '../data/models/exercise_entry.dart';
import '../data/models/workout_session.dart';
import '../data/workout_repository.dart';
import '../domain/progressive_overload.dart';
import 'overload_suggestion_view.dart';
import 'workout_providers.dart';

const _workoutColor = AppColors.workout;
final _dateFormat = DateFormat('EEEE, d MMMM y', 'id_ID');

class _ExerciseRowControllers {
  _ExerciseRowControllers()
      : nameController = TextEditingController(),
        weightController = TextEditingController(),
        setsController = TextEditingController(),
        repsController = TextEditingController(),
        durationController = TextEditingController(),
        holdController = TextEditingController(),
        notesController = TextEditingController();

  /// Isi controller dari data yang sudah tersimpan (dipakai saat mode edit).
  factory _ExerciseRowControllers.fromEntry(ExerciseEntry entry) {
    final row = _ExerciseRowControllers();
    row.nameController.text = entry.exerciseName;
    row.weightController.text = entry.weightKg?.toString() ?? '';
    row.setsController.text = entry.sets?.toString() ?? '';
    row.repsController.text = entry.reps?.toString() ?? '';
    row.durationController.text = entry.durationMinutes?.toString() ?? '';
    row.holdController.text = entry.durationSeconds?.toString() ?? '';
    row.notesController.text = entry.notes ?? '';
    row.type = entry.type;
    row.progressionLevel = entry.progressionLevel;
    return row;
  }

  final TextEditingController nameController;
  final TextEditingController weightController;
  final TextEditingController setsController;
  final TextEditingController repsController;
  final TextEditingController durationController;
  final TextEditingController holdController;
  final TextEditingController notesController;
  ExerciseType type = ExerciseType.beban;
  int progressionLevel = 0;

  void dispose() {
    nameController.dispose();
    weightController.dispose();
    setsController.dispose();
    repsController.dispose();
    durationController.dispose();
    holdController.dispose();
    notesController.dispose();
  }

  /// Terapkan saran progressive overload ke field yang relevan. Untuk saran
  /// naik variasi, nama latihannya ikut diganti ke langkah berikutnya.
  void applySuggestion(OverloadSuggestion suggestion) {
    if (suggestion.targetExerciseName != null) {
      nameController.text = suggestion.targetExerciseName!;
    }
    if (suggestion.targetWeight != null) {
      weightController.text = formatWeight(suggestion.targetWeight!);
    }
    if (suggestion.targetSets != null) {
      setsController.text = suggestion.targetSets.toString();
    }
    if (suggestion.targetReps != null) {
      repsController.text = suggestion.targetReps.toString();
    }
    if (suggestion.targetSeconds != null) {
      holdController.text = suggestion.targetSeconds.toString();
    }
    if (suggestion.targetLevel != null) {
      progressionLevel = suggestion.targetLevel!;
    }
  }

  ExerciseEntry toEntry() => ExerciseEntry(
        id: '',
        sessionId: '',
        userId: '',
        exerciseName: nameController.text.trim(),
        type: type,
        weightKg: type.pakaiBeban ? double.tryParse(weightController.text.trim()) : null,
        sets: type == ExerciseType.cardio ? null : int.tryParse(setsController.text.trim()),
        reps: type.pakaiRep ? int.tryParse(repsController.text.trim()) : null,
        durationMinutes: type == ExerciseType.cardio
            ? int.tryParse(durationController.text.trim())
            : null,
        durationSeconds: type == ExerciseType.isometrik
            ? int.tryParse(holdController.text.trim())
            : null,
        progressionLevel: progressionLevel,
        notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
      );
}

class WorkoutFormPage extends ConsumerStatefulWidget {
  const WorkoutFormPage({super.key, this.sessionId});

  /// Kalau diisi, form berjalan dalam mode edit.
  final String? sessionId;

  @override
  ConsumerState<WorkoutFormPage> createState() => _WorkoutFormPageState();
}

class _WorkoutFormPageState extends ConsumerState<WorkoutFormPage> {
  final _notesController = TextEditingController();
  DateTime _sessionDate = DateTime.now();
  final List<_ExerciseRowControllers> _rows = [_ExerciseRowControllers()];
  bool _saving = false;
  bool _prefilled = false;

  bool get _isEdit => widget.sessionId != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final session = _findSession(ref.read(workoutSessionsProvider).value);
      if (session != null) _prefill(session);
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  WorkoutSession? _findSession(List<WorkoutSession>? sessions) {
    if (sessions == null) return null;
    for (final session in sessions) {
      if (session.id == widget.sessionId) return session;
    }
    return null;
  }

  void _prefill(WorkoutSession session) {
    _sessionDate = session.sessionDate;
    _notesController.text = session.notes ?? '';
    for (final row in _rows) {
      row.dispose();
    }
    _rows
      ..clear()
      ..addAll(session.exercises.map(_ExerciseRowControllers.fromEntry));
    if (_rows.isEmpty) _rows.add(_ExerciseRowControllers());
    _prefilled = true;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _sessionDate,
      // Dilebarkan supaya sesi lama tetap bisa dibuka saat mode edit.
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year, now.month, now.day),
    );
    if (picked != null) setState(() => _sessionDate = picked);
  }

  Future<void> _submit() async {
    final userId = ref.read(currentUserProvider)?.id;
    if (userId == null) return;

    final exercises = _rows
        .map((row) => row.toEntry())
        .where((entry) => entry.exerciseName.isNotEmpty)
        .toList();

    if (exercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Isi minimal satu latihan')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final repository = ref.read(workoutRepositoryProvider);
      final notes =
          _notesController.text.trim().isEmpty ? null : _notesController.text.trim();

      if (_isEdit) {
        await repository.updateSession(
          sessionId: widget.sessionId!,
          userId: userId,
          sessionDate: _sessionDate,
          notes: notes,
          exercises: exercises,
        );
      } else {
        await repository.addSession(
          userId: userId,
          sessionDate: _sessionDate,
          notes: notes,
          exercises: exercises,
        );
      }
      ref.invalidate(workoutSessionsProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Gagal menyimpan: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isEdit) {
      ref.listen(workoutSessionsProvider, (previous, next) {
        if (_prefilled) return;
        final session = _findSession(next.value);
        if (session != null) setState(() => _prefill(session));
      });
    }

    final suggestions =
        ref.watch(overloadSuggestionsProvider).value ?? const <String, OverloadSuggestion>{};
    final filledCount =
        _rows.where((row) => row.nameController.text.trim().isNotEmpty).length;

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          HeroHeader(
            title: _isEdit ? 'Edit Sesi Workout' : 'Catat Sesi Workout',
            subtitle: 'Catat latihanmu, saran beban muncul otomatis',
            color: _workoutColor,
            leading: HeroIconButton(
              icon: Icons.arrow_back,
              tooltip: 'Kembali',
              onPressed: () => context.pop(),
            ),
            stats: [
              HeroStatData(
                icon: Icons.event,
                value: DateFormat('d MMM', 'id_ID').format(_sessionDate),
                label: 'Tanggal Sesi',
              ),
              HeroStatData(
                icon: Icons.fitness_center,
                value: '$filledCount',
                label: 'Latihan Diisi',
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SectionHeader(
                  title: 'Sesi',
                  icon: Icons.today_outlined,
                  color: _workoutColor,
                ),
                Card(
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _workoutColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.calendar_today, size: 18, color: _workoutColor),
                    ),
                    title: Text(
                      _dateFormat.format(_sessionDate),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: const Text('Ketuk untuk ganti tanggal'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _pickDate,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                const SectionHeader(
                  title: 'Latihan',
                  icon: Icons.fitness_center,
                  color: _workoutColor,
                ),
                for (var i = 0; i < _rows.length; i++) _buildExerciseCard(i, suggestions),
                OutlinedButton.icon(
                  onPressed: () => setState(() => _rows.add(_ExerciseRowControllers())),
                  icon: const Icon(Icons.add, color: _workoutColor),
                  label: const Text('Tambah Latihan', style: TextStyle(color: _workoutColor)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: _workoutColor),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                const SectionHeader(
                  title: 'Catatan',
                  icon: Icons.sticky_note_2_outlined,
                  color: _workoutColor,
                ),
                TextField(
                  controller: _notesController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Catatan sesi (opsional)',
                    hintText: 'Misal: badan enak, tidur cukup',
                    alignLabelWithHint: true,
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SaveBar(
        color: _workoutColor,
        saving: _saving,
        onPressed: _submit,
        label: 'Simpan Sesi',
      ),
    );
  }

  Widget _buildExerciseCard(int index, Map<String, OverloadSuggestion> suggestions) {
    final row = _rows[index];
    final key = row.nameController.text.trim().toLowerCase();
    final suggestion = row.type == ExerciseType.cardio ? null : suggestions[key];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: _workoutColor.withValues(alpha: 0.14),
                  foregroundColor: _workoutColor,
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: TextField(
                    controller: row.nameController,
                    textCapitalization: TextCapitalization.words,
                    // Rebuild supaya strip saran ikut berubah saat namanya diketik.
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(labelText: 'Nama Latihan'),
                  ),
                ),
                if (_rows.length > 1)
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Hapus latihan',
                    onPressed: () => setState(() {
                      row.dispose();
                      _rows.removeAt(index);
                    }),
                  ),
              ],
            ),
            if (suggestion != null)
              OverloadStrip(
                suggestion: suggestion,
                onApply: () => setState(() => row.applySuggestion(suggestion)),
              ),
            const SizedBox(height: AppSpacing.sm),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final type in ExerciseType.values) ...[
                    if (type != ExerciseType.values.first) const SizedBox(width: 6),
                    ChoiceChip(
                      label: Text(type.label),
                      selected: row.type == type,
                      onSelected: (_) => setState(() => row.type = type),
                      selectedColor: _workoutColor.withValues(alpha: 0.18),
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: row.type == type
                            ? _workoutColor
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            // Field yang tampil menyesuaikan tipe: beban/bodyweight pakai
            // set x rep, isometrik pakai detik tahanan, cardio pakai menit.
            if (row.type.pakaiRep)
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: row.weightController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: row.type == ExerciseType.bodyweight
                            ? 'Beban tambahan'
                            : 'Berat (kg)',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: row.setsController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Set'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: row.repsController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Rep'),
                    ),
                  ),
                ],
              )
            else if (row.type == ExerciseType.isometrik)
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: row.setsController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Set'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: row.holdController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Tahan (detik)'),
                    ),
                  ),
                ],
              )
            else
              TextField(
                controller: row.durationController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Durasi (menit)'),
              ),
            const SizedBox(height: 8),
            TextField(
              controller: row.notesController,
              decoration: const InputDecoration(labelText: 'Catatan (opsional)'),
            ),
          ],
        ),
      ),
    );
  }
}
