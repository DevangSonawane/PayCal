import 'package:flutter/material.dart';
import 'package:paycal/app/paycal_app.dart';
import 'package:paycal/core/settings/app_settings.dart';
import 'package:paycal/core/config/app_config.dart';
import 'package:paycal/core/notifications/push_notification_service.dart';
import 'package:paycal/data/in_memory_repositories.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppSettings.instance.load();
  if (AppConfig.hasSupabaseConfiguration) {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabasePublishableKey,
    );
    PayCalRepositories.instance = PayCalRepositories.supabase(
      Supabase.instance.client,
    );
    await PushNotificationService.instance.initialize(Supabase.instance.client);
  }
  runApp(const PayCalApp());
}
