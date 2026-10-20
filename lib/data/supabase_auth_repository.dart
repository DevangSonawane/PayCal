import 'package:paycal/data/models.dart';
import 'package:paycal/data/repositories.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);
  final SupabaseClient _client;

  @override
  AuthUser? get currentUser => _map(_client.auth.currentUser);

  @override
  Future<AuthUser?> restoreSession() async => currentUser;

  @override
  Future<AuthUser> signIn({
    required String email,
    required String password,
  }) async {
    final result = await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
    return _required(result.user);
  }

  @override
  Future<AuthUser?> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final result = await _client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {'display_name': displayName.trim()},
    );
    return _map(result.user);
  }

  @override
  Future<void> signOut() => _client.auth.signOut();

  @override
  Future<void> deleteAccount() async {
    await _client.functions.invoke('delete-account');
    await _client.auth.signOut();
  }

  @override
  Future<void> resetPassword({required String email}) =>
      _client.auth.resetPasswordForEmail(email.trim());

  @override
  Future<AuthUser> updateProfile({
    required String name,
    required String email,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const RepositoryException(
        RepositoryErrorCode.unauthorized,
        'Please sign in again to update your profile.',
      );
    }
    final displayName = name.trim();
    await _client.auth.updateUser(
      UserAttributes(email: email.trim(), data: {'display_name': displayName}),
    );
    await _client
        .from('profiles')
        .update({'display_name': displayName})
        .eq('id', user.id);
    return _required(_client.auth.currentUser);
  }

  AuthUser _required(User? user) =>
      _map(user) ??
      (throw const RepositoryException(
        RepositoryErrorCode.unauthorized,
        'No authenticated user returned.',
      ));
  AuthUser? _map(User? user) => user == null
      ? null
      : AuthUser(
          id: user.id,
          name:
              (user.userMetadata?['display_name'] as String?)
                      ?.trim()
                      .isNotEmpty ==
                  true
              ? user.userMetadata!['display_name'] as String
              : user.email?.split('@').first ?? 'PayCal member',
          email: user.email ?? '',
        );
}
