import 'package:flutter/material.dart';
import 'package:paycal/app/splash_screen.dart';
import 'package:paycal/core/config/app_config.dart';
import 'package:paycal/core/settings/app_settings.dart';
import 'package:paycal/core/theme/app_theme.dart';

class PayCalApp extends StatelessWidget {
  const PayCalApp({super.key});
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppSettings.instance,
      builder: (context, _) => MaterialApp(
        title: AppConfig.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: AppSettings.instance.darkMode
            ? ThemeMode.dark
            : ThemeMode.light,
        home: const SplashScreen(),
        builder: (context, child) => child ?? const SizedBox.shrink(),
      ),
    );
  }
}
