import 'package:flutter_test/flutter_test.dart';
import 'package:paycal/data/models.dart';
import 'package:paycal/data/repositories.dart';

import 'support/harness.dart';

void main() {
  /// The crib splits 1000 between the payer and Asha.
  Expense sharedExpense({String id = 'e1'}) => Expense(
    id: id,
    cribId: 'c1',
    description: 'Dinner',
    totalMinor: 1000,
    currency: 'INR',
    payerId: 'me',
    shares: {'me': 500, 'a': 500},
    date: DateTime(2026),
    category: 'other',
  );

  test('a settlement cannot be created by somebody else', () async {
    final world = TestHarness(expenses: [sharedExpense()]);
    world.store.currentUser = testUser('me');

    await expectLater(
      world.repositories.settlements.create(
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
      ),
      throwsA(
        isA<RepositoryException>().having(
          (error) => error.code,
          'code',
          RepositoryErrorCode.unauthorized,
        ),
      ),
    );
  });

  test('a confirmed settlement cannot be created directly', () async {
    final world = TestHarness(expenses: [sharedExpense()]);
    world.store.currentUser = testUser('a');

    await expectLater(
      world.repositories.settlements.create(
        Settlement(
          id: 's1',
          cribId: 'c1',
          currency: 'INR',
          fromMemberId: 'a',
          toMemberId: 'me',
          amountMinor: 200,
          status: SettlementStatus.confirmed,
          createdAt: DateTime(2026),
        ),
      ),
      throwsA(
        isA<RepositoryException>().having(
          (error) => error.code,
          'code',
          RepositoryErrorCode.unauthorized,
        ),
      ),
    );
  });

  test('a settlement cannot overpay the outstanding balance', () async {
    final world = TestHarness(expenses: [sharedExpense()]);
    world.store.currentUser = testUser('a');

    await expectLater(
      world.repositories.settlements.create(
        Settlement(
          id: 's1',
          cribId: 'c1',
          currency: 'INR',
          fromMemberId: 'a',
          toMemberId: 'me',
          amountMinor: 900,
          status: SettlementStatus.pending,
          createdAt: DateTime(2026),
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
  });

  test('a settlement cannot overpay the receiver', () async {
    final world = TestHarness(expenses: [sharedExpense()]);
    world.store.currentUser = testUser('me');

    await expectLater(
      world.repositories.settlements.create(
        Settlement(
          id: 's1',
          cribId: 'c1',
          currency: 'INR',
          fromMemberId: 'me',
          toMemberId: 'a',
          amountMinor: 900,
          status: SettlementStatus.pending,
          createdAt: DateTime(2026),
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
  });

  test('the idempotency key replays the same settlement', () async {
    final world = TestHarness(expenses: [sharedExpense()]);
    world.store.currentUser = testUser('a');

    Settlement build() => Settlement(
      id: 's1',
      cribId: 'c1',
      currency: 'INR',
      fromMemberId: 'a',
      toMemberId: 'me',
      amountMinor: 200,
      status: SettlementStatus.pending,
      createdAt: DateTime(2026),
      idempotencyKey: 'request-1',
    );
    final first = await world.repositories.settlements.create(build());
    final replay = await world.repositories.settlements.create(build());

    expect(replay.id, first.id);
    expect(world.store.settlements, hasLength(1));
  });

  test('only the recipient can confirm a settlement', () async {
    final world = TestHarness(expenses: [sharedExpense()]);
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

    await expectLater(
      world.repositories.settlements.updateStatus(
        's1',
        SettlementStatus.confirmed,
      ),
      throwsA(
        isA<RepositoryException>().having(
          (error) => error.code,
          'code',
          RepositoryErrorCode.unauthorized,
        ),
      ),
    );
  });

  test('only the sender can cancel a settlement', () async {
    final world = TestHarness(expenses: [sharedExpense()]);
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
    await expectLater(
      world.repositories.settlements.updateStatus(
        's1',
        SettlementStatus.cancelled,
      ),
      throwsA(
        isA<RepositoryException>().having(
          (error) => error.code,
          'code',
          RepositoryErrorCode.unauthorized,
        ),
      ),
    );
  });

  test('a confirmed settlement cannot be overwritten', () async {
    final world = TestHarness(expenses: [sharedExpense()]);
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

    await expectLater(
      world.repositories.settlements.updateStatus(
        's1',
        SettlementStatus.cancelled,
      ),
      throwsA(
        isA<RepositoryException>().having(
          (error) => error.code,
          'code',
          RepositoryErrorCode.conflict,
        ),
      ),
    );
    expect(world.store.settlements.single.status, SettlementStatus.confirmed);
  });

  test('a stale settlement version is a conflict', () async {
    final world = TestHarness(expenses: [sharedExpense()]);
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

    await expectLater(
      world.repositories.settlements.updateStatus(
        's1',
        SettlementStatus.confirmed,
        expectedVersion: 5,
      ),
      throwsA(
        isA<RepositoryException>().having(
          (error) => error.code,
          'code',
          RepositoryErrorCode.conflict,
        ),
      ),
    );
  });

  test('expenses of a settled crib cannot be edited any more', () async {
    final world = TestHarness(expenses: [sharedExpense()]);
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

    await expectLater(
      world.repositories.expenses.update(
        sharedExpense().copyWith(totalMinor: 1200, shares: {'me': 1200}),
      ),
      throwsA(
        isA<RepositoryException>().having(
          (error) => error.code,
          'code',
          RepositoryErrorCode.conflict,
        ),
      ),
    );
  });

  test('a settlement does not change the tracked spending', () async {
    final world = TestHarness(expenses: [sharedExpense()]);
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

    expect(world.store.expenses.single.totalMinor, 1000);
  });
}
