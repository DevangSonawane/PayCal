import 'package:shared_preferences/shared_preferences.dart';

/// An invitation that was opened by a member who was not signed in yet.
///
/// The token is the only credential of an invitation, so it is kept until the
/// member has an account. The token is stored on the device only, and it is
/// dropped as soon as it was used or turned out to be unusable.
class PendingInvitation {
  const PendingInvitation._();

  static const _key = 'paycal_pending_invitation_v1';

  /// Remembers the token of an invitation that could not be accepted yet.
  static Future<void> store(String token) async {
    final trimmed = token.trim();
    if (trimmed.isEmpty) return;
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_key, trimmed);
  }

  /// The stored token, without consuming it.
  static Future<String?> read() async {
    final sp = await SharedPreferences.getInstance();
    final token = sp.getString(_key);
    if (token == null || token.trim().isEmpty) return null;
    return token.trim();
  }

  /// The stored token, and forgets it.
  static Future<String?> take() async {
    final token = await read();
    if (token != null) await clear();
    return token;
  }

  /// Forgets the stored token.
  static Future<void> clear() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_key);
  }
}
