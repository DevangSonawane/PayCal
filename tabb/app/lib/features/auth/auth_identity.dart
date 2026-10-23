import 'package:paycal/core/settings/app_settings.dart';
import 'package:paycal/data/models.dart';

/// Copies the signed-in member into the local settings.
///
/// The profile card reads the name and the email from [AppSettings], so the
/// identity of the account that just signed in has to be written there. An
/// empty name is ignored by [AppSettings.update], which keeps the previous
/// name when the account carries none.
void syncAppIdentity(AuthUser? user) {
  if (user == null) return;
  AppSettings.instance.update(userName: user.name, userEmail: user.email);
}
