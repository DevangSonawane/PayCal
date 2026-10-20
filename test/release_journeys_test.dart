import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paycal/core/widgets/primary_button.dart';
import 'package:paycal/data/in_memory_repositories.dart';
import 'package:paycal/data/models.dart';
import 'package:paycal/features/cribs/crib_detail_screen.dart';
import 'package:paycal/features/cribs/crib_edit_sheet.dart';

import 'support/harness.dart';

/// Opens the group details sheet, where the recurring transfers live.
Future<void> _openGroupDetails(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.more_horiz));
  await tester.pumpAndSettle();
  await tester.tap(find.text('View group details'));
  await tester.pumpAndSettle();
}

/// The release journeys that have to work for the owner and for a member.
void main() {
  testWidgets('deleting a crib asks for a confirmation first', (tester) async {
    final world = TestHarness();
    PayCalRepositories.instance = world.repositories;
    final crib = await world.repositories.cribs.getById('c1');

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SizedBox())),
    );
    showCribEdit(tester.element(find.byType(Scaffold)), crib);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Delete crib'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete crib'));
    await tester.pumpAndSettle();

    // The confirmation is shown, and nothing is deleted yet.
    expect(find.text('Delete "Flat"?'), findsOneWidget);
    expect(world.store.cribs, hasLength(1));
  });

  testWidgets('cancelling the confirmation keeps the crib', (tester) async {
    final world = TestHarness();
    PayCalRepositories.instance = world.repositories;
    final crib = await world.repositories.cribs.getById('c1');

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SizedBox())),
    );
    showCribEdit(tester.element(find.byType(Scaffold)), crib);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Delete crib'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete crib'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(world.store.cribs, hasLength(1));
  });

  testWidgets('confirming the deletion removes the crib and keeps the history',
      (tester) async {
    final world = TestHarness(
      expenses: [
        Expense(
          id: 'e1',
          cribId: 'c1',
          description: 'Dinner',
          totalMinor: 1000,
          currency: 'INR',
          payerId: 'me',
          shares: {'me': 500, 'a': 500},
          date: DateTime(2026),
          category: 'other',
        ),
      ],
    );
    PayCalRepositories.instance = world.repositories;
    final crib = await world.repositories.cribs.getById('c1');

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SizedBox())),
    );
    showCribEdit(tester.element(find.byType(Scaffold)), crib);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Delete crib'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete crib'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(PrimaryButton, 'Delete'));
    await tester.pumpAndSettle();

    // The crib is gone for the members, the financial history stays and
    // still points at a crib that exists.
    expect(world.repositories.cribs.cachedCribs, isEmpty);
    expect(world.store.cribs.single.isDeleted, isTrue);
    expect(world.store.expenses, hasLength(1));
    expect(world.store.expenses.single.cribId, 'c1');
  });

  testWidgets('the owner sees the recurring controls and a member does not',
      (tester) async {
    final world = TestHarness();
    PayCalRepositories.instance = world.repositories;
    final crib = await world.repositories.cribs.getById('c1');
    await world.repositories.recurring.create(
      RecurringPayment(
        id: 'r1',
        cribId: 'c1',
        description: 'Pocket money',
        amountMinor: 50000,
        currency: 'INR',
        category: 'other',
        frequency: RecurringFrequency.monthly,
        recipientId: 'r',
        createdById: 'me',
        startDate: DateTime(2026, 1, 31, 9),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(home: CribDetailScreen(crib: crib)),
    );
    await tester.pumpAndSettle();
    await _openGroupDetails(tester);

    // The owner gets the edit, the payer and the cancel button.
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    expect(find.byIcon(Icons.person_pin_circle_outlined), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);

    // A member gets none of them.
    // Close the group details sheet first, it covers the menu.
    Navigator.of(tester.element(find.byType(CribDetailScreen))).pop();
    await tester.pumpAndSettle();
    world.signIn('a');
    await tester.pumpWidget(
      MaterialApp(home: CribDetailScreen(crib: crib)),
    );
    await tester.pumpAndSettle();
    await _openGroupDetails(tester);

    expect(find.byIcon(Icons.edit_outlined), findsNothing);
    expect(find.byIcon(Icons.person_pin_circle_outlined), findsNothing);
    expect(find.byIcon(Icons.delete_outline_rounded), findsNothing);
  });

  testWidgets('a member does not get the recurring setup action', (tester) async {
    final world = TestHarness();
    PayCalRepositories.instance = world.repositories;
    final crib = await world.repositories.cribs.getById('c1');
    world.signIn('a');

    await tester.pumpWidget(
      MaterialApp(home: CribDetailScreen(crib: crib)),
    );
    await tester.pumpAndSettle();

    // The action sheet of the crib offers the recurring setup to the owner
    // only, so a member never sees it.
    expect(find.text('Set up recurring transfer'), findsNothing);
  });
}
