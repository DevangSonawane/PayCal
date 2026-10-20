import 'package:flutter_test/flutter_test.dart';
import 'package:paycal/data/models.dart';

import 'support/harness.dart';

void main() {
  /// The actions that were recorded, newest first.
  List<String?> actionsOf(TestHarness world) =>
      world.store.activity.map((event) => event.action).toList();

  ActivityEvent? eventFor(TestHarness world, String action) {
    for (final event in world.store.activity) {
      if (event.action == action) return event;
    }
    return null;
  }

  test('creating a crib is recorded with actor and target', () async {
    final world = TestHarness(cribs: []);

    await world.repositories.cribs.create(
      Crib(
        id: 'c2',
        name: 'Trip',
        currency: 'INR',
        members: const [],
        categories: const [],
      ),
    );

    final event = eventFor(world, 'crib_created');
    expect(event, isNotNull);
    expect(event!.actorId, 'me');
    expect(event.targetId, 'c2');
    expect(event.cribId, 'c2');
    expect(event.occurredAt, isNotNull);
  });

  test('crib updates and deletes are recorded', () async {
    final world = TestHarness();
    final crib = await world.repositories.cribs.getById('c1');

    await world.repositories.cribs.update(crib.copyWith(name: 'Home'));
    await world.repositories.cribs.delete('c1');

    expect(actionsOf(world), containsAll(['crib_updated', 'crib_deleted']));
  });

  test('membership changes are recorded', () async {
    final world = TestHarness();

    await world.repositories.cribs.addMember(
      cribId: 'c1',
      member: Member(id: 'z', name: 'Zoya'),
    );
    await world.repositories.cribs.removeMember(cribId: 'c1', memberId: 'z');

    expect(
      actionsOf(world),
      containsAll(['member_added', 'member_removed']),
    );
    expect(eventFor(world, 'member_removed')!.targetId, 'z');
  });

  test('expense changes are recorded', () async {
    final world = TestHarness();
    final expense = testExpense();

    await world.repositories.expenses.create(expense);
    await world.repositories.expenses.update(
      expense.copyWith(totalMinor: 1200, shares: {'me': 1200}),
    );
    await world.repositories.expenses.flagDispute(expense.id);
    await world.repositories.expenses.delete(expense.id);

    expect(
      actionsOf(world),
      containsAll([
        'expense_created',
        'expense_updated',
        'expense_disputed',
        'expense_deleted',
      ]),
    );
  });

  test('settlement changes are recorded', () async {
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
    world.store.currentUser = testUser('a');

    await world.repositories.settlements.create(
      Settlement(
        id: 's1',
        cribId: 'c1',
        currency: 'INR',
        fromMemberId: 'a',
        toMemberId: 'me',
        amountMinor: 200,
        status: SettlementStatus.pending,
        createdAt: DateTime(2026),
      ),
    );
    world.store.currentUser = testUser('me');
    await world.repositories.settlements.updateStatus(
      's1',
      SettlementStatus.confirmed,
    );

    expect(
      actionsOf(world),
      containsAll(['settlement_created', 'settlement_confirmed']),
    );
  });

  test('invitation changes are recorded', () async {
    final world = TestHarness();
    final invitation = await world.repositories.invitations.create(
      cribId: 'c1',
      createdById: 'me',
      expiresAt: DateTime.now().add(const Duration(days: 1)),
    );
    world.store.currentUser = testUser('newcomer');
    await world.repositories.invitations.accept(invitation.token);
    world.store.currentUser = testUser('me');
    await world.repositories.invitations.revoke(invitation.token);

    expect(
      actionsOf(world),
      containsAll([
        'invitation_created',
        'invitation_accepted',
        'invitation_revoked',
      ]),
    );
    expect(eventFor(world, 'invitation_accepted')!.actorId, 'newcomer');
  });

  test('recurring changes are recorded', () async {
    final world = TestHarness();
    await world.repositories.recurring.create(
      RecurringPayment(
        id: 'r1',
        cribId: 'c1',
        description: 'Pocket money',
        amountMinor: 50000,
        currency: 'INR',
        category: 'other',
        frequency: RecurringFrequency.monthly,
        recipientId: 'a',
        createdById: 'me',
        startDate: DateTime(2026, 1, 31, 9),
      ),
    );
    await world.repositories.recurring.generateDue(
      cribId: 'c1',
      now: DateTime.utc(2026, 2, 5),
    );
    await world.repositories.recurring.cancel('r1');

    expect(
      actionsOf(world),
      containsAll([
        'recurring_created',
        'recurring_generated',
        'recurring_cancelled',
      ]),
    );
  });

  test('the activity feed keeps the newest change first', () async {
    final world = TestHarness();
    final crib = await world.repositories.cribs.getById('c1');

    await world.repositories.cribs.update(crib.copyWith(name: 'Home'));
    await world.repositories.cribs.addMember(
      cribId: 'c1',
      member: Member(id: 'z', name: 'Zoya'),
    );

    expect(actionsOf(world).first, 'member_added');
    expect(actionsOf(world).last, 'crib_updated');
  });
}
