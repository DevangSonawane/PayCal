import 'package:flutter_test/flutter_test.dart';
import 'package:paycal/data/models.dart';
import 'package:paycal/data/repositories.dart';

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

  test('deleting a crib removes the records that belong to it', () async {
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

    expect(world.store.cribs, isEmpty);
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
}
