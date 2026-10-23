import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paycal/core/config/app_config.dart';
import 'package:paycal/core/widgets/primary_button.dart';
import 'package:paycal/data/in_memory_repositories.dart';
import 'package:paycal/data/models.dart';
import 'package:paycal/features/cribs/crib_detail_screen.dart';
import 'package:paycal/features/cribs/create_crib_popup.dart';
import 'package:paycal/features/cribs/invite_link_sheet.dart';
import 'package:paycal/features/expenses/quick_add_sheet.dart';

import 'support/harness.dart';

/// People join a crib through an invite link, never through a name that is
/// typed into a form: a member needs an account of their own.
void main() {
  late PayCalRepositories previous;

  setUp(() {
    previous = PayCalRepositories.instance;
  });

  tearDown(() {
    PayCalRepositories.instance = previous;
  });

  testWidgets('a new crib asks for no names and hands out an invite link', (
    tester,
  ) async {
    final world = TestHarness(cribs: []);
    PayCalRepositories.instance = world.repositories;

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SizedBox())),
    );
    final created = showCreateCrib(tester.element(find.byType(Scaffold)));
    await tester.pumpAndSettle();

    // Nobody is asked for a name.
    expect(find.text('Add a member'), findsNothing);
    expect(find.textContaining('private invite link'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, 'Trip');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(PrimaryButton, 'Create crib'));
    await tester.pumpAndSettle();

    final crib = await created;
    expect(crib, isNotNull);
    expect(crib!.name, 'Trip');
    // The creator is the only member so far: everybody else joins with the
    // invite link.
    expect(crib.members, hasLength(1));
    expect(crib.members.single.id, 'me');
    expect(crib.members.single.role, MemberRole.owner);
  });

  testWidgets('the invite sheet shows a link that joins the crib', (
    tester,
  ) async {
    final world = TestHarness();
    PayCalRepositories.instance = world.repositories;
    final crib = await world.repositories.cribs.getById('c1');

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SizedBox())),
    );
    unawaited(
      showInviteLinkSheet(tester.element(find.byType(Scaffold)), crib: crib),
    );
    await tester.pumpAndSettle();

    expect(find.text('Share invite link'), findsOneWidget);
    expect(world.store.invitations, hasLength(1));

    final token = world.store.invitations.single.id;
    expect(
      find.text(AppConfig.invitationLink(token)),
      findsOneWidget,
    );
  });

  testWidgets('the group details offers the owner an invite link', (
    tester,
  ) async {
    final world = TestHarness();
    PayCalRepositories.instance = world.repositories;
    final crib = await world.repositories.cribs.getById('c1');

    await tester.pumpWidget(MaterialApp(home: CribDetailScreen(crib: crib)));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View group details'));
    await tester.pumpAndSettle();

    expect(find.text('Invite someone'), findsOneWidget);
    expect(
      find.text('Get a private link that expires in 7 days'),
      findsOneWidget,
    );
  });

  testWidgets('a member is told that only the owner may invite', (
    tester,
  ) async {
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

    expect(find.text('Invite someone'), findsOneWidget);
    expect(
      find.text('Only the Crib Owner can invite new people'),
      findsOneWidget,
    );
    // The action is inert for a member, so no invitation is created.
    expect(world.store.invitations, isEmpty);
  });

  testWidgets('the quick add sheet survives a crib without anybody to split with',
      (tester) async {
    final world = TestHarness(cribs: []);
    PayCalRepositories.instance = world.repositories;

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SizedBox())),
    );
    unawaited(showQuickAdd(tester.element(find.byType(Scaffold))));
    await tester.pumpAndSettle();

    // The preview used to divide the amount by the number of people, which
    // was zero when the crib had no members.
    expect(tester.takeException(), isNull);
    expect(
      find.text('You have no cribs yet — create one to start splitting.'),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextField).first, '100');
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      find.text('Nobody to split with yet — invite someone first'),
      findsOneWidget,
    );
  });
}
