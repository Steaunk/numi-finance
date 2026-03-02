import 'dart:convert';
import 'package:drift/drift.dart';
import '../../models/expense.dart' as model;
import '../../utils/currency_utils.dart';
import '../local/database.dart';
import '../remote/endpoints/expense_api.dart';

class ExpenseRepository {
  final AppDatabase _db;
  final ExpenseApi? _api;

  ExpenseRepository(this._db, this._api);

  Stream<List<model.Expense>> watchByMonth(int year, int month) {
    return _db.expenseDao.watchByMonth(year, month).map(
          (rows) => rows.map(_rowToModel).toList(),
        );
  }

  Future<List<String>> getCategories() =>
      _db.expenseDao.getDistinctCategories();

  Future<Map<String, Map<String, double>>> getMonthlyStats({
    int? year,
    required String displayCurrency,
  }) async {
    final rows = await _db.expenseDao.getAll(year: year);
    final result = <String, Map<String, double>>{};
    for (final row in rows) {
      final monthKey =
          '${row.date.year}-${row.date.month.toString().padLeft(2, '0')}';
      final amount = CurrencyUtils.getDisplayAmount(
        displayCurrency: displayCurrency,
        amountUsd: row.amountUsd,
        amountCny: row.amountCny,
        amountHkd: row.amountHkd,
        amountSgd: row.amountSgd,
        originalAmount: row.amount,
        originalCurrency: row.currency,
      );
      result.putIfAbsent(monthKey, () => {});
      result[monthKey]!.update(
        row.category,
        (v) => v + amount,
        ifAbsent: () => amount,
      );
    }
    return result;
  }

  Future<void> addExpense({
    required double amount,
    required String currency,
    required DateTime date,
    required String category,
    required String name,
    String notes = '',
  }) async {
    final rates = await _getCachedRates();
    final computed = CurrencyUtils.computeAmounts(amount, currency, rates);

    final companion = ExpensesCompanion.insert(
      amount: amount,
      currency: currency,
      date: date,
      category: category,
      name: name,
      notes: Value(notes),
      amountUsd: Value(computed['amount_usd']!),
      amountCny: Value(computed['amount_cny']!),
      amountHkd: Value(computed['amount_hkd']!),
      amountSgd: Value(computed['amount_sgd']!),
      createdAt: Value(DateTime.now()),
    );
    final localId = await _db.expenseDao.insertRow(companion);

    final api = _api;
    if (api != null) {
      try {
        final remote = await api.addExpense({
          'amount': amount,
          'currency': currency,
          'date': '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
          'category': category,
          'name': name,
          'notes': notes,
        });
        await _db.expenseDao.markSynced(localId, remote['id'] as int);
      } catch (_) {
        await _db.syncQueueDao.enqueue(
          SyncQueueCompanion.insert(
            entityType: 'expense',
            operation: 'create',
            localId: localId,
            payload: jsonEncode({
              'amount': amount,
              'currency': currency,
              'date': date.toIso8601String(),
              'category': category,
              'name': name,
              'notes': notes,
            }),
            createdAt: Value(DateTime.now()),
          ),
        );
      }
    }
  }

  Future<void> deleteExpense(int localId) async {
    final row = await (_db.select(_db.expenses)
          ..where((e) => e.id.equals(localId)))
        .getSingleOrNull();
    await _db.expenseDao.removeById(localId);

    final api = _api;
    if (api != null && row?.remoteId != null) {
      try {
        await api.deleteExpense(row!.remoteId!);
      } catch (_) {
        await _db.syncQueueDao.enqueue(
          SyncQueueCompanion.insert(
            entityType: 'expense',
            operation: 'delete',
            localId: localId,
            payload: jsonEncode({'remote_id': row!.remoteId}),
            createdAt: Value(DateTime.now()),
          ),
        );
      }
    }
  }

  Future<void> syncFromServer(String currency) async {
    final api = _api;
    if (api == null) return;
    try {
      final now = DateTime.now();
      for (var i = 0; i < 12; i++) {
        var month = now.month - i;
        var year = now.year;
        while (month <= 0) {
          month += 12;
          year -= 1;
        }
        final monthStr =
            '$year-${month.toString().padLeft(2, '0')}';
        final expenses = await api.getExpenses(
          month: monthStr,
          currency: currency,
        );
        for (final e in expenses) {
          final date = DateTime.parse(e['date'] as String);
          await _db.expenseDao.upsertByRemoteId(
            ExpensesCompanion(
              remoteId: Value(e['id'] as int),
              amount: Value((e['amount'] as num).toDouble()),
              currency: Value(e['currency'] as String),
              date: Value(date),
              category: Value(e['category'] as String),
              name: Value(e['name'] as String),
              notes: Value(e['notes'] as String? ?? ''),
              amountUsd: Value((e['amount_usd'] as num?)?.toDouble() ?? 0),
              amountCny: Value((e['amount_cny'] as num?)?.toDouble() ?? 0),
              amountHkd: Value((e['amount_hkd'] as num?)?.toDouble() ?? 0),
              amountSgd: Value((e['amount_sgd'] as num?)?.toDouble() ?? 0),
              synced: const Value(true),
            ),
          );
        }
      }
    } catch (_) {}
  }

  Future<Map<String, double>> _getCachedRates() async {
    final rate = await _db.exchangeRateDao.getLatest();
    if (rate != null) {
      return {'cny': rate.cny, 'hkd': rate.hkd, 'sgd': rate.sgd, 'jpy': rate.jpy};
    }
    // Fallback
    return {'cny': 7.25, 'hkd': 7.82, 'sgd': 1.34, 'jpy': 150.0};
  }

  model.Expense _rowToModel(DbExpense row) => model.Expense(
        id: row.id,
        remoteId: row.remoteId,
        amount: row.amount,
        currency: row.currency,
        date: row.date,
        category: row.category,
        name: row.name,
        notes: row.notes,
        amountUsd: row.amountUsd,
        amountCny: row.amountCny,
        amountHkd: row.amountHkd,
        amountSgd: row.amountSgd,
        createdAt: row.createdAt,
        synced: row.synced,
      );
}
