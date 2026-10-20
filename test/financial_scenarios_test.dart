import 'package:flutter_test/flutter_test.dart';
import 'package:paycal/data/models.dart';
import 'package:paycal/data/repositories.dart';
import 'package:paycal/domain/financial_ledger.dart';

import 'support/harness.dart';

/// The money rules, checked against hand-computed expectations.
///
/// The expected numbers in this file are worked out by hand, not by calling
/// the ledger again. That is the point: a test that recomputes the answer
/// with the same code proves nothing.
void main() {
  /// A crib with "me" (owner), "a" and "b".
  TestHarness threeMembers({List<Expense>? expenses}) => TestHarness(
    cribs: [
      testCrib(
        members: [
          Member(id: 'me', name: 'Me', role: MemberRole.owner),
          Member(id: 'a', name: 'Asha'),
          Member(id: 'b', name: 'Bala'),
        ],
      ),
    ],
    expenses: expenses ??
        [
          Expense(
            id: 'e1',
            cribId: 'c1',
            description: 'Dinner',
            totalMinor: 1000,
            currency: 'INR',
            payerId: 'me',
            shares: {'me': 334, 'a': 333, 'b': 333},
            date: DateTime(2026),
            category: 'other',
          ),
          Expense(
            id: 'e2',
            cribId: 'c1',
            description: 'Lunch',
            totalMinor: 900,
            currency: 'INR',
            payerId: 'a',
            shares: {'me': 300, 'a': 300, 'b': 300},
            date: DateTime(2026),
            category: 'other',
          ),
        ],
  );

  Map<String, int> balancesOf(TestHarness world) => FinancialLedger.balances(
    crib: world.store.cribs.first,
    expenses: world.store.expenses,
    settlements: world.store.settlements,
  );

  group('splits', () {
    test('an equal split gives the remainder to the payer', () {
      // 1000 over three people is 333.33 each. The two extra minor units go
      // to the payer, so the shares are 334 / 333 / 333 and they add up to
      // exactly 1000.
      final shares = FinancialLedger.equalSplit(
        totalMinor: 1000,
        participantIds: const ['me', 'a', 'b'],
        payerId: 'me',
      );

      expect(shares, {'me': 334, 'a': 333, 'b': 333});
      expect(shares.values.reduce((a, b) => a + b), 1000);
    });

    test('an equal split of a whole number is exact', () {
      final shares = FinancialLedger.equalSplit(
        totalMinor: 900,
        participantIds: const ['me', 'a', 'b'],
        payerId: 'me',
      );

      expect(shares, {'me': 300, 'a': 300, 'b': 300});
    });

    test('a percentage split is exact in minor units', () {
      // 33.33 % of 1000 is 333.3, so the percentages cannot be used directly.
      // The basis points are 3333 / 3333 / 3334.
      final shares = FinancialLedger.percentageSplit(
        totalMinor: 1000,
        basisPoints: const {'me': 3333, 'a': 3333, 'b': 3334},
        payerId: 'me',
      );

      expect(shares.values.reduce((a, b) => a + b), 1000);
      // 333.3 falls to 333 for each of them, and the one minor unit that is
      // left goes to the payer, the same rule the equal split uses.
      expect(shares['me'], 334);
      expect(shares['a'], 333);
      expect(shares['b'], 333);
    });

    test('a percentage split that does not add up to 100 is refused', () {
      expect(
        () => FinancialLedger.percentageSplit(
          totalMinor: 1000,
          basisPoints: const {'me': 5000, 'a': 4000},
          payerId: 'me',
        ),
        throwsA(isA<Object>()),
      );
    });
  });

  group('balances with more than one payer', () {
    test('the net position of every member is right', () {
      // Dinner: me paid 1000 and consumed 334, so me is owed 666.
      // Lunch: a paid 900 and consumed 300, so a is owed 600.
      // me consumed 300 of the lunch, a consumed 333 of the dinner,
      // b consumed 333 + 300.
      final world = threeMembers();

      expect(balancesOf(world), {'me': 366, 'a': 267, 'b': -633});
    });

    test('the balances always add up to zero', () {
      final world = threeMembers();
      final balances = balancesOf(world);

      expect(balances.values.reduce((a, b) => a + b), 0);
    });
  });

  group('editing and deleting an expense', () {
    test('editing the amount changes the balances', () async {
      final world = threeMembers();
      expect(balancesOf(world)['me'], 366);

      // The dinner was 1000, now it is 600. "me" fronted 600 and consumed
      // 200 (600 over three people, 200 each), so "me" is owed 400 and the
      // others owe 200 each.
      await world.repositories.expenses.update(
        (await world.repositories.expenses.getById('e1')).copyWith(
          totalMinor: 600,
          shares: const {'me': 200, 'a': 200, 'b': 200},
        ),
      );

      // me: 600 - 200 = 400, then -300 of the lunch = 100.
      // a: -200, then 900 - 300 = 600, so 400.
      // b: -200, then -300 = -500.
      expect(balancesOf(world), {'me': 100, 'a': 400, 'b': -500});
      expect(balancesOf(world).values.reduce((a, b) => a + b), 0);
    });

    test('deleting an expense changes the balances back', () async {
      final world = threeMembers();
      final before = balancesOf(world);

      await world.repositories.expenses.delete('e1');

      // Without the dinner only the lunch is left: me -300, a +600, b -300.
      expect(balancesOf(world), {'me': -300, 'a': 600, 'b': -300});
      expect(balancesOf(world).values.reduce((a, b) => a + b), 0);
      expect(before['me'], 366);
    });

    test('a failed edit leaves the ledger untouched', () async {
      final world = threeMembers();
      final before = balancesOf(world);

      await expectLater(
        world.repositories.expenses.update(
          (await world.repositories.expenses.getById('e1')).copyWith(
            totalMinor: 700,
            // The shares do not add up to the total any more.
            shares: const {'me': 200, 'a': 200, 'b': 200},
          ),
        ),
        throwsA(isA<RepositoryException>()),
      );

      expect(balancesOf(world), before);
    });
  });

  group('settlements', () {
    test('a partial settlement leaves the rest as debt', () async {
      final world = threeMembers();
      world.signIn('b');

      await world.repositories.settlements.create(
        Settlement(
          id: 's1',
          cribId: 'c1',
          currency: 'INR',
          fromMemberId: 'b',
          toMemberId: 'me',
          amountMinor: 200,
          status: SettlementStatus.selfManaged,
          createdAt: DateTime(2026),
        ),
      );

      // b owes "me" 333 directly (the dinner) and "a" 300 (the lunch).
      // After paying 200 to "me", b still owes "me" 133.
      expect(balancesOf(world), {'me': 166, 'a': 267, 'b': -433});
      expect(
        FinancialLedger.pairwiseDebt(
          crib: world.store.cribs.first,
          expenses: world.store.expenses,
          settlements: world.store.settlements,
          fromId: 'b',
          toId: 'me',
        ),
        133,
      );
      expect(
        FinancialLedger.pairwiseDebt(
          crib: world.store.cribs.first,
          expenses: world.store.expenses,
          settlements: world.store.settlements,
          fromId: 'b',
          toId: 'a',
        ),
        300,
      );
    });

    test('the suggested transfers bring the crib to zero', () async {
      final world = threeMembers();
      final transfers = FinancialLedger.suggestedTransfers(
        crib: world.store.cribs.first,
        expenses: world.store.expenses,
        settlements: world.store.settlements,
      );

      // "me" and "a" owe each other money (333 and 300), so the mutual
      // part cancels and only the 33 that "me" is owed stays. "b" owes
      // "me" 333 and "a" 300.
      expect(
        transfers
            .map((t) => (t.fromId, t.toId, t.amountMinor))
            .toSet(),
        {
          ('a', 'me', 33),
          ('b', 'me', 333),
          ('b', 'a', 300),
        },
      );

      for (final transfer in transfers) {
        world.signIn(transfer.fromId);
        await world.repositories.settlements.create(
          Settlement(
            id: 's-${transfer.fromId}-${transfer.toId}',
            cribId: 'c1',
            currency: 'INR',
            fromMemberId: transfer.fromId,
            toMemberId: transfer.toId,
            amountMinor: transfer.amountMinor,
            status: SettlementStatus.selfManaged,
            createdAt: DateTime(2026),
          ),
        );
      }

      for (final balance in balancesOf(world).values) {
        expect(balance, 0, reason: 'every member has to be square');
      }
    });

    test('a repeated submission records the settlement once', () async {
      final world = threeMembers();
      world.signIn('b');

      Settlement build(String id) => Settlement(
        id: id,
        cribId: 'c1',
        currency: 'INR',
        fromMemberId: 'b',
        toMemberId: 'me',
        amountMinor: 200,
        status: SettlementStatus.selfManaged,
        createdAt: DateTime(2026),
        idempotencyKey: 'same-key',
      );

      final first = await world.repositories.settlements.create(build('s1'));
      final replay = await world.repositories.settlements.create(build('s2'));

      expect(replay.id, first.id);
      expect(world.store.settlements, hasLength(1));
      // One settlement of 200, not two.
      expect(balancesOf(world)['me'], 166);
    });

    test('a refused settlement does not change the ledger', () async {
      final world = threeMembers();
      final before = balancesOf(world);
      world.signIn('b');

      await expectLater(
        world.repositories.settlements.create(
          Settlement(
            id: 's1',
            cribId: 'c1',
            currency: 'INR',
            fromMemberId: 'b',
            toMemberId: 'a',
            amountMinor: 400,
            status: SettlementStatus.selfManaged,
            createdAt: DateTime(2026),
          ),
        ),
        throwsA(isA<RepositoryException>()),
      );

      expect(world.store.settlements, isEmpty);
      expect(balancesOf(world), before);
    });
  });

  group('currency precision', () {
    test('one minor unit survives the whole round trip', () async {
      final world = TestHarness(
        expenses: [
          Expense(
            id: 'e1',
            cribId: 'c1',
            description: 'Pocket money',
            totalMinor: 2,
            currency: 'INR',
            payerId: 'me',
            shares: {'me': 1, 'a': 1},
            date: DateTime(2026),
            category: 'other',
          ),
        ],
      );

      expect(balancesOf(world), {'me': 1, 'a': -1, 'r': 0});
    });

    test('a large amount keeps every minor unit', () async {
      final world = TestHarness(
        expenses: [
          Expense(
            id: 'e1',
            cribId: 'c1',
            description: 'Big',
            totalMinor: 9007199254740991,
            currency: 'INR',
            payerId: 'me',
            shares: {'me': 0, 'a': 9007199254740991},
            date: DateTime(2026),
            category: 'other',
          ),
        ],
      );

      expect(balancesOf(world)['me'], 9007199254740991);
      expect(balancesOf(world)['a'], -9007199254740991);
    });

    test('an amount in another currency is refused', () async {
      final world = threeMembers();

      await expectLater(
        world.repositories.expenses.create(
          Expense(
            id: 'e2',
            cribId: 'c1',
            description: 'Dollars',
            totalMinor: 100,
            currency: 'USD',
            payerId: 'me',
            shares: {'me': 100},
            date: DateTime(2026),
            category: 'other',
          ),
        ),
        throwsA(isA<RepositoryException>()),
      );
    });
  });
}
