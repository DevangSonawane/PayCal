import 'package:paycal/data/models.dart';
import 'package:paycal/data/repositories.dart';
import 'package:paycal/core/config/app_config.dart';
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
    try {
      final result = await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      return _required(result.user);
    } on AuthException catch (error) {
      throw _toRepositoryError(error);
    }
  }

  @override
  Future<void> signInWithGoogle() async {
    final didLaunch = await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: AppConfig.googleAuthRedirectUrl,
    );
    if (!didLaunch) {
      throw const RepositoryException(
        RepositoryErrorCode.transient,
        'Could not open the browser for Google sign-in.',
      );
    }
  }

  @override
  Future<AuthUser?> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final result = await _client.auth.signUp(
        email: email.trim(),
        password: password,
        data: {'display_name': displayName.trim()},
        // The confirmation link has to come back into the app, otherwise it
        // opens the dashboard site instead of the app.
        emailRedirectTo: AppConfig.googleAuthRedirectUrl,
      );
      return _map(result.user);
    } on AuthException catch (error) {
      throw _toRepositoryError(error);
    }
  }

  @override
  Future<void> resendConfirmation(String email) async {
    try {
      await _client.auth.resend(email: email.trim(), type: OtpType.signup);
    } on AuthException catch (error) {
      throw _toRepositoryError(error);
    }
  }

  @override
  Future<void> signOut() => _client.auth.signOut();

  @override
  Future<void> deleteAccount() async {
    try {
      final response = await _client.functions.invoke('delete-account');
      if (response.status < 200 || response.status >= 300) {
        throw RepositoryException(
          RepositoryErrorCode.conflict,
          _messageFrom(response.data) ??
              'The server refused to delete the account.',
        );
      }
    } on FunctionsHttpException catch (error) {
      throw RepositoryException(
        RepositoryErrorCode.conflict,
        _messageFrom(error.details) ??
            'The server refused to delete the account.',
      );
    } on FunctionException {
      throw const RepositoryException(
        RepositoryErrorCode.transient,
        'Could not reach the server to delete the account.',
      );
    }
    await _client.auth.signOut();
  }

  @override
  Future<void> resetPassword({required String email}) async {
    try {
      await _client.auth.resetPasswordForEmail(email.trim());
    } on AuthException catch (error) {
      throw _toRepositoryError(error);
    }
  }

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
    try {
      await _client.auth.updateUser(
        UserAttributes(email: email.trim(), data: {'display_name': displayName}),
      );
    } on AuthException catch (error) {
      throw _toRepositoryError(error);
    }
    await _client
        .from('profiles')
        .update({'display_name': displayName})
        .eq('id', user.id);
    return _required(_client.auth.currentUser);
  }

  @override
  Future<void> setPassword(String password) async {
    if (_client.auth.currentUser == null) {
      throw const RepositoryException(
        RepositoryErrorCode.unauthorized,
        'Please sign in again to set a password.',
      );
    }
    try {
      // The flag tells the app that the member can sign in with an email
      // address, so a later Google sign-in does not ask for a password again.
      await _client.auth.updateUser(
        UserAttributes(password: password, data: {'password_set': true}),
      );
    } on AuthException catch (error) {
      throw _toRepositoryError(error);
    }
  }

  @override
  Future<void> setDisplayName(String name) async {
    final displayName = name.trim();
    if (displayName.isEmpty) return;
    final user = _client.auth.currentUser;
    try {
      await _client.auth.updateUser(
        UserAttributes(data: {'display_name': displayName}),
      );
    } on AuthException catch (error) {
      throw _toRepositoryError(error);
    }
    if (user != null) {
      await _client
          .from('profiles')
          .update({'display_name': displayName})
          .eq('id', user.id);
    }
  }

  /// Turns a Supabase auth failure into a message the member can act on.
  ///
  /// The raw messages of the auth server are technical ("Invalid login
  /// credentials"), which is not what somebody who typed the wrong password
  /// needs to read.
  RepositoryException _toRepositoryError(AuthException error) {
    final code = error.code ?? error.message;
    switch (code) {
      case 'invalid_credentials':
        return const RepositoryException(
          RepositoryErrorCode.unauthorized,
          'That email and password do not match an account. Check them and try again.',
        );
      case 'email_not_confirmed':
        return const RepositoryException(
          RepositoryErrorCode.validation,
          'Confirm your email first — open the link we sent you, then come back.',
        );
      case 'user_already_exists':
      case 'email_exists':
        return const RepositoryException(
          RepositoryErrorCode.conflict,
          'An account with that email already exists. Sign in instead.',
        );
      case 'over_email_send_rate_limit':
        return const RepositoryException(
          RepositoryErrorCode.transient,
          'Too many emails requested just now. Try again in a few minutes.',
        );
      case 'over_request_rate_limit':
      case 'over_refresh_token_rate_limit':
        return const RepositoryException(
          RepositoryErrorCode.transient,
          'Too many attempts. Wait a moment and try again.',
        );
      case 'weak_password':
        return const RepositoryException(
          RepositoryErrorCode.validation,
          'That password is too weak. Use at least 8 characters.',
        );
      case 'same_password':
        return const RepositoryException(
          RepositoryErrorCode.validation,
          'That is already your password. Pick a different one.',
        );
      case 'email_address_invalid':
        return const RepositoryException(
          RepositoryErrorCode.validation,
          'That email address does not look right.',
        );
    }
    if (error.message.contains('Invalid login credentials')) {
      return const RepositoryException(
        RepositoryErrorCode.unauthorized,
        'That email and password do not match an account. Check them and try again.',
      );
    }
    if (error.message.contains('already registered')) {
      return const RepositoryException(
        RepositoryErrorCode.conflict,
        'An account with that email already exists. Sign in instead.',
      );
    }
    if (error.message.contains('Email not confirmed')) {
      return const RepositoryException(
        RepositoryErrorCode.validation,
        'Confirm your email first — open the link we sent you, then come back.',
      );
    }
    return RepositoryException(RepositoryErrorCode.transient, error.message);
  }

  /// Pulls the `error` field out of an edge function response body.
  String? _messageFrom(dynamic details) {
    if (details is Map) {
      final value = details['error'];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    if (details is String && details.trim().isNotEmpty) return details.trim();
    return null;
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
          hasPassword: _hasPassword(user),
        );

  /// Whether the account can sign in with an email address and a password.
  ///
  /// An account that came from Google has no password. Once the member sets
  /// one, the flag in the metadata remembers it.
  bool _hasPassword(User user) {
    if (user.userMetadata?['password_set'] == true) return true;
    return user.identities?.any((identity) => identity.provider == 'email') ??
        false;
  }
}
