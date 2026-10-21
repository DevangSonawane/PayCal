import 'package:paycal/data/models.dart';
import 'package:paycal/data/repositories.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseSettlementRepository implements SettlementRepository {
  SupabaseSettlementRepository(this._client);
  final SupabaseClient _client;
  List<Settlement> _cache = const [];

  @override
  List<Settlement> get cachedSettlements => List.unmodifiable(_cache);

  @override
  Future<List<Settlement>> list({required String cribId}) async {
    final rows = await _client
        .from('settlements')
        .select()
        .eq('crib_id', cribId)
        .order('created_at', ascending: false);
    final values = rows.map(_map).toList(growable: false);
    _cache = [..._cache.where((item) => item.cribId != cribId), ...values];
    return cachedSettlements;
  }

  @override
  Future<Settlement> create(Settlement settlement) async {
    final row = await _client.rpc(
      'create_settlement',
      params: {
        'target_crib_id': settlement.cribId,
        'recipient_id': settlement.toMemberId,
        'settlement_amount_minor': settlement.amountMinor,
        'settlement_currency': settlement.currency,
        'settlement_status': settlement.status.name,
        'settlement_idempotency_key':
            settlement.idempotencyKey ?? settlement.id,
      },
    );
    final result = _map(row as Map<String, dynamic>);
    await list(cribId: result.cribId);
    return result;
  }

  @override
  Future<Settlement> updateStatus(
    String id,
    SettlementStatus status, {
    int? expectedVersion,
  }) async {
    final current = _cache.where((item) => item.id == id).firstOrNull;
    if (current == null) {
      throw const RepositoryException(
        RepositoryErrorCode.notFound,
        'Settlement not found.',
      );
    }
    final row = await _client.rpc(
      'update_settlement_status',
      params: {
        'target_settlement_id': id,
        'expected_version': expectedVersion ?? current.version,
        'next_status': status.name,
      },
    );
    final result = _map(row as Map<String, dynamic>);
    await list(cribId: result.cribId);
    return result;
  }

  Settlement _map(Map<String, dynamic> row) => Settlement(
    id: row['id'] as String,
    cribId: row['crib_id'] as String,
    currency: row['currency'] as String,
    fromMemberId: row['from_user_id'] as String,
    toMemberId: row['to_user_id'] as String,
    amountMinor: (row['amount_minor'] as num).toInt(),
    status: SettlementStatus.values.byName(row['status'] as String),
    createdAt: DateTime.parse(row['created_at'] as String),
    idempotencyKey: row['idempotency_key'] as String?,
    version: (row['version'] as num).toInt(),
  );
}
