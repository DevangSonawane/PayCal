import 'package:flutter/material.dart';
import 'package:paycal/core/theme/app_colors.dart';
import 'package:paycal/core/utils/deep_link.dart';
import 'package:paycal/features/onboarding/welcome_screen.dart';
import 'package:paycal/features/shell/main_shell.dart';
import 'package:paycal/features/auth/auth_identity.dart';
import 'package:paycal/data/in_memory_repositories.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const _logoAssets = [
    'assets/logo/1.png',
    'assets/logo/3.png',
    'assets/logo/5.png',
  ];

  static const _backgrounds = [AppColors.pink, AppColors.lime, AppColors.ink];

  // The supplied PNGs have different transparent padding. These values align
  // their visible artwork to the same center point inside the 220 px frame.
  static const _logoOffsets = [
    Offset(0.2, 5.7),
    Offset(1.1, -6.5),
    Offset(-1.3, 0.8),
  ];

  late final AnimationController _logoController;

  @override
  void initState() {
    super.initState();
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1650),
    )..repeat();
    Future.delayed(const Duration(milliseconds: 1200), () async {
      if (!mounted) return;
      final user = await PayCalRepositories.instance.auth.restoreSession();
      if (user != null) {
        syncAppIdentity(user);
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
      // The link that started the app is handled now, when the app is on
      // screen and the member can be asked to sign in.
      await Future<void>.delayed(const Duration(milliseconds: 600));
      await DeepLinks.deliverInitialLink();
    });
  }

  @override
  void dispose() {
    _logoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _logoController,
      builder: (context, _) {
        final segment = _logoController.value * _logoAssets.length;
        final index = segment.floor() % _logoAssets.length;
        final nextIndex = (index + 1) % _logoAssets.length;
        final segmentProgress = segment - segment.floor();
        final background = Color.lerp(
          _backgrounds[index],
          _backgrounds[nextIndex],
          Curves.easeInOut.transform(segmentProgress),
        )!;

        return Scaffold(
          backgroundColor: background,
          body: ColoredBox(
            color: background,
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, animation) =>
                    FadeTransition(opacity: animation, child: child),
                child: SizedBox(
                  key: ValueKey(_logoAssets[index]),
                  width: 220,
                  height: 220,
                  child: Transform.translate(
                    offset: _logoOffsets[index],
                    child: Image.asset(_logoAssets[index], fit: BoxFit.contain),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
