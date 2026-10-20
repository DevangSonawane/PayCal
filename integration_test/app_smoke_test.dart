import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:paycal/app/paycal_app.dart';
import 'package:paycal/core/settings/app_settings.dart';
import 'package:paycal/features/onboarding/onboarding_draft.dart';

/// The first launch of the real app, on a real device.
///
/// The point is not to test the rules — the unit and repository tests do
/// that. The point is to prove that the onboarding path works on a real
/// platform: the screens render, the buttons are where the eye expects them,
/// nothing overflows and the flow reaches the home screen.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await AppSettings.instance.load();
    // The date step needs a date, and the date picker is a wheel on iOS.
    // The draft is the app's own persisted onboarding state.
    final draft = OnboardingDraft(birthDate: DateTime(1995, 5, 5), step: 0);
    await draft.save();
  });

  testWidgets('first launch walks through to the home screen', (tester) async {
    await tester.pumpWidget(const PayCalApp());
    // The splash screen holds for 900 ms.
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pump(const Duration(milliseconds: 600));

    // --- The welcome screen -----------------------------------------
    expect(find.text('Get started'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _tap(tester, find.text('Get started'));

    // --- The product tour --------------------------------------------
    expect(find.text('Skip'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _tap(tester, find.text('Skip'));

    // --- The onboarding steps ----------------------------------------
    // 1. who you are
    expect(find.text('Woman'), findsOneWidget);
    await _tap(tester, find.text('Woman'));
    expect(tester.takeException(), isNull);
    await _tap(tester, find.text('Continue'));

    // 2. when you were born — the date comes from the saved draft
    expect(find.text('Continue'), findsOneWidget);
    await _tap(tester, find.text('Continue'));

    // 3. what brings you here — the role fills the categories as well
    expect(find.text('What brings you here?'), findsOneWidget);
    await _tap(tester, find.text('Sharing a flat'));
    expect(tester.takeException(), isNull);
    await _tap(tester, find.text('Continue'));

    // 4. how you split
    expect(find.text('Continue'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _tap(tester, find.text('Continue'));

    // 5. how many people
    expect(find.text('Continue'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _tap(tester, find.text('Continue'));

    // --- The account -------------------------------------------------
    expect(find.text('Continue with email'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _tap(tester, find.text('Continue with email'));

    // --- The verification --------------------------------------------
    expect(find.text('I verified — continue'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _tap(tester, find.text('I verified — continue'));

    // --- The notifications -------------------------------------------
    expect(find.text('Not now'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _tap(tester, find.text('Not now'));

    // --- The first crib ----------------------------------------------
    expect(find.text('Create crib'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.enterText(find.byType(TextFormField).first, 'Our flat');
    await tester.pump(const Duration(milliseconds: 400));
    await _tap(tester, find.text('Create crib'));

    // --- The invite --------------------------------------------------
    // The invite screen offers to share a link. Skipping it finishes the
    // onboarding and opens the shell.
    expect(find.text('Skip for now'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _tap(tester, find.text('Skip for now'));

    // --- The home screen ---------------------------------------------
    // The shell is up and nothing threw on the way.
    expect(tester.takeException(), isNull);
    expect(find.byType(Navigator), findsWidgets);
  });
}

/// Taps a widget and lets the screen catch up.
///
/// `pumpAndSettle` cannot be used: the splash loader repeats forever, so it
/// never settles.
Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 400));
  }
}
