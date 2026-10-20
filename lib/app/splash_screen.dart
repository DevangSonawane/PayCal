import 'package:flutter/material.dart';
import 'package:paycal/core/config/app_config.dart';
import 'package:paycal/core/theme/app_colors.dart';
import 'package:paycal/core/theme/app_spacing.dart';
import 'package:paycal/core/theme/app_typography.dart';
import 'package:paycal/core/widgets/pinstripe_rules.dart';
import 'package:paycal/core/widgets/wedge_loader.dart';
import 'package:paycal/features/onboarding/welcome_screen.dart';
import 'package:paycal/features/shell/main_shell.dart';
import 'package:paycal/data/in_memory_repositories.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 900), () async {
      if (!mounted) return;
      final user = await PayCalRepositories.instance.auth.restoreSession();
      if (user != null) {
        try {
          await PayCalRepositories.instance.hydrate();
        } catch (_) {
          // The shell remains usable and exposes retry paths if the network
          // is temporarily unavailable during launch.
        }
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) =>
              user == null ? const WelcomeScreen() : const MainShell(),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.current.page,
      body: CustomPaint(
        painter: const PinstripePainter(),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppPalette.current.ink,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.bolt_rounded,
                  color: AppPalette.current.lime,
                  size: 28,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Transform.rotate(
                angle: -0.04,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: AppPalette.current.lime,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppPalette.current.ink,
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    AppConfig.appName,
                    style: AppTypography.title.copyWith(
                      color: AppPalette.current.ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              const WedgeLoader(size: 26),
            ],
          ),
        ),
      ),
    );
  }
}
