import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:paycal/core/config/app_config.dart';
import 'package:paycal/core/settings/app_settings.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Registers this installation with the backend. Notification delivery itself
/// happens only in the server-side Edge Function; FCM credentials never ship
/// in the app.
class PushNotificationService {
  PushNotificationService._();
  static final instance = PushNotificationService._();

  SupabaseClient? _client;
  StreamSubscription<String>? _tokenRefresh;
  StreamSubscription<AuthState>? _authChanges;
  bool _ready = false;

  Future<void> initialize(SupabaseClient client) async {
    if (_ready || !AppConfig.firebasePushEnabled || kIsWeb) return;
    _client = client;
    try {
      await Firebase.initializeApp();
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
            alert: true,
            badge: true,
            sound: true,
          );
      _tokenRefresh = FirebaseMessaging.instance.onTokenRefresh.listen(
        (_) => unawaited(_syncToken()),
      );
      _authChanges = client.auth.onAuthStateChange.listen((_) {
        unawaited(_syncToken());
      });
      _ready = true;
      await _syncToken(requestPermission: false);
    } on FirebaseException catch (error) {
      // Missing platform configuration is expected until Firebase is linked.
      debugPrint('Push notifications unavailable: ${error.code}');
    }
  }

  Future<void> requestPermissionAndEnable() async {
    AppSettings.instance.update(notificationsOn: true);
    await _syncToken(requestPermission: true);
  }

  Future<void> setEnabled(bool enabled) async {
    AppSettings.instance.update(notificationsOn: enabled);
    if (!_ready) return;
    await _syncToken(requestPermission: enabled);
  }

  Future<void> _syncToken({bool requestPermission = false}) async {
    final client = _client;
    if (!_ready || client == null || client.auth.currentUser == null) return;

    if (requestPermission) {
      final permission = await FirebaseMessaging.instance.requestPermission();
      if (permission.authorizationStatus == AuthorizationStatus.denied) {
        AppSettings.instance.update(notificationsOn: false);
        return;
      }
    }
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) return;
    await client.rpc(
      'register_push_device',
      params: {
        'device_token': token,
        'device_platform': Platform.isIOS ? 'ios' : 'android',
        'delivery_enabled': AppSettings.instance.notificationsOn,
      },
    );
  }

  Future<void> dispose() async {
    await _tokenRefresh?.cancel();
    await _authChanges?.cancel();
  }
}
