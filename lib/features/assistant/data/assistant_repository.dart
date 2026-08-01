import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../../academic/presentation/academic_providers.dart';
import '../../finance/data/finance_repository.dart';
import '../../nutrition/data/nutrition_repository.dart';
import '../../run/data/run_repository.dart';
import '../../workout/presentation/workout_providers.dart';
import '../domain/data_context.dart';

/// Kesalahan yang layak ditampilkan apa adanya ke user.
class AssistantException implements Exception {
  const AssistantException(this.message);
  final String message;

  @override
  String toString() => message;
}

class AssistantRepository {
  AssistantRepository(this._client);

  final SupabaseClient _client;

  /// Kirim pertanyaan beserta ringkasan data ke Edge Function.
  ///
  /// API key tidak pernah menyentuh app ini — fungsi di Supabase yang
  /// memegangnya. Kalau key-nya ada di sini, siapa pun yang membongkar APK bisa
  /// memakainya atas tagihanmu.
  Future<String> tanya({required String question, required String context}) async {
    try {
      final response = await _client.functions.invoke(
        'tanya',
        body: {'question': question, 'context': context},
      );

      final data = response.data;
      if (data is! Map) {
        throw const AssistantException('Jawaban dari server tidak dikenali.');
      }

      final error = data['error'];
      if (error is String && error.isNotEmpty) {
        throw AssistantException(error);
      }

      final answer = data['answer'];
      if (answer is! String || answer.trim().isEmpty) {
        throw const AssistantException('Server tidak mengirim jawaban.');
      }
      return answer.trim();
    } on FunctionException catch (e) {
      // 404 hampir selalu berarti fungsinya belum di-deploy — pesan bawaannya
      // tidak menjelaskan itu sama sekali.
      if (e.status == 404) {
        throw const AssistantException(
          'Fungsi "tanya" belum ada di Supabase. Jalankan '
          '"supabase functions deploy tanya" dulu.',
        );
      }
      final detail = e.details;
      if (detail is Map && detail['error'] is String) {
        throw AssistantException(detail['error'] as String);
      }
      throw AssistantException('Gagal menghubungi server (${e.status}).');
    }
  }
}

final assistantRepositoryProvider = Provider<AssistantRepository>((ref) {
  return AssistantRepository(ref.watch(supabaseClientProvider));
});

/// Ringkasan data yang dikirim bersama tiap pertanyaan.
///
/// Null selama data masih dimuat, supaya halaman tidak mengirim pertanyaan
/// dengan konteks setengah jadi dan mendapat jawaban yang salah.
final dataContextProvider = Provider.autoDispose<String?>((ref) {
  final tasks = ref.watch(tasksProvider).value;
  final sessions = ref.watch(workoutSessionsProvider).value;
  final runs = ref.watch(runsProvider).value;
  final foods = ref.watch(foodLogsProvider).value;
  final transactions = ref.watch(transactionsProvider).value;
  final finance = ref.watch(financeSummaryProvider).value;

  if (tasks == null || sessions == null || runs == null) return null;

  return buildDataContext(
    now: DateTime.now(),
    tasks: tasks,
    sessions: sessions,
    runs: runs,
    foods: foods ?? const [],
    transactions: transactions ?? const [],
    finance: finance,
  );
});
