import 'package:flutter/material.dart';
import 'package:paycal/app/paycal_app.dart';
import 'package:paycal/core/settings/app_settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppSettings.instance.load();
  runApp(const PayCalApp());
}
