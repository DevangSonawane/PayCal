import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paycal/features/auth/create_account_screen.dart';
import 'package:paycal/features/onboarding/onboarding_draft.dart';

void main() {
  testWidgets('continue with email path', (tester) async {
    final draft = OnboardingDraft();
    await tester.pumpWidget(
      MaterialApp(home: CreateAccountScreen(draft: draft)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue with email'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    // ignore: avoid_print
    print('TEXT FOUND: ${find.byType(Text).evaluate().map((e) => (e.widget as Text).data).whereType<String>().toList()}');
  });
}
