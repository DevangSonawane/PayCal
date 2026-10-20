import 'package:flutter_test/flutter_test.dart';
import 'package:paycal/data/models.dart';
import 'package:paycal/data/repositories.dart';
import 'package:paycal/domain/financial_ledger.dart';

import 'support/harness.dart';

void main() {
  test('only the owner can add a member', () async {
    final world = TestHarness();
    world.store.currentUser = testUser('a');

    await expectLater(
      world.repositories.cribs.addMember(
        cribId: 'c1',
        member: Member(id: 'z', name: 'Zoya'),
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

  test('only the owner can remove a member', () async {
    final world = TestHarness();
    world.store.currentUser = testUser('a');

    await expectLater(
      world.repositories.cribs.removeMember(cribId: 'c1', memberId: 'r'),
      throwsA(
        isA<RepositoryException>().having(
          (error) => error.code,
          'code',
          RepositoryErrorCode.unauthorized,
        ),
      ),
    );
  });

  test('adding a member records the membership change', () async {
    final world = TestHarness();

    final crib = await world.repositories.cribs.addMember(
      cribId: 'c1',
      member: Member(id: 'z', name: 'Zoya'),
    );

    expect(crib.memberById('z'), isNotNull);
    expect(crib.memberById('z')!.isActive, isTrue);
    expect(crib.memberById('z')!.role, MemberRole.member);
    expect(
      world.store.activity.map((event) => event.action),
      contains('member_added'),
    );
  });

  test('a member that is added twice is a conflict', () async {
    final world = TestHarness();

    await expectLater(
      world.repositories.cribs.addMember(
        cribId: 'c1',
        member: Member(id: 'a', name: 'Asha'),
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

  test('removing a member keeps the financial history intact', () async {
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

    final crib = await world.repositories.cribs.removeMember(
      cribId: 'c1',
      memberId: 'a',
    );

    // The member stays in the crib so old expenses keep validating.
    expect(crib.memberById('a'), isNotNull);
    expect(crib.memberById('a')!.isActive, isFalse);
    expect(crib.memberById('a')!.leftAt, isNotNull);
    expect(crib.activeMembers.map((member) => member.id), ['me', 'r']);
    expect(
      world.store.activity.map((event) => event.action),
      contains('member_removed'),
    );
  });

  test('the ledger still validates expenses of a removed member', () async {
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
    final crib = await world.repositories.cribs.removeMember(
      cribId: 'c1',
      memberId: 'a',
    );

    final balances = FinancialLedger.balances(
      crib: crib,
      expenses: world.store.expenses,
      settlements: world.store.settlements,
    );

    expect(balances['a'], -500);
    expect(balances['me'], 500);
  });

  test('a removed member cannot add expenses any more', () async {
    final world = TestHarness();
    await world.repositories.cribs.removeMember(
      cribId: 'c1',
      memberId: 'a',
    );
    world.store.currentUser = testUser('a');

    await expectLater(
      world.repositories.expenses.create(
        testExpense(id: 'e2', payerId: 'a'),
      ),
      throwsA(isA<RepositoryException>()),
    );
  });

  test('the owner cannot be removed', () async {
    final world = TestHarness();

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
  });

  test('removing a member twice is a conflict', () async {
    final world = TestHarness();
    await world.repositories.cribs.removeMember(
      cribId: 'c1',
      memberId: 'r',
    );

    await expectLater(
      world.repositories.cribs.removeMember(cribId: 'c1', memberId: 'r'),
      throwsA(
        isA<RepositoryException>().having(
          (error) => error.code,
          'code',
          RepositoryErrorCode.conflict,
        ),
      ),
    );
  });

  test('removing an unknown member is not found', () async {
    final world = TestHarness();

    await expectLater(
      world.repositories.cribs.removeMember(cribId: 'c1', memberId: 'ghost'),
      throwsA(
        isA<RepositoryException>().having(
          (error) => error.code,
          'code',
          RepositoryErrorCode.notFound,
        ),
      ),
    );
  });

  test('membership cannot be changed through a crib update', () async {
    final world = TestHarness();
    final crib = await world.repositories.cribs.getById('c1');

    await expectLater(
      world.repositories.cribs.update(
        crib.copyWith(
          members: [
            crib.members.first,
            Member(id: 'z', name: 'Zoya'),
          ],
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

  test('a removed member can be added back', () async {
    final world = TestHarness();
    await world.repositories.cribs.removeMember(
      cribId: 'c1',
      memberId: 'r',
    );

    final crib = await world.repositories.cribs.addMember(
      cribId: 'c1',
      member: Member(id: 'r', name: 'Ravi'),
    );

    expect(crib.memberById('r')!.isActive, isTrue);
    expect(crib.memberById('r')!.leftAt, isNull);
  });
}
