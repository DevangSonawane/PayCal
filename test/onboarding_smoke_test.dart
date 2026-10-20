import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paycal/features/auth/create_account_screen.dart';
import 'package:paycal/features/auth/sign_in_screen.dart';
import 'package:paycal/features/onboarding/invite_screen.dart';
import 'package:paycal/features/onboarding/first_batch_screen.dart';
import 'package:paycal/features/onboarding/onboarding_draft.dart';
import 'package:paycal/features/onboarding/onboarding_flow.dart';
import 'package:paycal/features/onboarding/product_tour_screen.dart';
import 'package:paycal/features/onboarding/welcome_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('welcome screen renders', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: WelcomeScreen()));
    await tester.pumpAndSettle();
    expect(find.text('PayCal'), findsOneWidget);
    expect(find.text('Get started'), findsOneWidget);
  });

  testWidgets('onboarding flow steps render', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home: OnboardingFlow()));
    await tester.pumpAndSettle();
    expect(find.text('How do you identify?'), findsOneWidget);

    await tester.tap(find.text('Woman'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('When is your birthday?'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('When is your birthday?'), findsOneWidget);

    await tester.tap(find.text('Tap to pick your date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('What brings you here?'), findsOneWidget);

    await tester.tap(find.text('Student'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('What will you split?'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('How many people split?'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();
    expect(find.text('4'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Continue with Google'), findsOneWidget);
  });

  testWidgets('product tour explains the core flow', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home: ProductTourScreen()));
    await tester.pumpAndSettle();
    expect(
      find.text('Keep every shared expense in one place.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Add it once. We split it fairly.'), findsOneWidget);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.text('How do you identify?'), findsOneWidget);
  });

  testWidgets('first batch + invite render', (tester) async {
    final draft = OnboardingDraft(
      role: 'flat',
      splitTypes: const ['rent', 'food'],
    );
    await tester.pumpWidget(MaterialApp(home: FirstBatchScreen(draft: draft)));
    await tester.pumpAndSettle();
    expect(find.text('Your first batch'), findsOneWidget);
    expect(find.text('Skip for now'), findsOneWidget);

    await tester.pumpWidget(const MaterialApp(home: InviteScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Add your people'), findsOneWidget);
    expect(find.text('Share invite link'), findsOneWidget);
  });

  testWidgets('create account + sign in render', (tester) async {
    final draft = OnboardingDraft();
    await tester.pumpWidget(
      MaterialApp(home: CreateAccountScreen(draft: draft)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Continue with Google'), findsOneWidget);

    await tester.pumpWidget(const MaterialApp(home: SignInScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
  });
}
