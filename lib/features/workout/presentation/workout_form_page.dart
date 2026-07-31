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
        notesController = TextEditingController();

  /// Isi controller dari data yang sudah tersimpan (dipakai saat mode edit).
  factory _ExerciseRowControllers.fromEntry(ExerciseEntry entry) {
    final row = _ExerciseRowControllers();
    row.nameController.text = entry.exerciseName;
    row.weightController.text = entry.weightKg?.toString() ?? '';
    row.setsController.text = entry.sets?.toString() ?? '';
    row.repsController.text = entry.reps?.toString() ?? '';
    row.durationController.text = entry.durationMinutes?.toString() ?? '';
    row.notesController.text = entry.notes ?? '';
    row.isCardio = entry.isCardio;
    return row;
  }

  final TextEditingController nameController;
  final TextEditingController weightController;
  final TextEditingController setsController;
  final TextEditingController repsController;
  final TextEditingController durationController;
  final TextEditingController notesController;
  bool isCardio = false;

  void dispose() {
    nameController.dispose();
    weightController.dispose();
    setsController.dispose();
    repsController.dispose();
    durationController.dispose();
    notesController.dispose();
  }

  /// Isi berat/set/rep dari saran progressive overload.
  void applySuggestion(OverloadSuggestion suggestion) {
    weightController.text = suggestion.targetWeight == suggestion.targetWeight.roundToDouble()
        ? suggestion.targetWeight.round().toString()
        : suggestion.targetWeight.toString();
    setsController.text = suggestion.targetSets.toString();
    repsController.text = suggestion.targetReps.toString();
  }

  ExerciseEntry toEntry() => ExerciseEntry(
        id: '',
        sessionId: '',
        userId: '',
        exerciseName: nameController.text.trim(),
        weightKg: double.tryParse(weightController.text.trim()),
        sets: int.tryParse(setsController.text.trim()),
        reps: int.tryParse(repsController.text.trim()),
        durationMinutes: int.tryParse(durationController.text.trim()),
        isCardio: isCardio,
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
    final suggestion = row.isCardio ? null : suggestions[key];

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
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Cardio'),
              activeThumbColor: _workoutColor,
              value: row.isCardio,
              onChanged: (value) => setState(() => row.isCardio = value),
            ),
            if (!row.isCardio)
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: row.weightController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Berat (kg)'),
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
