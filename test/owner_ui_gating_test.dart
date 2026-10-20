import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paycal/core/widgets/primary_button.dart';
import 'package:paycal/data/in_memory_repositories.dart';
import 'package:paycal/features/cribs/crib_edit_sheet.dart';

import 'support/harness.dart';

/// The owner-only controls of the Crib editor.
///
/// The repositories refuse every owner-only operation for a member, so these
/// tests are about the interface: a member must not be offered a button that
/// is bound to fail.
void main() {
  testWidgets('the owner sees the editing controls', (tester) async {
    final world = TestHarness();
    PayCalRepositories.instance = world.repositories;
    final crib = await world.repositories.cribs.getById('c1');

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SizedBox())),
    );
    showCribEdit(tester.element(find.byType(Scaffold)), crib);
    await tester.pumpAndSettle();

    expect(find.text('Delete crib'), findsOneWidget);
    expect(find.text('Add someone'), findsOneWidget);
    expect(find.text('Share invite link'), findsOneWidget);
    expect(
      find.widgetWithText(PrimaryButton, 'Save changes'),
      findsOneWidget,
    );
  });

  testWidgets('a member does not see the owner-only controls', (tester) async {
    final world = TestHarness();
    PayCalRepositories.instance = world.repositories;
    world.signIn('a');
    final crib = await world.repositories.cribs.getById('c1');

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SizedBox())),
    );
    showCribEdit(tester.element(find.byType(Scaffold)), crib);
    await tester.pumpAndSettle();

    expect(find.text('Delete crib'), findsNothing);
    expect(find.text('Add someone'), findsNothing);
    expect(find.text('Share invite link'), findsNothing);
    expect(find.widgetWithText(PrimaryButton, 'Save changes'), findsNothing);
    expect(find.widgetWithText(PrimaryButton, 'Close'), findsOneWidget);
    // The members are still listed, so the member can see who is in the crib.
    expect(find.text('You'), findsOneWidget);
    expect(find.text('Me (owner)'), findsOneWidget);
    expect(find.text('Ravi'), findsOneWidget);
    // A member is never labelled as the owner.
    expect(find.text('You (owner)'), findsNothing);
  });

  testWidgets('the remove button of a member is owner-only', (tester) async {
    final world = TestHarness();
    PayCalRepositories.instance = world.repositories;
    world.signIn('a');
    final crib = await world.repositories.cribs.getById('c1');

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SizedBox())),
    );
    showCribEdit(tester.element(find.byType(Scaffold)), crib);
    await tester.pumpAndSettle();

    // The member rows carry no remove button for a member.
    final memberRow = find.ancestor(
      of: find.text('Ravi'),
      matching: find.byType(Row),
    );
    expect(
      find.descendant(of: memberRow, matching: find.byIcon(Icons.close_rounded)),
      findsNothing,
    );
  });
}
