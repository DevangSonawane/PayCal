import 'package:flutter_test/flutter_test.dart';
import 'package:paycal/data/models.dart';
import 'package:paycal/data/repositories.dart';

import 'support/harness.dart';

void main() {
  Expense sharedExpense({String id = 'e1', String payerId = 'me'}) => Expense(
    id: id,
    cribId: 'c1',
    description: 'Dinner',
    totalMinor: 1000,
    currency: 'INR',
    payerId: payerId,
    shares: {'me': 500, 'a': 500},
    date: DateTime(2026),
    category: 'other',
    createdById: payerId,
  );

  test('an expense can only be created by the payer', () async {
    final world = TestHarness();

    await expectLater(
      world.repositories.expenses.create(
        sharedExpense().copyWith(payerId: 'a'),
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

  test('a member outside the crib cannot add an expense', () async {
    final world = TestHarness();
    world.store.currentUser = testUser('stranger');

    await expectLater(
      world.repositories.expenses.create(sharedExpense()),
      throwsA(
        isA<RepositoryException>().having(
          (error) => error.code,
          'code',
          RepositoryErrorCode.unauthorized,
        ),
      ),
    );
  });

  test('the payer may edit the expense', () async {
    final world = TestHarness();
    final expense = sharedExpense();
    await world.repositories.expenses.create(expense);

    final updated = await world.repositories.expenses.update(
      expense.copyWith(totalMinor: 1200, shares: {'me': 600, 'a': 600}),
    );

    expect(updated.totalMinor, 1200);
    expect(updated.version, expense.version + 1);
  });

  test('the author may edit the expense of somebody else', () async {
    final world = TestHarness();
    final expense = sharedExpense(payerId: 'a');
    world.store.currentUser = testUser('a');
    await world.repositories.expenses.create(
      expense.copyWith(createdById: 'a'),
    );
    world.store.currentUser = testUser('a');

    final updated = await world.repositories.expenses.update(
      expense.copyWith(
        payerId: 'a',
        createdById: 'a',
        totalMinor: 900,
        shares: {'me': 450, 'a': 450},
      ),
    );

    expect(updated.totalMinor, 900);
  });

  test('another member may not edit the expense', () async {
    final world = TestHarness();
    final expense = sharedExpense();
    await world.repositories.expenses.create(expense);
    world.store.currentUser = testUser('a');

    await expectLater(
      world.repositories.expenses.update(
        expense.copyWith(totalMinor: 1200, shares: {'me': 1200}),
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

  test('another member may not delete the expense', () async {
    final world = TestHarness();
    final expense = sharedExpense();
    await world.repositories.expenses.create(expense);
    world.store.currentUser = testUser('a');

    await expectLater(
      world.repositories.expenses.delete(expense.id),
      throwsA(
        isA<RepositoryException>().having(
          (error) => error.code,
          'code',
          RepositoryErrorCode.unauthorized,
        ),
      ),
    );
  });

  test('any member of the crib may flag a dispute', () async {
    final world = TestHarness();
    final expense = sharedExpense();
    await world.repositories.expenses.create(expense);
    world.store.currentUser = testUser('a');

    final flagged = await world.repositories.expenses.flagDispute(expense.id);

    expect(flagged.disputed, isTrue);
  });

  test('a dispute keeps the money untouched', () async {
    final world = TestHarness();
    final expense = sharedExpense();
    await world.repositories.expenses.create(expense);
    world.store.currentUser = testUser('a');

    final flagged = await world.repositories.expenses.flagDispute(expense.id);

    expect(flagged.totalMinor, expense.totalMinor);
    expect(flagged.shares, expense.shares);
  });

  test('a stale expense version is a conflict', () async {
    final world = TestHarness();
    final expense = sharedExpense();
    await world.repositories.expenses.create(expense);
    await world.repositories.expenses.update(
      expense.copyWith(totalMinor: 1100, shares: {'me': 550, 'a': 550}),
    );

    await expectLater(
      world.repositories.expenses.update(
        expense.copyWith(totalMinor: 1300, shares: {'me': 650, 'a': 650}),
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

  test('the currency of an expense cannot be changed', () async {
    final world = TestHarness();
    final expense = sharedExpense();
    await world.repositories.expenses.create(expense);

    await expectLater(
      world.repositories.expenses.update(expense.copyWith(currency: 'USD')),
      throwsA(
        isA<RepositoryException>().having(
          (error) => error.code,
          'code',
          RepositoryErrorCode.unauthorized,
        ),
      ),
    );
  });

  test('the payer of an expense cannot be swapped', () async {
    final world = TestHarness();
    final expense = sharedExpense();
    await world.repositories.expenses.create(expense);

    await expectLater(
      world.repositories.expenses.update(expense.copyWith(payerId: 'a')),
      throwsA(
        isA<RepositoryException>().having(
          (error) => error.code,
          'code',
          RepositoryErrorCode.unauthorized,
        ),
      ),
    );
  });
}
