import 'package:flutter/material.dart';
import 'package:paycal/app/splash_screen.dart';
import 'package:paycal/core/config/app_config.dart';
import 'package:paycal/core/theme/app_theme.dart';

class PayCalApp extends StatelessWidget {
  const PayCalApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const SplashScreen(),
    );
  }
}
