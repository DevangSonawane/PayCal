import 'package:flutter_test/flutter_test.dart';
import 'package:paycal/data/models.dart';
import 'package:paycal/data/repositories.dart';
import 'package:paycal/domain/financial_ledger.dart';

import 'support/harness.dart';

void main() {
  test('the creator of a crib becomes its owner', () async {
    final world = TestHarness(cribs: []);

    final created = await world.repositories.cribs.create(
      Crib(
        id: 'c2',
        name: 'Trip',
        currency: 'INR',
        members: [Member(id: 'a', name: 'Asha')],
        categories: const ['food'],
      ),
    );

    expect(created.ownerId, 'me');
    expect(created.memberById('me')!.role, MemberRole.owner);
    expect(created.memberById('a')!.role, MemberRole.member);
    expect(created.memberById('a')!.isAdmin, isFalse);
  });

  test('a crib with the same id cannot be created twice', () async {
    final world = TestHarness();

    await expectLater(
      world.repositories.cribs.create(
        Crib(
          id: 'c1',
          name: 'Copy',
          currency: 'INR',
          members: const [],
          categories: const [],
        ),
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

  test('a member cannot update the crib', () async {
    final world = TestHarness();
    final crib = await world.repositories.cribs.getById('c1');
    world.store.currentUser = testUser('a');

    await expectLater(
      world.repositories.cribs.update(crib.copyWith(name: 'Renamed')),
      throwsA(
        isA<RepositoryException>().having(
          (error) => error.code,
          'code',
          RepositoryErrorCode.unauthorized,
        ),
      ),
    );
  });

  test('a stale version is a conflict', () async {
    final world = TestHarness();
    final crib = await world.repositories.cribs.getById('c1');
    await world.repositories.cribs.update(crib.copyWith(name: 'First'));

    // The second update still carries the version from before the first one.
    await expectLater(
      world.repositories.cribs.update(crib.copyWith(name: 'Second')),
      throwsA(
        isA<RepositoryException>().having(
          (error) => error.code,
          'code',
          RepositoryErrorCode.conflict,
        ),
      ),
    );
    expect((await world.repositories.cribs.getById('c1')).name, 'First');
  });

  test('the currency can change while the crib has no activity', () async {
    final world = TestHarness();
    final crib = await world.repositories.cribs.getById('c1');

    final updated = await world.repositories.cribs.update(
      crib.copyWith(currency: 'USD'),
    );

    expect(updated.currency, 'USD');
    expect(updated.version, crib.version + 1);
  });

  test('the currency cannot change once the crib has activity', () async {
    final world = TestHarness(expenses: [testExpense()]);
    final crib = await world.repositories.cribs.getById('c1');

    await expectLater(
      world.repositories.cribs.update(crib.copyWith(currency: 'USD')),
      throwsA(
        isA<RepositoryException>().having(
          (error) => error.code,
          'code',
          RepositoryErrorCode.validation,
        ),
      ),
    );
    expect((await world.repositories.cribs.getById('c1')).currency, 'INR');
  });

  test('the currency cannot change once the crib has a settlement', () async {
    final world = TestHarness(
      settlements: [
        Settlement(
          id: 's1',
          cribId: 'c1',
          currency: 'INR',
          fromMemberId: 'a',
          toMemberId: 'me',
          amountMinor: 100,
          status: SettlementStatus.pending,
          createdAt: DateTime(2026),
        ),
      ],
    );
    final crib = await world.repositories.cribs.getById('c1');

    await expectLater(
      world.repositories.cribs.update(crib.copyWith(currency: 'USD')),
      throwsA(
        isA<RepositoryException>().having(
          (error) => error.code,
          'code',
          RepositoryErrorCode.validation,
        ),
      ),
    );
  });

  test('only the owner can delete a crib', () async {
    final world = TestHarness();
    world.store.currentUser = testUser('a');

    await expectLater(
      world.repositories.cribs.delete('c1'),
      throwsA(
        isA<RepositoryException>().having(
          (error) => error.code,
          'code',
          RepositoryErrorCode.unauthorized,
        ),
      ),
    );
  });

  test('deleting a crib hides it and keeps the financial history', () async {
    final world = TestHarness(
      expenses: [testExpense()],
      settlements: [
        Settlement(
          id: 's1',
          cribId: 'c1',
          currency: 'INR',
          fromMemberId: 'a',
          toMemberId: 'me',
          amountMinor: 100,
          status: SettlementStatus.pending,
          createdAt: DateTime(2026),
        ),
      ],
    );

    await world.repositories.cribs.delete('c1');

    // The crib is gone for the members, but its row stays, so the records of
    // it still point at something that exists.
    expect(world.repositories.cribs.cachedCribs, isEmpty);
    expect(world.store.cribs.single.isDeleted, isTrue);
    // Financial history is preserved rather than erased.
    expect(world.store.expenses, isNotEmpty);
    expect(world.store.settlements, isNotEmpty);
    expect(
      world.store.activity.map((event) => event.action),
      contains('crib_deleted'),
    );
  });

  test('deleting a crib with a stale version is a conflict', () async {
    final world = TestHarness();
    final crib = await world.repositories.cribs.getById('c1');
    await world.repositories.cribs.update(crib.copyWith(name: 'First'));

    await expectLater(
      world.repositories.cribs.delete('c1', expectedVersion: crib.version),
      throwsA(
        isA<RepositoryException>().having(
          (error) => error.code,
          'code',
          RepositoryErrorCode.conflict,
        ),
      ),
    );
  });

  test('an unknown crib is not found', () async {
    final world = TestHarness();

    await expectLater(
      world.repositories.cribs.getById('nope'),
      throwsA(
        isA<RepositoryException>().having(
          (error) => error.code,
          'code',
          RepositoryErrorCode.notFound,
        ),
      ),
    );
  });

  group('deleting a crib with financial history', () {
    TestHarness worldWithHistory() => TestHarness(
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
      settlements: [
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
      ],
    );

    test('the financial records stay and still resolve', () async {
      final world = worldWithHistory();

      await world.repositories.cribs.delete('c1');

      // The records are kept, and they still point at a crib that exists.
      expect(world.store.expenses, hasLength(1));
      expect(world.store.settlements, hasLength(1));
      expect(world.store.cribs, hasLength(1));
      expect(world.store.cribs.single.isDeleted, isTrue);
      expect(world.store.expenses.single.cribId, 'c1');
      expect(world.store.settlements.single.cribId, 'c1');
    });

    test('the balances of the deleted crib still add up', () async {
      final world = worldWithHistory();

      await world.repositories.cribs.delete('c1');

      final balances = FinancialLedger.balances(
        crib: world.store.cribs.first,
        expenses: world.store.expenses,
        settlements: world.store.settlements,
      );
      expect(balances, {'me': 300, 'a': -300, 'r': 0});
    });

    test('the members lose access to the crib and to its records', () async {
      final world = worldWithHistory();

      await world.repositories.cribs.delete('c1');

      expect(world.repositories.cribs.cachedCribs, isEmpty);
      expect(world.repositories.expenses.cachedExpenses, isEmpty);
      expect(world.repositories.settlements.cachedSettlements, isEmpty);
      expect(world.repositories.activity.cachedEvents, isEmpty);
      await expectLater(
        world.repositories.cribs.getById('c1'),
        throwsA(
          isA<RepositoryException>().having(
            (error) => error.code,
            'code',
            RepositoryErrorCode.notFound,
          ),
        ),
      );
    });

    test('a deleted crib can be deleted only once', () async {
      final world = worldWithHistory();

      await world.repositories.cribs.delete('c1');
      await expectLater(
        world.repositories.cribs.delete('c1'),
        throwsA(
          isA<RepositoryException>().having(
            (error) => error.code,
            'code',
            RepositoryErrorCode.notFound,
          ),
        ),
      );
    });
  });
}
