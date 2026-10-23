import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paycal/features/onboarding/invite_screen.dart';

void main() {
  testWidgets('dialog probe', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: InviteScreen()));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Skip for now'), findsOneWidget);
    await tester.tap(find.text('Skip for now'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 200));
    // ignore: avoid_print
    print('dialogs: ${find.byType(Dialog).evaluate().length}');
    // ignore: avoid_print
    print('columns: ${find.text('You are all set!').evaluate().length}');
    await expectLater(
      find.text('You are all set!'),
      matchesGoldenFile('goldens/all_set_dialog.png'),
    );
  });
}
