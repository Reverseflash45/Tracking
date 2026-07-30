import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../data/models/exercise_entry.dart';
import '../data/workout_repository.dart';
import 'workout_providers.dart';

class _ExerciseRowControllers {
  _ExerciseRowControllers()
      : nameController = TextEditingController(),
        weightController = TextEditingController(),
        setsController = TextEditingController(),
        repsController = TextEditingController(),
        durationController = TextEditingController(),
        notesController = TextEditingController();

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
  const WorkoutFormPage({super.key});

  @override
  ConsumerState<WorkoutFormPage> createState() => _WorkoutFormPageState();
}

class _WorkoutFormPageState extends ConsumerState<WorkoutFormPage> {
  final _notesController = TextEditingController();
  DateTime _sessionDate = DateTime.now();
  final List<_ExerciseRowControllers> _rows = [_ExerciseRowControllers()];
  bool _saving = false;

  @override
  void dispose() {
    _notesController.dispose();
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _sessionDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
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
      await ref.read(workoutRepositoryProvider).addSession(
            userId: userId,
            sessionDate: _sessionDate,
            notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
            exercises: exercises,
          );
      ref.invalidate(workoutSessionsProvider);
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Catat Sesi Workout')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              title: const Text('Tanggal'),
              subtitle: Text(_sessionDate.toString().split(' ').first),
              trailing: const Icon(Icons.calendar_today),
              onTap: _pickDate,
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < _rows.length; i++) _buildExerciseCard(i),
            OutlinedButton.icon(
              onPressed: () => setState(() => _rows.add(_ExerciseRowControllers())),
              icon: const Icon(Icons.add),
              label: const Text('Tambah Latihan'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'Catatan Sesi (opsional)'),
              maxLines: 2,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Simpan Sesi'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseCard(int index) {
    final row = _rows[index];
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: row.nameController,
                    decoration: const InputDecoration(labelText: 'Nama Latihan'),
                  ),
                ),
                if (_rows.length > 1)
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() {
                      row.dispose();
                      _rows.removeAt(index);
                    }),
                  ),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Cardio'),
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
