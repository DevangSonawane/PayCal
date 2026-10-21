import 'package:paycal/data/models.dart';
import 'package:paycal/data/repositories.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase-backed Crib data. This is intentionally not selected by the app
/// until the rest of the production repository bundle is ready.
class SupabaseCribRepository implements CribRepository {
  SupabaseCribRepository(this._client);
  final SupabaseClient _client;
  List<Crib> _cache = const [];

  @override
  List<Crib> get cachedCribs => List.unmodifiable(_cache);

  @override
  Future<List<Crib>> list() async {
    final rows = await _client.from('cribs').select().order('created_at');
    _cache = await Future.wait(rows.map(_map));
    return cachedCribs;
  }

  @override
  Future<Crib> getById(String id) async {
    final row = await _client.from('cribs').select().eq('id', id).maybeSingle();
    if (row == null) _notFound('Crib');
    return _map(row);
  }

  @override
  Future<Crib> create(Crib crib) async {
    final row = await _client.rpc(
      'create_crib',
      params: {
        'crib_name': crib.name,
        'crib_currency': crib.currency,
        'crib_categories': crib.categories,
      },
    );
    final result = await _map(row as Map<String, dynamic>);
    await list();
    return result;
  }

  @override
  Future<Crib> update(Crib crib) async {
    final row = await _client.rpc(
      'update_crib',
      params: {
        'target_crib_id': crib.id,
        'expected_version': crib.version,
        'crib_name': crib.name,
        'crib_currency': crib.currency,
        'crib_categories': crib.categories,
      },
    );
    final result = await _map(row as Map<String, dynamic>);
    await list();
    return result;
  }

  @override
  Future<void> delete(String id, {int? expectedVersion}) async {
    final existing = await getById(id);
    await _client.rpc(
      'delete_crib',
      params: {
        'target_crib_id': id,
        'expected_version': expectedVersion ?? existing.version,
      },
    );
    await list();
  }

  @override
  Future<Crib> addMember({
    required String cribId,
    required Member member,
  }) async {
    await _client.rpc(
      'add_crib_member',
      params: {'target_crib_id': cribId, 'member_id': member.id},
    );
    return getById(cribId);
  }

  @override
  Future<Crib> removeMember({
    required String cribId,
    required String memberId,
  }) async {
    await _client.rpc(
      'remove_crib_member',
      params: {'target_crib_id': cribId, 'member_id': memberId},
    );
    return getById(cribId);
  }

  Future<Crib> mapRow(Map<String, dynamic> row) async {
    final memberships = await _client
        .from('crib_members')
        .select('user_id, left_at, profiles(display_name)')
        .eq('crib_id', row['id']);
    final members = memberships.map((item) {
      final profile = item['profiles'] as Map<String, dynamic>?;
      final id = item['user_id'] as String;
      return Member(
        id: id,
        name: profile?['display_name'] as String? ?? 'PayCal member',
        role: id == row['owner_id'] ? MemberRole.owner : MemberRole.member,
        isActive: item['left_at'] == null,
        leftAt: item['left_at'] == null
            ? null
            : DateTime.parse(item['left_at'] as String),
      );
    }).toList();
    return Crib(
      id: row['id'] as String,
      name: row['name'] as String,
      currency: row['currency'] as String,
      categories: List<String>.from(row['categories'] as List),
      members: members,
      ownerId: row['owner_id'] as String?,
      version: row['version'] as int,
      deletedAt: row['deleted_at'] == null
          ? null
          : DateTime.parse(row['deleted_at'] as String),
    );
  }

  Future<Crib> _map(Map<String, dynamic> row) => mapRow(row);

  Never _notFound(String type) => throw RepositoryException(
    RepositoryErrorCode.notFound,
    '$type not found.',
  );
}
