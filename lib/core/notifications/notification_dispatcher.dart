import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Asks the backend to deliver the transactional notifications right away.
///
/// The scheduler sweeps the outbox every few minutes. That is the right pace
/// for a recurring reminder, but a member who just added an expense should
/// not wait for it: the app of the member who did something asks for the
/// transactional notifications to go out now, and the other members get them
/// within seconds.
///
/// The call never blocks the write it follows and never fails it. A member
/// without a working network still sees the expense; the notification simply
/// arrives with the next sweep.
class NotificationDispatcher {
  NotificationDispatcher._();
  static final NotificationDispatcher instance = NotificationDispatcher._();

  bool _running = false;

  Future<void> dispatchNow(SupabaseClient client) async {
    if (_running) return;
    _running = true;
    try {
      await client.functions.invoke('dispatch-notifications');
    } catch (error) {
      debugPrint('Immediate notification dispatch failed: $error');
    } finally {
      _running = false;
    }
  }
}
