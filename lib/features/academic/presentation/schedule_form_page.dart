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
import '../data/academic_repository.dart';
import '../data/models/class_schedule.dart';
import '../data/models/course.dart';
import 'academic_providers.dart';

const _academicColor = AppColors.academic;
final _dateFormat = DateFormat('EEEE, d MMMM y', 'id_ID');

class ScheduleFormPage extends ConsumerStatefulWidget {
  const ScheduleFormPage({super.key, this.scheduleId});

  /// Kalau diisi, form berjalan dalam mode edit.
  final String? scheduleId;

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
  bool _prefilled = false;

  bool get _isEdit => widget.scheduleId != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final schedule = _findSchedule(ref.read(classSchedulesProvider).value);
      if (schedule != null) _prefill(schedule);
    }
  }

  @override
  void dispose() {
    _newCourseController.dispose();
    _lecturerController.dispose();
    _roomController.dispose();
    super.dispose();
  }

  ClassSchedule? _findSchedule(List<ClassSchedule>? schedules) {
    if (schedules == null) return null;
    for (final schedule in schedules) {
      if (schedule.id == widget.scheduleId) return schedule;
    }
    return null;
  }

  TimeOfDay _parseTime(String value) {
    final parts = value.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  void _prefill(ClassSchedule schedule) {
    _selectedCourseId = schedule.courseId;
    _lecturerController.text = schedule.lecturer ?? '';
    _roomController.text = schedule.room ?? '';
    _dayOfWeek = schedule.dayOfWeek;
    _startTime = _parseTime(schedule.startTime);
    _endTime = _parseTime(schedule.endTime);
    _isPhl = schedule.isPhl;
    _specificDate = schedule.specificDate;
    _prefilled = true;
  }

  String _formatTime(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:00';

  /// Selisih jam mulai-selesai, ditampilkan sebagai info di bawah pemilih jam.
  String get _durationLabel {
    final minutes =
        (_endTime.hour * 60 + _endTime.minute) - (_startTime.hour * 60 + _startTime.minute);
    if (minutes <= 0) return 'Jam selesai harus setelah jam mulai';
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    if (hours == 0) return 'Durasi $rest menit';
    if (rest == 0) return 'Durasi $hours jam';
    return 'Durasi $hours jam $rest menit';
  }

  bool get _isDurationValid =>
      (_endTime.hour * 60 + _endTime.minute) > (_startTime.hour * 60 + _startTime.minute);

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
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _specificDate = picked;
        // Hari otomatis mengikuti tanggal PHL yang dipilih.
        _dayOfWeek = picked.weekday;
      });
    }
  }

  Future<void> _submit(List<Course> courses) async {
    if (!_formKey.currentState!.validate()) return;
    if (!_isDurationValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Jam selesai harus setelah jam mulai')),
      );
      return;
    }
    if (_isPhl && _specificDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih dulu tanggal PHL-nya')),
      );
      return;
    }

    final userId = ref.read(currentUserProvider)?.id;
    if (userId == null) return;

    setState(() => _saving = true);
    try {
      final repository = ref.read(academicRepositoryProvider);
      final lecturer =
          _lecturerController.text.trim().isEmpty ? null : _lecturerController.text.trim();
      final room = _roomController.text.trim().isEmpty ? null : _roomController.text.trim();
      var courseId = _selectedCourseId;

      if (courseId == null && _newCourseController.text.trim().isNotEmpty) {
        final newName = _newCourseController.text.trim();
        await repository.addCourse(userId: userId, name: newName, lecturer: lecturer);
        final refreshed = await repository.fetchCourses(userId);
        courseId = refreshed.firstWhere((course) => course.name == newName).id;
      } else if (courseId != null) {
        // Dosen menempel di mata kuliah, jadi perubahannya disimpan ke sana.
        final course = courses.where((c) => c.id == courseId).firstOrNull;
        if (course != null && course.lecturer != lecturer) {
          await repository.updateCourse(id: course.id, name: course.name, lecturer: lecturer);
        }
      }

      if (courseId == null) {
        setState(() => _saving = false);
        return;
      }

      if (_isEdit) {
        await repository.updateSchedule(
          id: widget.scheduleId!,
          courseId: courseId,
          dayOfWeek: _dayOfWeek,
          startTime: _formatTime(_startTime),
          endTime: _formatTime(_endTime),
          room: room,
          isPhl: _isPhl,
          specificDate: _isPhl ? _specificDate : null,
        );
      } else {
        await repository.addSchedule(
          userId: userId,
          courseId: courseId,
          dayOfWeek: _dayOfWeek,
          startTime: _formatTime(_startTime),
          endTime: _formatTime(_endTime),
          room: room,
          isPhl: _isPhl,
          specificDate: _isPhl ? _specificDate : null,
        );
      }

      ref.invalidate(coursesProvider);
      ref.invalidate(classSchedulesProvider);
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
    final coursesAsync = ref.watch(coursesProvider);

    if (_isEdit) {
      ref.listen(classSchedulesProvider, (previous, next) {
        if (_prefilled) return;
        final schedule = _findSchedule(next.value);
        if (schedule != null) setState(() => _prefill(schedule));
      });
    }

    final courses = coursesAsync.value ?? const <Course>[];

    return Scaffold(
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            HeroHeader(
              title: _isEdit ? 'Edit Jadwal' : 'Tambah Jadwal',
              subtitle: 'Atur mata kuliah, hari, dan jam perkuliahan',
              color: _academicColor,
              leading: HeroIconButton(
                icon: Icons.arrow_back,
                tooltip: 'Kembali',
                onPressed: () => context.pop(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SectionHeader(
                    title: 'Mata Kuliah',
                    icon: Icons.school_outlined,
                    color: _academicColor,
                  ),
                  if (courses.isNotEmpty)
                    DropdownButtonFormField<String>(
                      initialValue: _selectedCourseId,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.menu_book_outlined),
                      ),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('+ Buat mata kuliah baru')),
                        ...courses.map(
                          (course) => DropdownMenuItem(value: course.id, child: Text(course.name)),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedCourseId = value;
                          // Ikut tampilkan dosen dari mata kuliah yang dipilih.
                          final course = courses.where((c) => c.id == value).firstOrNull;
                          _lecturerController.text = course?.lecturer ?? '';
                        });
                      },
                    ),
                  if (_selectedCourseId == null) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _newCourseController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Nama mata kuliah baru',
                        hintText: 'Misal: Basis Data',
                        prefixIcon: Icon(Icons.add),
                      ),
                      validator: (value) => (_selectedCourseId == null &&
                              (value == null || value.trim().isEmpty))
                          ? 'Wajib diisi jika tidak memilih mata kuliah'
                          : null,
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _lecturerController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Dosen (opsional)',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const SectionHeader(
                    title: 'Hari',
                    icon: Icons.calendar_view_week,
                    color: _academicColor,
                  ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (var day = 1; day <= 7; day++) ...[
                          if (day > 1) const SizedBox(width: AppSpacing.sm),
                          _DayChip(
                            day: day,
                            selected: _dayOfWeek == day,
                            // Saat PHL, hari mengikuti tanggal yang dipilih.
                            onTap: _isPhl ? null : () => setState(() => _dayOfWeek = day),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const SectionHeader(
                    title: 'Jam',
                    icon: Icons.schedule_outlined,
                    color: _academicColor,
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _TimeCard(
                          label: 'Mulai',
                          time: _startTime,
                          onTap: () => _pickTime(isStart: true),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _TimeCard(
                          label: 'Selesai',
                          time: _endTime,
                          onTap: () => _pickTime(isStart: false),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Icon(
                        _isDurationValid ? Icons.timelapse : Icons.error_outline,
                        size: 14,
                        color: _isDurationValid
                            ? Theme.of(context).colorScheme.onSurfaceVariant
                            : Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _durationLabel,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _isDurationValid
                              ? Theme.of(context).colorScheme.onSurfaceVariant
                              : Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const SectionHeader(
                    title: 'Detail Tambahan',
                    icon: Icons.info_outline,
                    color: _academicColor,
                  ),
                  TextFormField(
                    controller: _roomController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Ruangan (opsional)',
                      hintText: 'Misal: GD-301',
                      prefixIcon: Icon(Icons.place_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: SwitchListTile(
                      secondary: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _academicColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.event_repeat, size: 18, color: _academicColor),
                      ),
                      title: const Text(
                        'Jadwal PHL',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: const Text('Kelas pengganti di tanggal tertentu'),
                      value: _isPhl,
                      activeThumbColor: _academicColor,
                      onChanged: (value) => setState(() {
                        _isPhl = value;
                        if (!value) _specificDate = null;
                      }),
                    ),
                  ),
                  if (_isPhl) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Card(
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _academicColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.calendar_today,
                              size: 18, color: _academicColor),
                        ),
                        title: const Text('Tanggal PHL'),
                        subtitle: Text(
                          _specificDate == null
                              ? 'Belum dipilih'
                              : _dateFormat.format(_specificDate!),
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: _specificDate == null
                                ? Theme.of(context).colorScheme.error
                                : null,
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _pickDate,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SaveBar(
        color: _academicColor,
        saving: _saving,
        onPressed: () => _submit(courses),
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({required this.day, required this.selected, this.onTap});

  final int day;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final disabled = onTap == null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 52,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? _academicColor : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              weekDayName(day).substring(0, 3),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: selected
                    ? Colors.white
                    : colorScheme.onSurfaceVariant.withValues(alpha: disabled ? 0.5 : 1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeCard extends StatelessWidget {
  const _TimeCard({required this.label, required this.time, required this.onTap});

  final String label;
  final TimeOfDay time;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radius),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 14),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppTheme.radius),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 2),
            Text(
              '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: _academicColor,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
