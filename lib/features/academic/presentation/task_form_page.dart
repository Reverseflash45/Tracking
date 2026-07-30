import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../data/academic_repository.dart';
import '../data/models/task.dart';
import 'academic_providers.dart';

class TaskFormPage extends ConsumerStatefulWidget {
  const TaskFormPage({super.key});

  @override
  ConsumerState<TaskFormPage> createState() => _TaskFormPageState();
}

class _TaskFormPageState extends ConsumerState<TaskFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  String? _courseId;
  TaskPriority _priority = TaskPriority.medium;
  DateTime _deadline = DateTime.now().add(const Duration(days: 7));
  bool _saving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDeadline() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _deadline,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_deadline),
    );
    if (time == null) return;
    setState(() {
      _deadline = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final userId = ref.read(currentUserProvider)?.id;
    if (userId == null) return;

    setState(() => _saving = true);
    try {
      await ref.read(academicRepositoryProvider).addTask(
            userId: userId,
            courseId: _courseId,
            title: _titleController.text.trim(),
            description:
                _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
            deadline: _deadline,
            priority: _priority,
          );
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final coursesAsync = ref.watch(coursesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Tambah Tugas')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Judul Tugas'),
                validator: (value) =>
                    (value == null || value.trim().isEmpty) ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Deskripsi (opsional)'),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              coursesAsync.when(
                data: (courses) => DropdownButtonFormField<String?>(
                  initialValue: _courseId,
                  decoration: const InputDecoration(labelText: 'Mata Kuliah (opsional)'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Umum')),
                    ...courses.map(
                      (course) => DropdownMenuItem(value: course.id, child: Text(course.name)),
                    ),
                  ],
                  onChanged: (value) => setState(() => _courseId = value),
                ),
                loading: () => const LinearProgressIndicator(),
                error: (error, stackTrace) => Text('Gagal memuat mata kuliah: $error'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<TaskPriority>(
                initialValue: _priority,
                decoration: const InputDecoration(labelText: 'Prioritas'),
                items: TaskPriority.values
                    .map((priority) => DropdownMenuItem(value: priority, child: Text(priority.label)))
                    .toList(),
                onChanged: (value) => setState(() => _priority = value ?? _priority),
              ),
              const SizedBox(height: 12),
              ListTile(
                title: const Text('Deadline'),
                subtitle: Text(_deadline.toString()),
                trailing: const Icon(Icons.event),
                onTap: _pickDeadline,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(
                        height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Simpan'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
