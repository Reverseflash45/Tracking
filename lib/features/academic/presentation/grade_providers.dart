import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../data/academic_repository.dart';
import '../data/models/course.dart';
import '../domain/grade.dart';
import 'academic_providers.dart';

const _skalaPrefsKey = 'grade_scale';

/// Skala huruf yang dipakai kampus.
///
/// Disimpan lokal, bukan di server: ini setelan tampilan, dan menyimpannya di
/// database berarti satu tabel lagi untuk satu baris yang tidak pernah berubah.
class GradeScaleController extends Notifier<GradeScale> {
  @override
  GradeScale build() {
    _restore();
    return GradeScale.plusMinus;
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    state = GradeScale.fromName(prefs.getString(_skalaPrefsKey));
  }

  Future<void> set(GradeScale scale) async {
    state = scale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_skalaPrefsKey, scale.name);
  }
}

final gradeScaleProvider =
    NotifierProvider<GradeScaleController, GradeScale>(GradeScaleController.new);

final gradeComponentsProvider =
    FutureProvider.autoDispose<List<GradeComponent>>((ref) async {
  final userId = ref.watch(currentUserProvider)?.id;
  if (userId == null) return const [];
  return ref.watch(academicRepositoryProvider).fetchGradeComponents(userId);
});

/// Mata kuliah lengkap dengan komponen nilainya.
///
/// Digabung di HP dari dua provider yang sudah ada, bukan lewat join di server:
/// keduanya sudah di-cache untuk keperluan lain, jadi halaman Nilai ikut
/// terbaca tanpa sinyal.
final courseGradesProvider = Provider.autoDispose<AsyncValue<List<CourseGrade>>>((ref) {
  final courses = ref.watch(coursesProvider);
  final components = ref.watch(gradeComponentsProvider);

  final error = courses.error ?? components.error;
  if (error != null) {
    return AsyncValue.error(
      error,
      courses.stackTrace ?? components.stackTrace ?? StackTrace.current,
    );
  }

  final daftarMatkul = courses.value;
  final daftarKomponen = components.value;
  if (daftarMatkul == null || daftarKomponen == null) return const AsyncValue.loading();

  final perMatkul = <String, List<GradeComponent>>{};
  for (final komponen in daftarKomponen) {
    perMatkul.putIfAbsent(komponen.courseId, () => []).add(komponen);
  }

  return AsyncValue.data([
    for (final Course course in daftarMatkul)
      CourseGrade(
        courseId: course.id,
        courseName: course.name,
        sks: course.sks,
        semester: course.semester,
        finalLetter: course.finalLetter,
        components: perMatkul[course.id] ?? const [],
      ),
  ]);
});

/// IPK: seluruh mata kuliah yang punya nilai, lintas semester.
final ipkProvider = Provider.autoDispose<AsyncValue<GradeSummary>>((ref) {
  final scale = ref.watch(gradeScaleProvider);
  return ref.watch(courseGradesProvider).whenData((list) => summarizeGrades(list, scale));
});
