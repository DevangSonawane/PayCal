import 'package:flutter/material.dart';
import 'package:paycal/app/splash_screen.dart';
import 'package:paycal/core/config/app_config.dart';
import 'package:paycal/core/settings/app_settings.dart';
import 'package:paycal/core/theme/app_theme.dart';
import 'package:paycal/core/utils/deep_link.dart';

class PayCalApp extends StatefulWidget {
  const PayCalApp({super.key});

  @override
  State<PayCalApp> createState() => _PayCalAppState();
}

class _PayCalAppState extends State<PayCalApp> {
  @override
  void initState() {
    super.initState();
    // The links are handled app wide: a link can arrive on the welcome
    // screen, in the middle of the onboarding or inside a crib.
    DeepLinks.listen();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppSettings.instance,
      builder: (context, _) => MaterialApp(
        title: AppConfig.appName,
        debugShowCheckedModeBanner: false,
        navigatorKey: DeepLinks.navigatorKey,
        theme: AppTheme.light(),
        themeMode: ThemeMode.light,
        home: const SplashScreen(),
        builder: (context, child) => child ?? const SizedBox.shrink(),
      ),
    );
  }
}
