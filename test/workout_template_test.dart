import 'package:flutter_test/flutter_test.dart';
import 'package:tracking/features/profile/domain/export_file.dart';
import 'package:tracking/features/workout/data/models/exercise_entry.dart';
import 'package:tracking/features/workout/data/models/workout_template.dart';

Map<String, dynamic> _exerciseRow(
  String name, {
  int position = 0,
  String type = 'beban',
  num? weight,
  int? sets,
  int? reps,
  int? rest,
}) {
  return {
    'exercise_name': name,
    'position': position,
    'exercise_type': type,
    'weight_kg': weight,
    'sets': sets,
    'reps': reps,
    'duration_minutes': null,
    'duration_seconds': null,
    'progression_level': 0,
    'rest_seconds': rest,
    'notes': null,
  };
}

void main() {
  group('WorkoutTemplate.fromMap', () {
    test('mengurutkan latihan menurut position, bukan urutan baris', () {
      final template = WorkoutTemplate.fromMap({
        'id': 't1',
        'name': 'Push A',
        'workout_template_exercises': [
          _exerciseRow('Dips', position: 2),
          _exerciseRow('Bench Press', position: 0),
          _exerciseRow('Overhead Press', position: 1),
        ],
      });

      expect(
        [for (final e in template.exercises) e.exerciseName],
        ['Bench Press', 'Overhead Press', 'Dips'],
      );
    });

    test('template tanpa latihan tidak error', () {
      final template = WorkoutTemplate.fromMap({'id': 't1', 'name': 'Kosong'});

      expect(template.exercises, isEmpty);
      expect(template.summary, 'Belum ada latihan');
    });

    test('membaca tipe dan angka latihan', () {
      final template = WorkoutTemplate.fromMap({
        'id': 't1',
        'name': 'Core',
        'workout_template_exercises': [
          _exerciseRow('Plank', type: 'isometrik', sets: 3, rest: 45),
        ],
      });

      final plank = template.exercises.single;
      expect(plank.type, ExerciseType.isometrik);
      expect(plank.sets, 3);
      expect(plank.restSeconds, 45);
    });

    test('tipe yang tidak dikenal jatuh ke beban, bukan melempar error', () {
      final template = WorkoutTemplate.fromMap({
        'id': 't1',
        'name': 'Lama',
        'workout_template_exercises': [_exerciseRow('Curl', type: 'entah_apa')],
      });

      expect(template.exercises.single.type, ExerciseType.beban);
    });
  });

  group('summary', () {
    test('dua latihan atau kurang disebut semua', () {
      final template = WorkoutTemplate.fromMap({
        'id': 't1',
        'name': 'Pull',
        'workout_template_exercises': [
          _exerciseRow('Pull Up', position: 0),
          _exerciseRow('Row', position: 1),
        ],
      });

      expect(template.summary, 'Pull Up, Row');
    });

    test('lebih dari dua diringkas dengan sisanya', () {
      final template = WorkoutTemplate.fromMap({
        'id': 't1',
        'name': 'Leg',
        'workout_template_exercises': [
          _exerciseRow('Squat', position: 0),
          _exerciseRow('Leg Press', position: 1),
          _exerciseRow('Lunge', position: 2),
          _exerciseRow('Calf Raise', position: 3),
        ],
      });

      expect(template.summary, 'Squat, Leg Press, +2 lagi');
    });
  });

  group('TemplateExercise.toInsertMap', () {
    test('menyertakan template, user, dan urutan', () {
      const exercise = TemplateExercise(
        exerciseName: 'Bench Press',
        type: ExerciseType.beban,
        weightKg: 40,
        sets: 3,
        reps: 10,
        restSeconds: 90,
      );

      final map = exercise.toInsertMap(templateId: 't1', userId: 'u1', position: 2);

      expect(map['template_id'], 't1');
      expect(map['user_id'], 'u1');
      expect(map['position'], 2);
      expect(map['exercise_type'], 'beban');
      expect(map['rest_seconds'], 90);
    });
  });

  group('exportFileName', () {
    test('memuat tanggal dan jam supaya dua cadangan tidak bentrok', () {
      final name = exportFileName(DateTime(2026, 7, 31, 9, 5));
      expect(name, 'tracking-backup-2026-07-31-0905.json');
    });

    test('jam dan menit selalu dua digit', () {
      final name = exportFileName(DateTime(2026, 1, 2, 0, 0));
      expect(name, 'tracking-backup-2026-01-02-0000.json');
    });
  });
}
