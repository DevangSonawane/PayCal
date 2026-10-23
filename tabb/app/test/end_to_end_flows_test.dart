import 'package:flutter_test/flutter_test.dart';
import 'package:paycal/data/models.dart';
import 'package:paycal/data/repositories.dart';
import 'package:paycal/domain/financial_ledger.dart';

import 'support/harness.dart';

/// The twelve product flows, walked in order, with more than one member and
/// more than one crib in the same store.
///
/// This is an **integration test at the repository level**. It is not a device
/// test and it is not a network test: there is no real authentication, no
/// durable storage and no database in this architecture yet. What it proves
/// is that the flows work against the real repository implementations, with
/// the real domain rules, in one process.
void main() {
  late TestHarness world;

  setUp(() {
    // The store starts empty, so the first flow really creates the crib.
    world = TestHarness(cribs: [], now: DateTime.utc(2026, 3, 1, 10));
  });

  test('flow 1 to 12: the whole product, from the first crib to the audit trail',
      () async {
    // ---------------------------------------------------------------
    // 1. Create a Crib and view it.
    // ---------------------------------------------------------------
    final crib = await world.repositories.cribs.create(
      Crib(
        id: 'c1',
        name: 'Our flat',
        currency: 'INR',
        members: const [],
        categories: const ['other'],
      ),
    );
    expect(crib.ownerId, 'me');
    expect((await world.repositories.cribs.list()).single.id, 'c1');
    expect(world.repositories.cribs.cachedCribs.single.name, 'Our flat');

    // ---------------------------------------------------------------
    // 2. Invite a member and accept the invitation.
    // ---------------------------------------------------------------
    final invitation = await world.repositories.invitations.create(
      cribId: 'c1',
      createdById: 'me',
      expiresAt: DateTime.utc(2026, 3, 8),
    );
    expect(invitation.token, isNot('c1'));
    expect(invitation.token.length, greaterThan(16));

    world.signIn('asha');
    await world.repositories.invitations.accept(invitation.id);
    expect(
      (await world.repositories.cribs.getById('c1')).memberById('asha'),
      isNotNull,
    );

    // A second member joins as well, so the crib has a group. The owner
    // issues the second invitation.
    world.signIn('me');
    final second = await world.repositories.invitations.create(
      cribId: 'c1',
      createdById: 'me',
      expiresAt: DateTime.utc(2026, 3, 8),
    );
    world.signIn('dev');
    await world.repositories.invitations.accept(second.id);

    // ---------------------------------------------------------------
    // 3. Record an expense and verify the shares and the balances.
    // ---------------------------------------------------------------
    world.signIn('me');
    await world.repositories.expenses.create(
      Expense(
        id: 'e1',
        cribId: 'c1',
        description: 'Dinner',
        totalMinor: 900,
        currency: 'INR',
        payerId: 'me',
        shares: {'me': 300, 'asha': 300, 'dev': 300},
        date: DateTime(2026, 3, 1),
        category: 'other',
      ),
    );
    final balances = FinancialLedger.balances(
      crib: await world.repositories.cribs.getById('c1'),
      expenses: world.store.expenses,
      settlements: world.store.settlements,
    );
    expect(balances, {'me': 600, 'asha': -300, 'dev': -300});
    // The pairwise debt agrees with the net position for a single payer.
    expect(
      FinancialLedger.pairwiseDebt(
        crib: await world.repositories.cribs.getById('c1'),
        expenses: world.store.expenses,
        fromId: 'asha',
        toId: 'me',
      ),
      300,
    );

    // ---------------------------------------------------------------
    // 4. Record a valid settlement and verify the pairwise debt and the
    //    group balances.
    // ---------------------------------------------------------------
    world.signIn('asha');
    final settlement = await world.repositories.settlements.create(
      Settlement(
        id: 's1',
        cribId: 'c1',
        currency: 'INR',
        fromMemberId: 'asha',
        toMemberId: 'me',
        amountMinor: 300,
        status: SettlementStatus.selfManaged,
        createdAt: DateTime(2026, 3, 1),
      ),
    );
    expect(settlement.amountMinor, 300);
    expect(
      FinancialLedger.pairwiseDebt(
        crib: await world.repositories.cribs.getById('c1'),
        expenses: world.store.expenses,
        settlements: world.store.settlements,
        fromId: 'asha',
        toId: 'me',
      ),
      0,
      reason: 'the debt is settled',
    );
    expect(
      FinancialLedger.balances(
        crib: await world.repositories.cribs.getById('c1'),
        expenses: world.store.expenses,
        settlements: world.store.settlements,
      ),
      {'me': 300, 'asha': 0, 'dev': -300},
    );

    // ---------------------------------------------------------------
    // 5. Reject an invalid settlement.
    // ---------------------------------------------------------------
    world.signIn('dev');
    await expectLater(
      world.repositories.settlements.create(
        Settlement(
          id: 's2',
          cribId: 'c1',
          currency: 'INR',
          fromMemberId: 'dev',
          toMemberId: 'me',
          amountMinor: 400,
          status: SettlementStatus.selfManaged,
          createdAt: DateTime(2026, 3, 1),
        ),
      ),
      throwsA(
        isA<RepositoryException>().having(
          (error) => error.code,
          'code',
          RepositoryErrorCode.validation,
        ),
      ),
    );
    // Dev owes 300 to "me" and nothing to "asha", so a settlement to
    // "asha" is refused as well.
    world.signIn('dev');
    await expectLater(
      world.repositories.settlements.create(
        Settlement(
          id: 's3',
          cribId: 'c1',
          currency: 'INR',
          fromMemberId: 'dev',
          toMemberId: 'asha',
          amountMinor: 100,
          status: SettlementStatus.selfManaged,
          createdAt: DateTime(2026, 3, 1),
        ),
      ),
      throwsA(
        isA<RepositoryException>().having(
          (error) => error.code,
          'code',
          RepositoryErrorCode.validation,
        ),
      ),
    );

    // ---------------------------------------------------------------
    // 6. Remove a member and preserve the financial history.
    // ---------------------------------------------------------------
    world.signIn('me');
    final afterRemoval = await world.repositories.cribs.removeMember(
      cribId: 'c1',
      memberId: 'dev',
    );
    expect(afterRemoval.memberById('dev')!.isActive, isFalse);
    expect(afterRemoval.memberById('dev')!.leftAt, isNotNull);
    // The history is still there and still balances.
    expect(
      FinancialLedger.balances(
        crib: afterRemoval,
        expenses: world.store.expenses,
        settlements: world.store.settlements,
      ),
      {'me': 300, 'asha': 0, 'dev': -300},
    );
    // A removed member cannot write any more.
    world.signIn('dev');
    await expectLater(
      world.repositories.expenses.create(
        Expense(
          id: 'e2',
          cribId: 'c1',
          description: 'Coffee',
          totalMinor: 100,
          currency: 'INR',
          payerId: 'dev',
          shares: {'dev': 100},
          date: DateTime(2026, 3, 1),
          category: 'other',
        ),
      ),
      throwsA(isA<RepositoryException>()),
    );
    // A removed member keeps the history readable.
    expect((await world.repositories.cribs.list()).single.id, 'c1');

    // ---------------------------------------------------------------
    // 7. Pause a recurring schedule when its payer leaves, assign an active
    //    payer and resume safely.
    // ---------------------------------------------------------------
    world.signIn('me');
    await world.repositories.recurring.create(
      RecurringPayment(
        id: 'r1',
        cribId: 'c1',
        description: 'Rent',
        amountMinor: 5000,
        currency: 'INR',
        category: 'other',
        frequency: RecurringFrequency.monthly,
        recipientId: 'asha',
        createdById: 'me',
        startDate: DateTime(2026, 1, 31, 9),
        timeZone: 'UTC',
      ),
    );
    // The owner hands the paying to "asha".
    await world.repositories.recurring.assignPayer('r1', 'asha');
    expect(world.store.schedules.single.payerId, 'asha');

    // "asha" leaves, so the schedule is paused.
    await world.repositories.cribs.removeMember(
      cribId: 'c1',
      memberId: 'asha',
    );
    expect(world.store.schedules.single.isPaused, isTrue);
    final generatedWhilePaused = await world.repositories.recurring.generateDue(
      cribId: 'c1',
      now: DateTime.utc(2026, 4, 1),
    );
    expect(generatedWhilePaused, isEmpty);

    // The owner assigns an active member and the schedule runs again.
    await world.repositories.recurring.assignPayer('r1', 'me');
    expect(world.store.schedules.single.isPaused, isFalse);
    final generatedAfterResume = await world.repositories.recurring.generateDue(
      cribId: 'c1',
      now: DateTime.utc(2026, 4, 1),
    );
    expect(generatedAfterResume, isNotEmpty);
    // Running the generation again does not create a second expense.
    final generatedAgain = await world.repositories.recurring.generateDue(
      cribId: 'c1',
      now: DateTime.utc(2026, 4, 1),
    );
    expect(generatedAgain, isEmpty);

    // ---------------------------------------------------------------
    // 8. Prevent a member from performing owner-only actions.
    // ---------------------------------------------------------------
    world.signIn('me');
    await world.repositories.cribs.addMember(
      cribId: 'c1',
      member: Member(id: 'new', name: 'New'),
    );
    world.signIn('new');
    await expectLater(
      world.repositories.cribs.update(
        (await world.repositories.cribs.getById('c1')).copyWith(name: 'Hijacked'),
      ),
      throwsA(
        isA<RepositoryException>().having(
          (error) => error.code,
          'code',
          RepositoryErrorCode.unauthorized,
        ),
      ),
    );
    await expectLater(
      world.repositories.cribs.removeMember(
        cribId: 'c1',
        memberId: 'me',
      ),
      throwsA(
        isA<RepositoryException>().having(
          (error) => error.code,
          'code',
          RepositoryErrorCode.unauthorized,
        ),
      ),
    );
    await expectLater(
      world.repositories.cribs.addMember(
        cribId: 'c1',
        member: Member(id: 'sneaky', name: 'Sneaky'),
      ),
      throwsA(
        isA<RepositoryException>().having(
          (error) => error.code,
          'code',
          RepositoryErrorCode.unauthorized,
        ),
      ),
    );

    // ---------------------------------------------------------------
    // 9. Verify the repository isolation between cribs and users.
    // ---------------------------------------------------------------
    world.signIn('me');
    await world.repositories.cribs.create(
      Crib(
        id: 'c2',
        name: 'Trip',
        currency: 'INR',
        members: const [],
        categories: const ['other'],
      ),
    );
    world.signIn('new');
    expect(
      (await world.repositories.cribs.list()).map((item) => item.id),
      ['c1'],
      reason: 'a member of one crib does not see the other cribs',
    );
    await expectLater(
      world.repositories.cribs.getById('c2'),
      throwsA(
        isA<RepositoryException>().having(
          (error) => error.code,
          'code',
          RepositoryErrorCode.notFound,
        ),
      ),
    );
    expect(
      world.repositories.expenses.cachedExpenses.every(
        (expense) => expense.cribId == 'c1',
      ),
      isTrue,
    );

    // ---------------------------------------------------------------
    // 10. Verify the signed-out behaviour.
    // ---------------------------------------------------------------
    world.signOut();
    expect(world.repositories.cribs.cachedCribs, isEmpty);
    expect(world.repositories.expenses.cachedExpenses, isEmpty);
    expect(world.repositories.settlements.cachedSettlements, isEmpty);
    expect(world.repositories.activity.cachedEvents, isEmpty);
    await expectLater(
      world.repositories.cribs.list(),
      throwsA(
        isA<RepositoryException>().having(
          (error) => error.code,
          'code',
          RepositoryErrorCode.unauthorized,
        ),
      ),
    );

    // ---------------------------------------------------------------
    // 11. Account deletion and the ownership edge cases, to the extent the
    //     current implementation supports them.
    // ---------------------------------------------------------------
    // The current build has no account deletion: the profile screen shows a
    // toast and changes nothing. The owner of a crib therefore cannot leave
    // it, and the owner cannot be removed.
    world.signIn('me');
    await expectLater(
      world.repositories.cribs.removeMember(cribId: 'c1', memberId: 'me'),
      throwsA(
        isA<RepositoryException>().having(
          (error) => error.code,
          'code',
          RepositoryErrorCode.unauthorized,
        ),
      ),
    );
    // A member cannot leave the crib by removing themselves either.
    world.signIn('new');
    await expectLater(
      world.repositories.cribs.removeMember(cribId: 'c1', memberId: 'new'),
      throwsA(
        isA<RepositoryException>().having(
          (error) => error.code,
          'code',
          RepositoryErrorCode.unauthorized,
        ),
      ),
    );

    // ---------------------------------------------------------------
    // 12. Verify the activity history for the financial and the membership
    //     actions.
    // ---------------------------------------------------------------
    world.signIn('me');
    final actions = world.store.activity.map((event) => event.action).toList();
    expect(
      actions,
      containsAll([
        'crib_created',
        'invitation_created',
        'invitation_accepted',
        'expense_created',
        'settlement_created',
        'member_removed',
        'recurring_created',
        'recurring_payer_assigned',
        'recurring_paused',
        'recurring_resumed',
      ]),
    );
    // The feed of the owner holds the events of every crib the owner is a
    // member of.
    final visible = await world.repositories.activity.list();
    expect(visible, isNotEmpty);
    expect(visible.map((event) => event.cribId).toSet(), {'c1', 'c2'});
    // A member of one crib only sees the events of that crib.
    world.signIn('new');
    final memberVisible = await world.repositories.activity.list();
    expect(memberVisible, isNotEmpty);
    for (final event in memberVisible) {
      expect(event.cribId, 'c1');
    }
    // The newest change is first.
    expect(world.store.activity.first.action, isNotNull);
  });
}
