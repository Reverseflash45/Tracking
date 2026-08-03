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
import '../data/body_repository.dart';
import '../domain/body_profile.dart';

const _color = AppColors.workout;
final _dateFormat = DateFormat('d MMMM y', 'id_ID');

class BodyProfileFormPage extends ConsumerStatefulWidget {
  const BodyProfileFormPage({super.key});

  @override
  ConsumerState<BodyProfileFormPage> createState() => _BodyProfileFormPageState();
}

class _BodyProfileFormPageState extends ConsumerState<BodyProfileFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _bodyFatController = TextEditingController();
  final _targetWeightController = TextEditingController();

  DateTime? _birthDate;
  Gender _gender = Gender.pria;
  ActivityLevel _activity = ActivityLevel.ringan;
  FitnessGoal _goal = FitnessGoal.maintenance;
  DateTime? _targetDate;

  bool _saving = false;
  bool _prefilled = false;

  @override
  void dispose() {
    _weightController.dispose();
    _heightController.dispose();
    _bodyFatController.dispose();
    _targetWeightController.dispose();
    super.dispose();
  }

  void _prefill(BodyProfile profile, double? weight) {
    _heightController.text = _trimNumber(profile.heightCm);
    if (weight != null) _weightController.text = _trimNumber(weight);
    if (profile.bodyFatPercentage != null) {
      _bodyFatController.text = _trimNumber(profile.bodyFatPercentage!);
    }
    if (profile.targetWeightKg != null) {
      _targetWeightController.text = _trimNumber(profile.targetWeightKg!);
    }
    _birthDate = profile.birthDate;
    _gender = profile.gender;
    _activity = profile.activityLevel;
    _goal = profile.goal;
    _targetDate = profile.targetDate;
    _prefilled = true;
  }

  static String _trimNumber(double value) =>
      value == value.roundToDouble() ? value.round().toString() : value.toString();

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 20, now.month, now.day),
      firstDate: DateTime(now.year - 100),
      lastDate: now,
      helpText: 'Pilih tanggal lahir',
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _pickTargetDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate ?? now.add(const Duration(days: 90)),
      firstDate: now,
      lastDate: DateTime(now.year + 5),
      helpText: 'Target tercapai kapan?',
    );
    if (picked != null) setState(() => _targetDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_birthDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tanggal lahir belum diisi')),
      );
      return;
    }

    final userId = ref.read(currentUserProvider)?.id;
    if (userId == null) return;

    setState(() => _saving = true);
    try {
      final repository = ref.read(bodyRepositoryProvider);
      final profile = BodyProfile(
        heightCm: double.parse(_heightController.text.trim().replaceAll(',', '.')),
        birthDate: _birthDate!,
        gender: _gender,
        activityLevel: _activity,
        goal: _goal,
        bodyFatPercentage: _parseOptional(_bodyFatController.text),
        targetWeightKg: _parseOptional(_targetWeightController.text),
        targetDate: _targetDate,
      );

      await repository.saveProfile(userId: userId, profile: profile);
      await repository.logWeight(
        userId: userId,
        weightKg: double.parse(_weightController.text.trim().replaceAll(',', '.')),
      );

      ref.invalidate(bodyProfileProvider);
      ref.invalidate(weightLogsProvider);
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

  static double? _parseOptional(String raw) {
    final text = raw.trim().replaceAll(',', '.');
    return text.isEmpty ? null : double.tryParse(text);
  }

  String? _validateNumber(
    String? value, {
    required String label,
    required double min,
    required double max,
    bool required = true,
  }) {
    final text = (value ?? '').trim().replaceAll(',', '.');
    if (text.isEmpty) return required ? '$label wajib diisi' : null;
    final parsed = double.tryParse(text);
    if (parsed == null) return '$label harus berupa angka';
    if (parsed < min || parsed > max) return '$label di luar rentang wajar';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    // Isi form dari data tersimpan begitu datanya tiba.
    ref.listen(bodyProfileProvider, (previous, next) {
      if (_prefilled) return;
      final profile = next.value;
      if (profile != null) {
        setState(() => _prefill(profile, ref.read(currentWeightProvider).value));
      }
    });

    final profileAsync = ref.watch(bodyProfileProvider);
    if (!_prefilled && profileAsync.value != null) {
      _prefill(profileAsync.value!, ref.read(currentWeightProvider).value);
    }

    final umur = _birthDate == null ? null : _umurDari(_birthDate!);

    return Scaffold(
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            HeroHeader.sub(
              title: 'Profil Tubuh',
              subtitle: 'Dasar perhitungan kalori dan target harianmu',
              color: _color,
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
                    title: 'Data Dasar',
                    icon: Icons.straighten,
                    color: _color,
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _weightController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Berat (kg)',
                            prefixIcon: Icon(Icons.monitor_weight_outlined),
                          ),
                          validator: (v) =>
                              _validateNumber(v, label: 'Berat', min: 20, max: 400),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: TextFormField(
                          controller: _heightController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Tinggi (cm)',
                            prefixIcon: Icon(Icons.height),
                          ),
                          validator: (v) =>
                              _validateNumber(v, label: 'Tinggi', min: 80, max: 250),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.cake_outlined, size: 20, color: _color),
                      ),
                      title: Text(
                        _birthDate == null
                            ? 'Pilih tanggal lahir'
                            : _dateFormat.format(_birthDate!),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(umur == null ? 'Belum diisi' : '$umur tahun'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _pickBirthDate,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      for (final gender in Gender.values) ...[
                        if (gender != Gender.values.first) const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: _SelectCard(
                            label: gender.label,
                            icon: gender == Gender.pria ? Icons.male : Icons.female,
                            selected: _gender == gender,
                            onTap: () => setState(() => _gender = gender),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _bodyFatController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Persentase lemak tubuh (opsional)',
                      helperText: 'Kalau diisi, BMR dihitung dengan rumus yang lebih akurat',
                      prefixIcon: Icon(Icons.percent),
                    ),
                    validator: (v) => _validateNumber(
                      v,
                      label: 'Persentase lemak',
                      min: 3,
                      max: 70,
                      required: false,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const SectionHeader(
                    title: 'Tingkat Aktivitas',
                    icon: Icons.directions_run,
                    color: _color,
                  ),
                  Card(
                    child: RadioGroup<ActivityLevel>(
                      groupValue: _activity,
                      onChanged: (value) => setState(() => _activity = value!),
                      child: Column(
                        children: [
                          for (final level in ActivityLevel.values)
                            RadioListTile<ActivityLevel>(
                              value: level,
                              activeColor: _color,
                              dense: true,
                              title: Text(
                                level.label,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                              ),
                              subtitle: Text(
                                level.description,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const SectionHeader(
                    title: 'Tujuan',
                    icon: Icons.flag_outlined,
                    color: _color,
                  ),
                  Card(
                    child: RadioGroup<FitnessGoal>(
                      groupValue: _goal,
                      onChanged: (value) => setState(() => _goal = value!),
                      child: Column(
                        children: [
                          for (final goal in FitnessGoal.values)
                            RadioListTile<FitnessGoal>(
                              value: goal,
                              activeColor: _color,
                              dense: true,
                              title: Text(
                                goal.label,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                              ),
                              subtitle: Text(
                                goal.description,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const SectionHeader(
                    title: 'Target (opsional)',
                    icon: Icons.emoji_events_outlined,
                    color: _color,
                  ),
                  TextFormField(
                    controller: _targetWeightController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Target berat (kg)',
                      prefixIcon: Icon(Icons.flag),
                    ),
                    validator: (v) => _validateNumber(
                      v,
                      label: 'Target berat',
                      min: 20,
                      max: 400,
                      required: false,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.event_outlined, size: 20, color: _color),
                      ),
                      title: Text(
                        _targetDate == null
                            ? 'Pilih target waktu'
                            : _dateFormat.format(_targetDate!),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: const Text('Dipakai untuk mengecek target realistis atau tidak'),
                      trailing: _targetDate == null
                          ? const Icon(Icons.chevron_right)
                          : IconButton(
                              icon: const Icon(Icons.close),
                              tooltip: 'Hapus target waktu',
                              onPressed: () => setState(() => _targetDate = null),
                            ),
                      onTap: _pickTargetDate,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SaveBar(
        color: _color,
        saving: _saving,
        onPressed: _submit,
      ),
    );
  }

  static int _umurDari(DateTime birthDate) {
    final now = DateTime.now();
    var age = now.year - birthDate.year;
    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    return age;
  }
}

class _SelectCard extends StatelessWidget {
  const _SelectCard({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radius),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? _color.withValues(alpha: 0.14) : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          border: Border.all(color: selected ? _color : Colors.transparent, width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: selected ? _color : colorScheme.onSurfaceVariant),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: selected ? _color : colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
