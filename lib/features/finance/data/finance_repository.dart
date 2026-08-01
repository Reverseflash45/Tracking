import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/offline/local_cache.dart';
import '../../../core/offline/pending_writes.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../domain/finance_stats.dart';
import '../domain/transaction.dart';

/// Riwayat dibatasi supaya query tidak membesar tanpa batas. Cukup panjang
/// untuk menampung periode berjalan plus perbandingan beberapa bulan ke belakang.
const int _historyDays = 400;

class FinanceRepository {
  FinanceRepository(this._client, this._cache);

  final SupabaseClient _client;
  final LocalCache _cache;

  Future<List<Transaction>> fetchTransactions(String userId) async {
    final since = DateTime.now()
        .subtract(const Duration(days: _historyDays))
        .toIso8601String()
        .substring(0, 10);

    return fetchWithCache(
      cache: _cache,
      key: 'transactions_$userId',
      remote: () async =>
          ((await _client
                      .from('transactions')
                      .select()
                      .eq('user_id', userId)
                      .gte('occurred_on', since)
                      .order('occurred_on', ascending: false)
                      .order('created_at', ascending: false))
                  as List)
              .cast<Map<String, dynamic>>(),
      parse: Transaction.fromMap,
    );
  }

  Future<List<RecurringExpense>> fetchRecurring(String userId) {
    return fetchWithCache(
      cache: _cache,
      key: 'recurring_expenses_$userId',
      remote: () async =>
          ((await _client
                      .from('recurring_expenses')
                      .select()
                      .eq('user_id', userId)
                      .order('due_day'))
                  as List)
              .cast<Map<String, dynamic>>(),
      parse: RecurringExpense.fromMap,
    );
  }

  Future<void> saveRecurring(String userId, RecurringExpense expense) {
    if (expense.id.isEmpty) {
      return _client.from('recurring_expenses').insert(expense.toMap(userId));
    }
    return _client
        .from('recurring_expenses')
        .update(expense.toMap(userId))
        .eq('id', expense.id);
  }

  Future<void> deleteRecurring(String id) {
    return _client.from('recurring_expenses').delete().eq('id', id);
  }

  Future<FinanceSettings> fetchSettings(String userId) async {
    final row = await _client
        .from('finance_settings')
        .select()
        .eq('user_id', userId)
        .maybeSingle();

    if (row == null) return const FinanceSettings();
    return FinanceSettings.fromMap(row);
  }

  Future<void> saveSettings(String userId, FinanceSettings settings) {
    return _client.from('finance_settings').upsert(settings.toMap(userId));
  }

  /// Catat transaksi. Masuk antrean kalau sinyalnya sedang mati — mencatat
  /// pengeluaran justru sering dilakukan di warung yang sinyalnya jelek.
  ///
  /// Mengembalikan true kalau langsung terkirim.
  Future<bool> addTransaction(
    String userId,
    Transaction tx, {
    required PendingWriteQueue queue,
  }) {
    return queue.submit(
      table: 'transactions',
      payload: tx.toMap(userId),
      label: tx.product ?? tx.merchant ?? tx.category.label,
    );
  }

  Future<void> updateTransaction(String userId, Transaction tx) {
    return _client.from('transactions').update(tx.toMap(userId)).eq('id', tx.id);
  }

  Future<void> deleteTransaction(String id) {
    return _client.from('transactions').delete().eq('id', id);
  }
}

final financeRepositoryProvider = Provider<FinanceRepository>((ref) {
  return FinanceRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(localCacheProvider),
  );
});

final transactionsProvider = FutureProvider.autoDispose<List<Transaction>>((ref) async {
  final userId = ref.watch(currentUserProvider)?.id;
  if (userId == null) return const [];
  return ref.watch(financeRepositoryProvider).fetchTransactions(userId);
});

final financeSettingsProvider = FutureProvider.autoDispose<FinanceSettings>((ref) async {
  final userId = ref.watch(currentUserProvider)?.id;
  if (userId == null) return const FinanceSettings();
  return ref.watch(financeRepositoryProvider).fetchSettings(userId);
});

final recurringExpensesProvider =
    FutureProvider.autoDispose<List<RecurringExpense>>((ref) async {
  final userId = ref.watch(currentUserProvider)?.id;
  if (userId == null) return const [];
  return ref.watch(financeRepositoryProvider).fetchRecurring(userId);
});

/// Ringkasan periode anggaran berjalan, dipakai halaman Keuangan dan kartu
/// ringkas di Dashboard.
final financeSummaryProvider = Provider.autoDispose<AsyncValue<FinanceSummary>>((ref) {
  final transactions = ref.watch(transactionsProvider);
  final settings = ref.watch(financeSettingsProvider);

  final error = transactions.error ?? settings.error;
  if (error != null) {
    return AsyncValue.error(
      error,
      transactions.stackTrace ?? settings.stackTrace ?? StackTrace.current,
    );
  }

  final list = transactions.value;
  final config = settings.value;
  if (list == null || config == null) return const AsyncValue.loading();

  return AsyncValue.data(
    summarize(
      transactions: list,
      now: DateTime.now(),
      budget: config.monthlyBudget,
      paydayDay: config.paydayDay,
      recurring: ref.watch(recurringExpensesProvider).value ?? const [],
    ),
  );
});
