import 'dart:math';

import 'package:paycal/core/notifications/notification_dispatcher.dart';
import 'package:paycal/data/models.dart';
import 'package:paycal/data/repositories.dart';
import 'package:paycal/data/supabase_crib_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseInvitationRepository implements InvitationRepository {
  SupabaseInvitationRepository(this._client, this._cribs);
  final SupabaseClient _client;
  final SupabaseCribRepository _cribs;

  @override
  Future<Invitation> create({
    required String cribId,
    required String createdById,
    required DateTime expiresAt,
  }) async {
    final token = _token();
    final row = await _client.rpc(
      'create_invitation',
      params: {
        'target_crib_id': cribId,
        'invitation_token': token,
        'invitation_expires_at': expiresAt.toUtc().toIso8601String(),
      },
    );
    return _map(row as Map<String, dynamic>, token: token);
  }

  @override
  Future<Invitation> getById(String id) async => _findVisible(id);

  @override
  Future<List<Invitation>> list({String? cribId}) async {
    var query = _client.from('invitations').select();
    if (cribId != null) query = query.eq('crib_id', cribId);
    final rows = await query.order('created_at', ascending: false);
    return rows.map((row) => _map(row)).toList(growable: false);
  }

  @override
  Future<Invitation> validate(String token) async {
    // The raw token is deliberately never queryable; acceptance performs the
    // hash lookup atomically on the server.
    if (token.length < 16) {
      throw const RepositoryException(
        RepositoryErrorCode.validation,
        'Invalid invitation link.',
      );
    }
    return Invitation(
      id: token,
      cribId: '',
      createdById: '',
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(days: 1)),
    );
  }

  @override
  Future<Crib> accept(String token) async {
    final Map<String, dynamic> row;
    try {
      final result = await _client.rpc(
        'accept_invitation',
        params: {'invitation_token': token},
      );
      row = result as Map<String, dynamic>;
    } on PostgrestException catch (error) {
      // The server refuses a revoked, expired or already used token with a
      // permission error. That is a dead invitation, not a broken app.
      if (error.code == '42501') {
        throw const RepositoryException(
          RepositoryErrorCode.unauthorized,
          'That invitation is invalid, expired, or unavailable',
        );
      }
      throw const RepositoryException(
        RepositoryErrorCode.transient,
        'Could not reach the server to join the crib.',
      );
    }
    final crib = await _cribs.mapRow(row);
    // The signed-in member is a member of the crib now, so the cached cribs
    // have to be refreshed: the member list is read from the cache and the
    // new member would stay invisible everywhere else.
    await _cribs.list();
    // The crib owner gets a "new member" notification; the device that
    // accepted the invitation asks for it to go out right away.
    await NotificationDispatcher.instance.dispatchNow(_client);
    return crib;
  }

  @override
  Future<void> revoke(String id) =>
      _client.rpc('revoke_invitation', params: {'target_invitation_id': id});

  Future<Invitation> _findVisible(String id) async {
    final row = await _client
        .from('invitations')
        .select()
        .eq('id', id)
        .maybeSingle();
    if (row == null) {
      throw const RepositoryException(
        RepositoryErrorCode.notFound,
        'Invitation not found.',
      );
    }
    return _map(row);
  }

  Invitation _map(Map<String, dynamic> row, {String? token}) => Invitation(
    id: row['id'] as String,
    cribId: row['crib_id'] as String,
    createdById: row['created_by'] as String,
    createdAt: DateTime.parse(row['created_at'] as String),
    expiresAt: DateTime.parse(row['expires_at'] as String),
    revoked: row['revoked_at'] != null,
    acceptedById: row['accepted_by'] as String?,
    acceptedAt: row['accepted_at'] == null
        ? null
        : DateTime.parse(row['accepted_at'] as String),
    secretToken: token,
  );

  String _token() {
    const alphabet =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    return List.generate(
      48,
      (_) => alphabet[random.nextInt(alphabet.length)],
    ).join();
  }
}
