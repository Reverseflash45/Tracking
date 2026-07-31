import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../domain/daily_nutrition.dart';
import '../domain/food_log.dart';

/// Riwayat dibatasi supaya query tidak membesar tanpa batas seiring waktu.
/// Cukup panjang untuk daftar "sering dipakai" dan rekap beberapa minggu.
const int _historyDays = 60;

class NutritionRepository {
  NutritionRepository(this._client);

  final SupabaseClient _client;

  String _sinceDate() => DateTime.now()
      .subtract(const Duration(days: _historyDays))
      .toIso8601String()
      .substring(0, 10);

  Future<List<FoodLog>> fetchFoods(String userId) async {
    final rows = await _client
        .from('food_logs')
        .select()
        .eq('user_id', userId)
        .gte('logged_on', _sinceDate())
        .order('logged_at', ascending: false);
    return (rows as List)
        .map((row) => FoodLog.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<List<WaterLog>> fetchWaters(String userId) async {
    final rows = await _client
        .from('water_logs')
        .select()
        .eq('user_id', userId)
        .gte('logged_on', _sinceDate())
        .order('logged_at', ascending: false);
    return (rows as List)
        .map((row) => WaterLog.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<void> addFood({
    required String userId,
    required FoodLog food,
    DateTime? date,
  }) {
    return _client.from('food_logs').insert(
          food.toInsertMap(userId: userId, date: date ?? DateTime.now()),
        );
  }

  Future<void> deleteFood(String id) {
    return _client.from('food_logs').delete().eq('id', id);
  }

  Future<void> addWater({
    required String userId,
    required int ml,
    DateTime? date,
  }) {
    final day = date ?? DateTime.now();
    return _client.from('water_logs').insert({
      'user_id': userId,
      'logged_on': day.toIso8601String().substring(0, 10),
      'ml': ml,
    });
  }

  Future<void> deleteWater(String id) {
    return _client.from('water_logs').delete().eq('id', id);
  }
}

final nutritionRepositoryProvider = Provider<NutritionRepository>((ref) {
  return NutritionRepository(ref.watch(supabaseClientProvider));
});

final foodLogsProvider = FutureProvider.autoDispose<List<FoodLog>>((ref) async {
  final userId = ref.watch(currentUserProvider)?.id;
  if (userId == null) return const [];
  return ref.watch(nutritionRepositoryProvider).fetchFoods(userId);
});

final waterLogsProvider = FutureProvider.autoDispose<List<WaterLog>>((ref) async {
  final userId = ref.watch(currentUserProvider)?.id;
  if (userId == null) return const [];
  return ref.watch(nutritionRepositoryProvider).fetchWaters(userId);
});

/// Asupan hari ini, dipakai halaman Nutrisi dan kartu ringkas di Dashboard.
final todayNutritionProvider = Provider.autoDispose<AsyncValue<DailyNutrition>>((ref) {
  final foods = ref.watch(foodLogsProvider);
  final waters = ref.watch(waterLogsProvider);

  final error = foods.error ?? waters.error;
  if (error != null) {
    return AsyncValue.error(
      error,
      foods.stackTrace ?? waters.stackTrace ?? StackTrace.current,
    );
  }

  final foodList = foods.value;
  final waterList = waters.value;
  if (foodList == null || waterList == null) return const AsyncValue.loading();

  return AsyncValue.data(
    nutritionForDay(date: DateTime.now(), foods: foodList, waters: waterList),
  );
});

final frequentFoodsProvider = Provider.autoDispose<AsyncValue<List<FrequentFood>>>((ref) {
  return ref.watch(foodLogsProvider).whenData(frequentFoods);
});
