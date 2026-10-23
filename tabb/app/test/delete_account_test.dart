import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:paycal/data/in_memory_repositories.dart';
import 'package:paycal/features/cribs/crib_detail_screen.dart';
import 'package:paycal/features/onboarding/welcome_screen.dart';
import 'package:paycal/features/profile/profile_screen.dart';

import 'support/harness.dart';

/// Deleting an account while still in a crib.
///
/// The account can only go when it is not in a crib any more, so the flow
/// asks the member to get out first: leave a crib they only take part in,
/// hand over or delete the cribs they own.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> openProfile(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ProfileScreen())),
    );
    await tester.pumpAndSettle();
    final deleteAccount = find.text('Delete account');
    await tester.ensureVisible(deleteAccount);
    await tester.pumpAndSettle();
    await tester.tap(deleteAccount);
    await tester.pumpAndSettle();
  }

  testWidgets('an owner is asked to get out of the crib first', (tester) async {
    final world = TestHarness();
    PayCalRepositories.instance = world.repositories;

    await openProfile(tester);

    expect(find.text('Leave the cribs first'), findsOneWidget);
    expect(find.text('Delete this crib'), findsOneWidget);
    expect(find.text('Hand Over'), findsOneWidget);
    // The account is not deleted while the crib is still there.
    expect(find.text('Delete my account'), findsNothing);
  });

  testWidgets('an owner deletes the crib, then the account', (tester) async {
    final world = TestHarness();
    PayCalRepositories.instance = world.repositories;

    await openProfile(tester);

    await tester.tap(find.text('Delete this crib'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete the crib'));
    await tester.pumpAndSettle();

    final cribs = await world.repositories.cribs.list();
    expect(cribs.where((crib) => crib.id == 'c1'), isEmpty);

    await tester.tap(find.text('Delete my account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(PayCalRepositories.instance.auth.currentUser, isNull);
    expect(find.byType(WelcomeScreen), findsOneWidget);
  });

  testWidgets('a member leaves the crib, then deletes the account', (
    tester,
  ) async {
    final world = TestHarness();
    PayCalRepositories.instance = world.repositories;
    world.signIn('a');

    await openProfile(tester);

    expect(find.text('Leave the cribs first'), findsOneWidget);
    expect(find.text('Leave this crib'), findsOneWidget);

    await tester.tap(find.text('Leave this crib'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leave the crib'));
    await tester.pumpAndSettle();

    final crib = await world.repositories.cribs.getById('c1');
    expect(crib.memberById('a')!.isActive, isFalse);

    await tester.tap(find.text('Delete my account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(PayCalRepositories.instance.auth.currentUser, isNull);
    expect(find.byType(WelcomeScreen), findsOneWidget);
  });

  testWidgets('the owner deletes the crib from the crib menu', (tester) async {
    final world = TestHarness();
    PayCalRepositories.instance = world.repositories;
    final crib = await world.repositories.cribs.getById('c1');

    await tester.pumpWidget(MaterialApp(home: CribDetailScreen(crib: crib)));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View group details'));
    await tester.pumpAndSettle();

    expect(find.text('Delete this crib'), findsOneWidget);
    await tester.ensureVisible(find.text('Delete this crib'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete this crib'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete the crib'));
    await tester.pumpAndSettle();

    final cribs = await world.repositories.cribs.list();
    expect(cribs.where((crib) => crib.id == 'c1'), isEmpty);
  });

  testWidgets('a member is not offered the delete tile', (tester) async {
    final world = TestHarness();
    PayCalRepositories.instance = world.repositories;
    world.signIn('a');
    final crib = await world.repositories.cribs.getById('c1');

    await tester.pumpWidget(MaterialApp(home: CribDetailScreen(crib: crib)));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View group details'));
    await tester.pumpAndSettle();

    expect(find.text('Delete this crib'), findsNothing);
    expect(find.text('Leave this crib'), findsOneWidget);
  });

  testWidgets('a member that is in no crib deletes the account directly', (
    tester,
  ) async {
    final world = TestHarness(cribs: []);
    PayCalRepositories.instance = world.repositories;

    await openProfile(tester);

    expect(find.text('Leave the cribs first'), findsNothing);
    expect(find.text('Delete account?'), findsOneWidget);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(PayCalRepositories.instance.auth.currentUser, isNull);
  });
}
