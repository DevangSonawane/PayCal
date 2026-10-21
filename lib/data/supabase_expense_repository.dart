import 'package:paycal/core/notifications/notification_dispatcher.dart';
import 'package:paycal/data/models.dart';
import 'package:paycal/data/repositories.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseExpenseRepository implements ExpenseRepository {
  SupabaseExpenseRepository(this._client);
  final SupabaseClient _client;
  List<Expense> _cache = const [];

  @override
  List<Expense> get cachedExpenses => List.unmodifiable(_cache);

  @override
  Future<List<Expense>> list({required String cribId}) async {
    final rows = await _client
        .from('expenses')
        .select('*, expense_shares(user_id, share_minor)')
        .eq('crib_id', cribId)
        .order('occurred_on', ascending: false)
        .order('created_at', ascending: false);
    final forCrib = rows.map(_map).toList(growable: false);
    _cache = [
      ..._cache.where((expense) => expense.cribId != cribId),
      ...forCrib,
    ];
    return cachedExpenses;
  }

  @override
  Future<Expense> getById(String id) async {
    final row = await _client
        .from('expenses')
        .select('*, expense_shares(user_id, share_minor)')
        .eq('id', id)
        .maybeSingle();
    if (row == null) _notFound();
    return _map(row);
  }

  @override
  Future<Expense> create(Expense expense) async {
    final row = await _client.rpc(
      'create_expense',
      params: {
        'target_crib_id': expense.cribId,
        'expense_description': expense.description,
        'expense_total_minor': expense.totalMinor,
        'expense_currency': expense.currency,
        'expense_category': expense.category,
        'expense_occurred_on': _date(expense.date),
        'expense_shares': [
          for (final entry in expense.shares.entries)
            {'user_id': entry.key, 'share_minor': entry.value},
        ],
      },
    );
    final result = await getById((row as Map<String, dynamic>)['id'] as String);
    await list(cribId: expense.cribId);
    // The other members hear about the expense right away instead of with
    // the next sweep of the scheduler.
    await NotificationDispatcher.instance.dispatchNow(_client);
    return result;
  }

  @override
  Future<Expense> update(Expense expense) async {
    final row = await _client.rpc(
      'update_expense',
      params: {
        'target_expense_id': expense.id,
        'expected_version': expense.version,
        'expense_description': expense.description,
        'expense_category': expense.category,
        'expense_occurred_on': _date(expense.date),
      },
    );
    final result = await getById((row as Map<String, dynamic>)['id'] as String);
    await list(cribId: result.cribId);
    await NotificationDispatcher.instance.dispatchNow(_client);
    return result;
  }

  @override
  Future<Expense> flagDispute(String id) async {
    final row = await _client.rpc(
      'flag_expense_dispute',
      params: {'target_expense_id': id},
    );
    final result = await getById((row as Map<String, dynamic>)['id'] as String);
    await list(cribId: result.cribId);
    return result;
  }

  @override
  Future<void> delete(String id, {int? expectedVersion}) async {
    final existing = await getById(id);
    await _client.rpc(
      'delete_expense',
      params: {
        'target_expense_id': id,
        'expected_version': expectedVersion ?? existing.version,
      },
    );
    await list(cribId: existing.cribId);
  }

  Expense _map(Map<String, dynamic> row) => Expense(
    id: row['id'] as String,
    cribId: row['crib_id'] as String,
    description: row['description'] as String,
    totalMinor: (row['total_minor'] as num).toInt(),
    currency: row['currency'] as String,
    payerId: row['payer_id'] as String,
    createdById: row['created_by'] as String?,
    shares: {
      for (final share in row['expense_shares'] as List<dynamic>)
        (share as Map<String, dynamic>)['user_id'] as String:
            ((share)['share_minor'] as num).toInt(),
    },
    date: DateTime.parse(row['occurred_on'] as String),
    category: row['category'] as String,
    disputed: row['disputed_at'] != null,
    unpaid: row['unpaid'] as bool? ?? false,
    version: (row['version'] as num).toInt(),
  );

  String _date(DateTime value) => value.toIso8601String().substring(0, 10);

  Never _notFound() => throw const RepositoryException(
    RepositoryErrorCode.notFound,
    'Expense not found.',
  );
}
