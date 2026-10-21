import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:paycal/core/export/ledger_pdf.dart';
import 'package:paycal/core/utils/deep_link.dart';
import 'package:paycal/data/in_memory_repositories.dart';
import 'package:paycal/data/models.dart';
import 'package:paycal/data/pending_invitation.dart';
import 'package:paycal/data/repositories.dart';

import 'support/harness.dart';

void main() {
  late PayCalRepositories previous;

  setUp(() {
    previous = PayCalRepositories.instance;
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    PayCalRepositories.instance = previous;
  });

  group('leaving a crib', () {
    test('a member can leave and keeps their history', () async {
      final world = TestHarness(
        expenses: [testExpense(id: 'e1', payerId: 'a', amount: 900)],
      );
      PayCalRepositories.instance = world.repositories;
      world.signIn('a');

      await world.repositories.cribs.leave('c1');

      final crib = await world.repositories.cribs.getById('c1');
      final member = crib.memberById('a')!;
      expect(member.isActive, isFalse);
      expect(member.leftAt, isNotNull);
      // The expense of the member that left is still part of the crib.
      final expenses = await world.repositories.expenses.list(cribId: 'c1');
      expect(expenses.single.id, 'e1');
    });

    test('the owner cannot leave before handing the crib over', () async {
      final world = TestHarness();
      PayCalRepositories.instance = world.repositories;

      await expectLater(
        world.repositories.cribs.leave('c1'),
        throwsA(
          isA<RepositoryException>().having(
            (error) => error.message,
            'message',
            contains('Hand the crib over'),
          ),
        ),
      );
    });

    test('a member that is not in the crib cannot leave it', () async {
      final world = TestHarness();
      PayCalRepositories.instance = world.repositories;
      world.signIn('stranger');

      await expectLater(
        world.repositories.cribs.leave('c1'),
        throwsA(isA<RepositoryException>()),
      );
    });

    test('a schedule the member paid for is paused', () async {
      final world = TestHarness(
        recurring: [
          RecurringPayment(
            id: 'r1',
            cribId: 'c1',
            description: 'Rent',
            amountMinor: 10000,
            currency: 'INR',
            category: 'rent',
            frequency: RecurringFrequency.monthly,
            recipientId: 'a',
            payerId: 'a',
            createdById: 'me',
            startDate: DateTime(2026),
            timeZone: 'Asia/Kolkata',
            localHour: 9,
            localMinute: 0,
            anchorDay: 1,
          ),
        ],
      );
      PayCalRepositories.instance = world.repositories;
      world.signIn('a');

      await world.repositories.cribs.leave('c1');

      final schedules = world.repositories.recurring.cachedSchedules;
      expect(schedules.single.isPaused, isTrue);
    });
  });

  group('handing a crib over', () {
    test('the owner can hand the crib to another member', () async {
      final world = TestHarness();
      PayCalRepositories.instance = world.repositories;

      final updated = await world.repositories.cribs.transferOwnership(
        cribId: 'c1',
        newOwnerId: 'a',
      );

      expect(updated.ownerId, 'a');
      expect(updated.memberById('a')!.role, MemberRole.owner);
      expect(updated.memberById('me')!.role, MemberRole.member);
    });

    test('a member that is not the owner cannot hand the crib over', () async {
      final world = TestHarness();
      PayCalRepositories.instance = world.repositories;
      world.signIn('a');

      await expectLater(
        world.repositories.cribs.transferOwnership(
          cribId: 'c1',
          newOwnerId: 'r',
        ),
        throwsA(isA<RepositoryException>()),
      );
    });

    test('the new owner has to be an active member', () async {
      final world = TestHarness();
      PayCalRepositories.instance = world.repositories;

      await expectLater(
        world.repositories.cribs.transferOwnership(
          cribId: 'c1',
          newOwnerId: 'stranger',
        ),
        throwsA(isA<RepositoryException>()),
      );
    });
  });

  group('invitations of members without an account', () {
    testWidgets('an invite link of a signed out member is kept', (
      tester,
    ) async {
      final world = TestHarness();
      PayCalRepositories.instance = world.repositories;
      final invitation = await world.repositories.invitations.create(
        cribId: 'c1',
        createdById: 'me',
        expiresAt: DateTime.now().add(const Duration(days: 1)),
      );
      world.signOut();

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SizedBox())),
      );
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      await DeepLinks.handle(
        Uri.parse('paycal://invite/${invitation.token}'),
        navigator,
      );
      await tester.pumpAndSettle();

      expect(await PendingInvitation.read(), invitation.token);
      // The member is asked to sign in, so the token is not lost.
      expect(find.text('You are invited'), findsOneWidget);
      expect(
        world.store.cribs.single.memberById('me')?.isActive,
        isTrue,
      );
    });

    testWidgets('the kept invitation is accepted after the sign in', (
      tester,
    ) async {
      final world = TestHarness();
      PayCalRepositories.instance = world.repositories;
      final invitation = await world.repositories.invitations.create(
        cribId: 'c1',
        createdById: 'me',
        expiresAt: DateTime.now().add(const Duration(days: 1)),
      );
      world.signOut();
      await PendingInvitation.store(invitation.token);

      // The member signs in and the shell accepts the invitation.
      world.signIn('newcomer', name: 'Newcomer');
      final token = await PendingInvitation.read();
      expect(token, invitation.token);
      final crib = await world.repositories.invitations.accept(token!);
      await PendingInvitation.clear();

      expect(crib.memberById('newcomer')?.isActive, isTrue);
      expect(await PendingInvitation.read(), isNull);
    });
  });

  group('the history export', () {
    test('the pdf carries the ledger of the crib', () async {
      final world = TestHarness(
        expenses: [testExpense(id: 'e1', amount: 4500)],
      );
      PayCalRepositories.instance = world.repositories;
      final crib = await world.repositories.cribs.getById('c1');
      final expenses = await world.repositories.expenses.list(cribId: 'c1');

      final bytes = await LedgerPdf.build(
        crib: crib,
        expenses: expenses,
        settlements: const [],
        memberId: 'me',
      );

      expect(bytes.length, greaterThan(1000));
      // A PDF always starts with its own header.
      expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    });
  });
}
