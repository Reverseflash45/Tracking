import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../data/academic_repository.dart';
import '../data/models/class_schedule.dart';
import '../data/models/course.dart';
import 'academic_providers.dart';

class ScheduleFormPage extends ConsumerStatefulWidget {
  const ScheduleFormPage({super.key});

  @override
  ConsumerState<ScheduleFormPage> createState() => _ScheduleFormPageState();
}

class _ScheduleFormPageState extends ConsumerState<ScheduleFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _newCourseController = TextEditingController();
  final _lecturerController = TextEditingController();
  final _roomController = TextEditingController();

  String? _selectedCourseId;
  int _dayOfWeek = DateTime.now().weekday;
  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 10, minute: 0);
  bool _isPhl = false;
  DateTime? _specificDate;
  bool _saving = false;

  @override
  void dispose() {
    _newCourseController.dispose();
    _lecturerController.dispose();
    _roomController.dispose();
    super.dispose();
  }

  String _formatTime(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:00';

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startTime = picked;
      } else {
        _endTime = picked;
      }
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _specificDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _specificDate = picked);
  }

  Future<void> _submit(List<Course> courses) async {
    if (!_formKey.currentState!.validate()) return;
    final userId = ref.read(currentUserProvider)?.id;
    if (userId == null) return;

    setState(() => _saving = true);
    try {
      final repository = ref.read(academicRepositoryProvider);
      var courseId = _selectedCourseId;

      if (courseId == null && _newCourseController.text.trim().isNotEmpty) {
        await repository.addCourse(
          userId: userId,
          name: _newCourseController.text.trim(),
          lecturer: _lecturerController.text.trim().isEmpty
              ? null
              : _lecturerController.text.trim(),
        );
        final refreshed = await repository.fetchCourses(userId);
        courseId = refreshed
            .firstWhere((course) => course.name == _newCourseController.text.trim())
            .id;
      }

      if (courseId == null) {
        setState(() => _saving = false);
        return;
      }

      await repository.addSchedule(
        userId: userId,
        courseId: courseId,
        dayOfWeek: _dayOfWeek,
        startTime: _formatTime(_startTime),
        endTime: _formatTime(_endTime),
        room: _roomController.text.trim().isEmpty ? null : _roomController.text.trim(),
        isPhl: _isPhl,
        specificDate: _isPhl ? _specificDate : null,
      );

      ref.invalidate(coursesProvider);
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final coursesAsync = ref.watch(coursesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Tambah Jadwal Kuliah')),
      body: coursesAsync.when(
        data: (courses) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (courses.isNotEmpty)
                  DropdownButtonFormField<String>(
                    initialValue: _selectedCourseId,
                    decoration: const InputDecoration(labelText: 'Mata Kuliah (pilih yang sudah ada)'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('-- Buat baru --')),
                      ...courses.map(
                        (course) => DropdownMenuItem(value: course.id, child: Text(course.name)),
                      ),
                    ],
                    onChanged: (value) => setState(() => _selectedCourseId = value),
                  ),
                if (_selectedCourseId == null) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _newCourseController,
                    decoration: const InputDecoration(labelText: 'Nama Mata Kuliah Baru'),
                    validator: (value) => (_selectedCourseId == null &&
                            (value == null || value.trim().isEmpty))
                        ? 'Wajib diisi jika tidak memilih mata kuliah'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _lecturerController,
                    decoration: const InputDecoration(labelText: 'Dosen (opsional)'),
                  ),
                ],
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  initialValue: _dayOfWeek,
                  decoration: const InputDecoration(labelText: 'Hari'),
                  items: List.generate(
                    7,
                    (index) => DropdownMenuItem(value: index + 1, child: Text(weekDayName(index + 1))),
                  ),
                  onChanged: (value) => setState(() => _dayOfWeek = value ?? _dayOfWeek),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _pickTime(isStart: true),
                        child: Text('Mulai: ${_startTime.format(context)}'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _pickTime(isStart: false),
                        child: Text('Selesai: ${_endTime.format(context)}'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _roomController,
                  decoration: const InputDecoration(labelText: 'Ruangan (opsional)'),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Jadwal PHL (Pengganti Hari Libur)'),
                  value: _isPhl,
                  onChanged: (value) => setState(() => _isPhl = value),
                ),
                if (_isPhl)
                  ListTile(
                    title: Text(_specificDate == null
                        ? 'Pilih tanggal PHL'
                        : 'Tanggal: ${_specificDate!.toLocal()}'.split(' ').first),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: _pickDate,
                  ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _saving ? null : () => _submit(courses),
                  child: _saving
                      ? const SizedBox(
                          height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Simpan'),
                ),
              ],
            ),
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('Gagal memuat: $error')),
      ),
    );
  }
}
