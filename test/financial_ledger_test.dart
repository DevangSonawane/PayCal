import 'package:flutter_test/flutter_test.dart';
import 'package:paycal/data/models.dart';
import 'package:paycal/domain/financial_ledger.dart';

void main() {
  final crib = Crib(
    id: 'crib',
    name: 'Flat',
    currency: 'INR',
    members: [
      Member(id: 'a', name: 'A'),
      Member(id: 'b', name: 'B'),
      Member(id: 'c', name: 'C'),
    ],
    categories: const ['other'],
  );

  Expense expense({
    String id = 'expense',
    int total = 1000,
    String payer = 'a',
    Map<String, int> shares = const {'a': 334, 'b': 333, 'c': 333},
    String currency = 'INR',
  }) => Expense(
    id: id,
    cribId: crib.id,
    description: 'Test',
    totalMinor: total,
    currency: currency,
    payerId: payer,
    shares: shares,
    date: DateTime(2026),
    category: 'other',
  );

  Settlement settlement({
    String id = 'settlement',
    String from = 'b',
    String to = 'a',
    int amount = 333,
    SettlementStatus status = SettlementStatus.confirmed,
  }) => Settlement(
    id: id,
    cribId: crib.id,
    currency: crib.currency,
    fromMemberId: from,
    toMemberId: to,
    amountMinor: amount,
    status: status,
    createdAt: DateTime(2026),
  );

  group('splits', () {
    test('equal split uses payer-first deterministic remainder', () {
      expect(
        FinancialLedger.equalSplit(
          totalMinor: 1000,
          participantIds: const ['b', 'a', 'c'],
          payerId: 'a',
        ),
        {'a': 334, 'b': 333, 'c': 333},
      );
    });

    test('percentage split is exact in minor units', () {
      final shares = FinancialLedger.percentageSplit(
        totalMinor: 101,
        basisPoints: const {'a': 5000, 'b': 2500, 'c': 2500},
        payerId: 'a',
      );
      expect(shares.values.reduce((a, b) => a + b), 101);
      expect(shares, {'a': 51, 'b': 25, 'c': 25});
    });

    test('rejects duplicate, invalid and incomplete split inputs', () {
      expect(
        () => FinancialLedger.equalSplit(
          totalMinor: 10,
          participantIds: const ['a', 'a'],
          payerId: 'a',
        ),
        throwsA(isA<FinancialValidationException>()),
      );
      expect(
        () => FinancialLedger.percentageSplit(
          totalMinor: 10,
          basisPoints: const {'a': 9999},
          payerId: 'a',
        ),
        throwsA(isA<FinancialValidationException>()),
      );
    });
  });

  group('expense validation', () {
    test('rejects invalid payer, participant, share sum and currency', () {
      for (final invalid in [
        expense(payer: 'missing'),
        expense(shares: const {'missing': 1000}),
        expense(shares: const {'a': 999}),
        expense(currency: 'USD'),
        expense(total: 0, shares: const {'a': 0}),
      ]) {
        expect(
          () => FinancialLedger.validateExpense(crib: crib, expense: invalid),
          throwsA(isA<FinancialValidationException>()),
        );
      }
    });

    test('expense copies retain immutable shares', () {
      final source = <String, int>{'a': 334, 'b': 333, 'c': 333};
      final value = expense(shares: source);
      source['a'] = 1;
      expect(value.shares['a'], 334);
      expect(() => value.shares['a'] = 1, throwsUnsupportedError);
    });
  });

  group('ledger balances', () {
    test('edits and deletions recalculate instead of applying deltas', () {
      expect(FinancialLedger.balances(crib: crib, expenses: [expense()]), {
        'a': 666,
        'b': -333,
        'c': -333,
      });
      final edited = expense(
        total: 900,
        shares: const {'a': 300, 'b': 300, 'c': 300},
      );
      expect(FinancialLedger.balances(crib: crib, expenses: [edited]), {
        'a': 600,
        'b': -300,
        'c': -300,
      });
      expect(FinancialLedger.balances(crib: crib, expenses: const []), {
        'a': 0,
        'b': 0,
        'c': 0,
      });
    });

    test('partial confirmed settlement changes only the two balances', () {
      final balances = FinancialLedger.balances(
        crib: crib,
        expenses: [expense()],
        settlements: [settlement(amount: 100)],
      );
      expect(balances, {'a': 566, 'b': -233, 'c': -333});
    });

    test('pending and cancelled settlements do not affect balances', () {
      final baseline = FinancialLedger.balances(
        crib: crib,
        expenses: [expense()],
      );
      for (final status in [
        SettlementStatus.pending,
        SettlementStatus.cancelled,
      ]) {
        expect(
          FinancialLedger.balances(
            crib: crib,
            expenses: [expense()],
            settlements: [settlement(status: status)],
          ),
          baseline,
        );
      }
    });

    test('suggested transfers honour existing partial settlements', () {
      expect(
        FinancialLedger.suggestedTransfers(
          crib: crib,
          expenses: [expense()],
          settlements: [settlement(amount: 333)],
        ).map(
          (transfer) => (transfer.fromId, transfer.toId, transfer.amountMinor),
        ),
        [('c', 'a', 333)],
      );
    });
  });

  group('pairwise debt', () {
    test('a member owes the person who paid for them', () {
      // "b" and "c" consumed 333 each of the money "a" paid.
      expect(
        FinancialLedger.pairwiseDebt(
          crib: crib,
          expenses: [expense()],
          fromId: 'b',
          toId: 'a',
        ),
        333,
      );
      expect(
        FinancialLedger.pairwiseDebt(
          crib: crib,
          expenses: [expense()],
          fromId: 'a',
          toId: 'b',
        ),
        0,
        reason: 'a did not consume any money of b',
      );
    });

    test('a settlement reduces the debt of that pair only', () {
      expect(
        FinancialLedger.pairwiseDebt(
          crib: crib,
          expenses: [expense()],
          settlements: [settlement(from: 'b', to: 'a', amount: 100)],
          fromId: 'b',
          toId: 'a',
        ),
        233,
      );
      expect(
        FinancialLedger.pairwiseDebt(
          crib: crib,
          expenses: [expense()],
          settlements: [settlement(from: 'b', to: 'a', amount: 100)],
          fromId: 'c',
          toId: 'a',
        ),
        333,
      );
    });

    test('a pending settlement does not reduce the debt', () {
      expect(
        FinancialLedger.pairwiseDebt(
          crib: crib,
          expenses: [expense()],
          settlements: [
            settlement(
              from: 'b',
              to: 'a',
              amount: 100,
              status: SettlementStatus.pending,
            ),
          ],
          fromId: 'b',
          toId: 'a',
        ),
        333,
      );
    });

    test('a member never owes themselves', () {
      expect(
        FinancialLedger.pairwiseDebt(
          crib: crib,
          expenses: [expense()],
          fromId: 'a',
          toId: 'a',
        ),
        0,
      );
    });

    test('the net position and the pairwise debt are different questions', () {
      // "a" paid 1000 and consumed 334 of it, so the crib owes "a" 666. The
      // net position of "a" is +666, but "a" does not owe anybody a penny.
      final balances = FinancialLedger.balances(
        crib: crib,
        expenses: [expense()],
      );
      expect(balances['a'], 666);
      expect(
        FinancialLedger.pairwiseDebts(
          crib: crib,
          expenses: [expense()],
        ),
        {
          'b': {'a': 333},
          'c': {'a': 333},
        },
      );
    });
  });

  group('suggested transfers', () {
    test('a member never suggests a transfer above the pairwise debt', () {
      final transfers = FinancialLedger.suggestedTransfers(
        crib: crib,
        expenses: [expense()],
      );

      for (final transfer in transfers) {
        final debt = FinancialLedger.pairwiseDebt(
          crib: crib,
          expenses: [expense()],
          fromId: transfer.fromId,
          toId: transfer.toId,
        );
        expect(transfer.amountMinor, lessThanOrEqualTo(debt));
      }
    });

    test('debts that cancel each other out are not suggested', () {
      // "a" paid for "b" and "b" paid for "a", so the crib is square.
      final square = FinancialLedger.suggestedTransfers(
        crib: crib,
        expenses: [
          expense(id: 'first', shares: const {'a': 500, 'b': 500}),
          expense(
            id: 'second',
            payer: 'b',
            shares: const {'b': 500, 'a': 500},
          ),
        ],
      );

      expect(square, isEmpty);
    });

    test('a debt cycle is not suggested', () {
      // "a" paid for "b", "b" paid for "c" and "c" paid for "a". The three
      // debts cancel each other out, so the crib is square.
      final cycle = FinancialLedger.suggestedTransfers(
        crib: crib,
        expenses: [
          expense(id: 'first', payer: 'a', shares: const {'a': 500, 'b': 500}),
          expense(id: 'second', payer: 'b', shares: const {'b': 500, 'c': 500}),
          expense(id: 'third', payer: 'c', shares: const {'c': 500, 'a': 500}),
        ],
      );

      expect(cycle, isEmpty);
    });

    test('a chain of debts is settled pair by pair', () {
      // "a" paid for "b" and "b" paid for "c". "b" owes "a" and "c" owes
      // "b", so the debts are settled one pair at a time.
      final chain = FinancialLedger.suggestedTransfers(
        crib: crib,
        expenses: [
          expense(id: 'first', payer: 'a', shares: const {'a': 500, 'b': 500}),
          expense(id: 'second', payer: 'b', shares: const {'b': 500, 'c': 500}),
        ],
      );

      expect(
        chain.map((transfer) => (transfer.fromId, transfer.toId, transfer.amountMinor)),
        [('b', 'a', 500), ('c', 'b', 500)],
      );
    });
  });
}
