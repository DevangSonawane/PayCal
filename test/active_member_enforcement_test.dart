import 'package:flutter_test/flutter_test.dart';
import 'package:paycal/data/models.dart';
import 'package:paycal/data/repositories.dart';
import 'package:paycal/domain/financial_ledger.dart';

import 'support/harness.dart';

/// A member that left stays part of the history of a crib, so the records
/// they took part in keep validating. They are never part of a new financial
/// operation again.
void main() {
  Crib cribWith({
    List<Member>? members,
    String? removedId,
  }) {
    final crib = testCrib(
      members:
          members ??
          [
            Member(id: 'me', name: 'Me', role: MemberRole.owner),
            Member(id: 'a', name: 'Asha'),
          ],
    );
    if (removedId == null) return crib;
    return crib.copyWith(
      members: [
        for (final member in crib.members)
          if (member.id == removedId)
            member.copyWith(isActive: false, leftAt: DateTime(2026))
          else member,
      ],
    );
  }

  Expense expenseWith({
    String id = 'e1',
    String payer = 'me',
    Map<String, int>? shares,
    int total = 1000,
  }) => Expense(
    id: id,
    cribId: 'c1',
    description: 'Dinner',
    totalMinor: total,
    currency: 'INR',
    payerId: payer,
    shares: shares ?? {'me': 500, 'a': 500},
    date: DateTime(2026),
    category: 'other',
  );

  Settlement settlementWith({
    String id = 's1',
    String from = 'a',
    String to = 'me',
    int amount = 200,
    SettlementStatus status = SettlementStatus.confirmed,
  }) => Settlement(
    id: id,
    cribId: 'c1',
    currency: 'INR',
    fromMemberId: from,
    toMemberId: to,
    amountMinor: amount,
    status: status,
    createdAt: DateTime(2026),
  );

  group('the domain rule for a new expense', () {
    test('a removed member cannot be charged again', () {
      final crib = cribWith(removedId: 'a');

      expect(
        () => FinancialLedger.validateNewExpense(
          crib: crib,
          expense: expenseWith(),
        ),
        throwsA(isA<FinancialValidationException>()),
      );
    });

    test('a removed member cannot be the payer of a new expense', () {
      final crib = cribWith(removedId: 'a');

      expect(
        () => FinancialLedger.validateNewExpense(
          crib: crib,
          expense: expenseWith(payer: 'a', shares: {'a': 1000}),
        ),
        throwsA(isA<FinancialValidationException>()),
      );
    });

    test('an active member can still be charged', () {
      final crib = cribWith(removedId: 'r');

      expect(
        () => FinancialLedger.validateNewExpense(
          crib: crib,
          expense: expenseWith(),
        ),
        returnsNormally,
      );
    });
  });

  group('the domain rule for the history', () {
    test('the expenses of a removed member keep validating', () {
      final crib = cribWith(removedId: 'a');

      expect(
        () => FinancialLedger.validateExpense(
          crib: crib,
          expense: expenseWith(),
        ),
        returnsNormally,
      );
    });

    test('the balances of a crib survive the removal of a member', () {
      final crib = cribWith(removedId: 'a');

      final balances = FinancialLedger.balances(
        crib: crib,
        expenses: [expenseWith()],
        settlements: [settlementWith()],
      );

      expect(balances['a'], -300);
      expect(balances['me'], 300);
    });

    test('the balances of a crib survive the removal of a settling member',
        () {
      // The member left after the settlement was confirmed. The settlement is
      // part of the history and still has to count.
      final crib = cribWith(removedId: 'a');

      final balances = FinancialLedger.balances(
        crib: crib,
        expenses: [expenseWith()],
        settlements: [settlementWith(from: 'a', to: 'me', amount: 200)],
      );

      expect(balances['a'], -300);
      expect(balances['me'], 300);
    });
  });

  group('the domain rule for a new settlement', () {
    test('a removed member cannot take part in a new settlement', () {
      final crib = cribWith(removedId: 'a');

      expect(
        () => FinancialLedger.validateNewSettlement(
          crib: crib,
          settlement: settlementWith(from: 'a', to: 'me'),
        ),
        throwsA(isA<FinancialValidationException>()),
      );
    });

    test('the settlement of a removed member keeps validating', () {
      final crib = cribWith(removedId: 'a');

      expect(
        () => FinancialLedger.validateSettlement(
          crib: crib,
          settlement: settlementWith(from: 'a', to: 'me'),
        ),
        returnsNormally,
      );
    });
  });

  group('the repository follows the domain rule', () {
    test('a removed member cannot be charged', () async {
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
      await world.repositories.cribs.removeMember(
        cribId: 'c1',
        memberId: 'a',
      );

      await expectLater(
        world.repositories.expenses.create(
          Expense(
            id: 'e2',
            cribId: 'c1',
            description: 'Coffee',
            totalMinor: 200,
            currency: 'INR',
            payerId: 'me',
            shares: {'me': 100, 'a': 100},
            date: DateTime(2026),
            category: 'other',
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

    test('a metadata-only edit of an expense with a removed member works',
        () async {
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
      await world.repositories.cribs.removeMember(
        cribId: 'c1',
        memberId: 'a',
      );

      final updated = await world.repositories.expenses.update(
        (await world.repositories.expenses.getById('e1')).copyWith(
          description: 'Dinner at home',
        ),
      );

      expect(updated.description, 'Dinner at home');
    });

    test('a share change that keeps the removed member is refused', () async {
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
      await world.repositories.cribs.removeMember(
        cribId: 'c1',
        memberId: 'a',
      );

      await expectLater(
        world.repositories.expenses.update(
          (await world.repositories.expenses.getById('e1')).copyWith(
            totalMinor: 1200,
            shares: {'me': 600, 'a': 600},
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

    test('a removed member cannot be added to a share again', () async {
      final world = TestHarness(
        expenses: [
          Expense(
            id: 'e1',
            cribId: 'c1',
            description: 'Dinner',
            totalMinor: 1000,
            currency: 'INR',
            payerId: 'me',
            shares: {'me': 1000},
            date: DateTime(2026),
            category: 'other',
          ),
        ],
      );
      await world.repositories.cribs.removeMember(
        cribId: 'c1',
        memberId: 'a',
      );

      await expectLater(
        world.repositories.expenses.update(
          (await world.repositories.expenses.getById('e1')).copyWith(
            totalMinor: 1200,
            shares: {'me': 1000, 'a': 200},
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
  });
}
