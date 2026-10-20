import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paycal/core/utils/deep_link.dart';
import 'package:paycal/core/widgets/primary_button.dart';
import 'package:paycal/data/in_memory_repositories.dart';
import 'package:paycal/data/models.dart';
import 'package:paycal/features/cribs/crib_detail_screen.dart';
import 'package:paycal/features/cribs/crib_edit_sheet.dart';
import 'package:paycal/features/cribs/create_crib_popup.dart';
import 'package:paycal/features/expenses/expense_detail_screen.dart';

import 'support/harness.dart';

void main() {
  late PayCalRepositories previous;

  setUp(() {
    previous = PayCalRepositories.instance;
  });

  tearDown(() {
    PayCalRepositories.instance = previous;
  });

  testWidgets('the crib screen shows the expenses of the crib', (
    tester,
  ) async {
    final world = TestHarness(
      expenses: [
        Expense(
          id: 'e1',
          cribId: 'c1',
          description: 'Groceries',
          totalMinor: 75000,
          currency: 'INR',
          payerId: 'me',
          shares: {'me': 25000, 'a': 25000, 'r': 25000},
          date: DateTime(2026),
          category: 'groceries',
        ),
      ],
    );
    PayCalRepositories.instance = world.repositories;
    final crib = await world.repositories.cribs.getById('c1');

    await tester.pumpWidget(MaterialApp(home: CribDetailScreen(crib: crib)));
    await tester.pumpAndSettle();

    expect(find.text('Flat'), findsWidgets);
    expect(find.text('Groceries'), findsOneWidget);
  });

  testWidgets('a new crib is created through the repository', (
    tester,
  ) async {
    final world = TestHarness(cribs: []);
    PayCalRepositories.instance = world.repositories;

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SizedBox())),
    );
    showCreateCrib(tester.element(find.byType(Scaffold)));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'Trip');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(PrimaryButton, 'Create crib'));
    await tester.pumpAndSettle();

    expect(world.store.cribs, hasLength(1));
    expect(world.store.cribs.single.name, 'Trip');
    expect(world.store.cribs.single.ownerId, 'me');
    expect(world.store.cribs.single.memberById('me')!.role, MemberRole.owner);
  });

  testWidgets('the crib editor adds a member through the repository', (
    tester,
  ) async {
    final world = TestHarness();
    PayCalRepositories.instance = world.repositories;
    final crib = await world.repositories.cribs.getById('c1');

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SizedBox())),
    );
    showCribEdit(tester.element(find.byType(Scaffold)), crib);
    await tester.pumpAndSettle();

    expect(find.text('Edit crib'), findsOneWidget);
    expect(find.text('Asha'), findsOneWidget);

    final addSomeone = find.text('Add someone');
    await tester.ensureVisible(addSomeone);
    await tester.pumpAndSettle();
    await tester.tap(addSomeone);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).last, 'Zoya');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(PrimaryButton, 'Add'));
    await tester.pumpAndSettle();

    expect(
      world.store.cribs.single.members.map((member) => member.name),
      contains('Zoya'),
    );
    expect(
      world.store.activity.map((event) => event.action),
      contains('member_added'),
    );
  });

  testWidgets('the expense screen hides edit and delete for other members', (
    tester,
  ) async {
    final world = TestHarness(
      expenses: [
        Expense(
          id: 'e1',
          cribId: 'c1',
          description: 'Groceries',
          totalMinor: 125000,
          currency: 'INR',
          payerId: 'a',
          shares: {'me': 62500, 'a': 62500},
          date: DateTime(2026),
          category: 'groceries',
          createdById: 'a',
        ),
      ],
    );
    PayCalRepositories.instance = world.repositories;
    // "r" is an ordinary member: neither the payer nor the author of the
    // expense, and not the owner of the crib.
    world.signIn('r');
    final expense = await world.repositories.expenses.getById('e1');

    await tester.pumpWidget(
      MaterialApp(home: ExpenseDetailScreen(expense: expense)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Flag a problem'), findsOneWidget);
    expect(find.text('Edit'), findsNothing);
    expect(find.text('Delete'), findsNothing);
  });

  testWidgets('the expense screen shows edit and delete for the crib owner', (
    tester,
  ) async {
    final world = TestHarness(
      expenses: [
        Expense(
          id: 'e1',
          cribId: 'c1',
          description: 'Groceries',
          totalMinor: 125000,
          currency: 'INR',
          payerId: 'a',
          shares: {'me': 62500, 'a': 62500},
          date: DateTime(2026),
          category: 'groceries',
          createdById: 'a',
        ),
      ],
    );
    PayCalRepositories.instance = world.repositories;
    // "me" owns the crib, so they may correct any expense in it.
    final expense = await world.repositories.expenses.getById('e1');

    await tester.pumpWidget(
      MaterialApp(home: ExpenseDetailScreen(expense: expense)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
  });

  testWidgets('the payer can edit the expense', (tester) async {
    final world = TestHarness(
      expenses: [
        Expense(
          id: 'e1',
          cribId: 'c1',
          description: 'Groceries',
          totalMinor: 125000,
          currency: 'INR',
          payerId: 'me',
          shares: {'me': 125000},
          date: DateTime(2026),
          category: 'groceries',
          createdById: 'me',
        ),
      ],
    );
    PayCalRepositories.instance = world.repositories;
    final expense = await world.repositories.expenses.getById('e1');

    await tester.pumpWidget(
      MaterialApp(home: ExpenseDetailScreen(expense: expense)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
  });

  testWidgets('an invitation link joins the crib', (tester) async {
    final world = TestHarness();
    PayCalRepositories.instance = world.repositories;
    final invitation = await world.repositories.invitations.create(
      cribId: 'c1',
      createdById: 'me',
      expiresAt: DateTime.now().add(const Duration(days: 1)),
    );
    world.store.currentUser = testUser('newcomer');

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SizedBox())),
    );
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    await DeepLinks.handle(
      Uri.parse('paycal://invite/${invitation.token}'),
      navigator,
    );
    await tester.pumpAndSettle();

    expect(world.store.cribs.single.memberById('newcomer')?.isActive, isTrue);
  });

  testWidgets('a crib link never grants membership', (tester) async {
    final world = TestHarness();
    PayCalRepositories.instance = world.repositories;
    world.store.currentUser = testUser('stranger');

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SizedBox())),
    );
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    await DeepLinks.handle(Uri.parse('paycal://crib/c1'), navigator);
    await tester.pumpAndSettle();

    expect(world.store.cribs.single.memberById('stranger'), isNull);
  });
}
