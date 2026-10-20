import 'package:flutter/material.dart';
import 'package:paycal/app/paycal_app.dart';
import 'package:paycal/core/settings/app_settings.dart';
import 'package:paycal/core/config/app_config.dart';
import 'package:paycal/data/in_memory_repositories.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (AppConfig.hasSupabaseConfiguration) {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabasePublishableKey,
    );
    PayCalRepositories.instance = PayCalRepositories.supabase(
      Supabase.instance.client,
    );
  }
  await AppSettings.instance.load();
  runApp(const PayCalApp());
}
