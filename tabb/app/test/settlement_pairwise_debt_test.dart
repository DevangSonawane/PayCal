import 'package:flutter_test/flutter_test.dart';
import 'package:paycal/data/models.dart';
import 'package:paycal/data/repositories.dart';
import 'package:paycal/domain/financial_ledger.dart';

import 'support/harness.dart';

/// The overpayment rule of a settlement is about the debt of the sender to
/// the recipient, not about the net position of the sender in the crib.
///
/// The scenarios below are the two failure directions of the old net rule:
///   a. a payer settled a person they did not owe anything to
///   b. a legitimate small payment was refused because of unrelated netting
void main() {
  /// Crib "c1" with the members "me" (owner), "a", "r" and "d".
  ///
  /// * "me" paid 1000 for a dinner split with "a": a owes me 500.
  /// * "r" paid 600 for a dinner split with "me": me owes r 300.
  /// * "me" paid 400 for a dinner split with "d": d owes me 200.
  ///
  /// Net positions: me -100, a -500, r +300, d -200. The net rule would let
  /// "a" pay up to 500 to anybody, including "r" which "a" never owes
  /// anything to.
  TestHarness sharedCrib() => TestHarness(
    cribs: [
      testCrib(
        members: [
          Member(id: 'me', name: 'Me', role: MemberRole.owner),
          Member(id: 'a', name: 'Asha'),
          Member(id: 'r', name: 'Ravi'),
          Member(id: 'd', name: 'Dara'),
        ],
      ),
    ],
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
      Expense(
        id: 'e2',
        cribId: 'c1',
        description: 'Ravi dinner',
        totalMinor: 600,
        currency: 'INR',
        payerId: 'r',
        shares: {'r': 300, 'me': 300},
        date: DateTime(2026),
        category: 'other',
      ),
      Expense(
        id: 'e3',
        cribId: 'c1',
        description: 'Dara dinner',
        totalMinor: 400,
        currency: 'INR',
        payerId: 'me',
        shares: {'me': 200, 'd': 200},
        date: DateTime(2026),
        category: 'other',
      ),
    ],
  );

  Settlement settlement({
    String id = 's1',
    String from = 'a',
    String to = 'me',
    int amount = 100,
    SettlementStatus status = SettlementStatus.selfManaged,
    String? idempotencyKey,
  }) => Settlement(
    id: id,
    cribId: 'c1',
    currency: 'INR',
    fromMemberId: from,
    toMemberId: to,
    amountMinor: amount,
    status: status,
    createdAt: DateTime(2026),
    idempotencyKey: idempotencyKey,
  );

  group('the debt of the payer to the recipient', () {
    test('a payer cannot settle a person they owe nothing to', () async {
      final world = sharedCrib();
      world.signIn('a');

      // "a" owes "me" 500 and owes "r" 0. The old net rule allowed a
      // settlement to "r" because "a" was a net debtor of the crib.
      await expectLater(
        world.repositories.settlements.create(
          settlement(id: 's1', from: 'a', to: 'r', amount: 300),
        ),
        throwsA(
          isA<RepositoryException>().having(
            (error) => error.code,
            'code',
            RepositoryErrorCode.validation,
          ),
        ),
      );
      expect(world.store.settlements, isEmpty);
    });

    test('a payer cannot settle more than they owe to the recipient', () async {
      final world = sharedCrib();
      world.signIn('a');

      await expectLater(
        world.repositories.settlements.create(
          settlement(id: 's1', from: 'a', to: 'me', amount: 501),
        ),
        throwsA(
          isA<RepositoryException>().having(
            (error) => error.code,
            'code',
            RepositoryErrorCode.validation,
          ),
        ),
      );
      expect(world.store.settlements, isEmpty);
    });

    test('a legitimate payment is not refused because of unrelated netting',
        () async {
      // "a" owes "me" 500, but "a" is only 50 behind in the crib because
      // "a" paid 900 of which "d" consumed 450. The net rule refused any
      // payment above 50, the pairwise rule allows the full debt.
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
          Expense(
            id: 'e2',
            cribId: 'c1',
            description: 'A pays for d',
            totalMinor: 900,
            currency: 'INR',
            payerId: 'a',
            shares: {'a': 450, 'd': 450},
            date: DateTime(2026),
            category: 'other',
          ),
        ],
        cribs: [
          testCrib(
            members: [
              Member(id: 'me', name: 'Me', role: MemberRole.owner),
              Member(id: 'a', name: 'Asha'),
              Member(id: 'd', name: 'Dara'),
            ],
          ),
        ],
      );
      world.signIn('a');

      final created = await world.repositories.settlements.create(
        settlement(id: 's1', from: 'a', to: 'me', amount: 100),
      );

      expect(created.amountMinor, 100);
      expect(world.store.settlements, hasLength(1));
    });
  });

  group('partial payments', () {
    test('a partial payment is allowed and leaves the rest as debt', () async {
      final world = sharedCrib();
      world.signIn('a');

      await world.repositories.settlements.create(
        settlement(id: 's1', from: 'a', to: 'me', amount: 200),
      );

      // 500 owed, 200 paid, so 300 is still owed.
      final remaining = await world.repositories.settlements.create(
        settlement(id: 's2', from: 'a', to: 'me', amount: 300),
      );
      expect(remaining.amountMinor, 300);

      // The debt is used up now.
      await expectLater(
        world.repositories.settlements.create(
          settlement(id: 's3', from: 'a', to: 'me', amount: 1),
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

    test('a pending request does not use up the debt', () async {
      final world = sharedCrib();
      world.signIn('a');

      // A pending request is only a request, the recipient still has to
      // confirm it, so the debt is not used up yet.
      await world.repositories.settlements.create(
        settlement(
          id: 's1',
          from: 'a',
          to: 'me',
          amount: 500,
          status: SettlementStatus.pending,
        ),
      );

      expect(world.store.settlements, hasLength(1));
    });
  });

  group('retries and idempotency', () {
    test('the same request returns the original settlement', () async {
      final world = sharedCrib();
      world.signIn('a');

      final first = await world.repositories.settlements.create(
        settlement(id: 's1', from: 'a', to: 'me', amount: 200, idempotencyKey: 'k1'),
      );
      final replay = await world.repositories.settlements.create(
        settlement(id: 's2', from: 'a', to: 'me', amount: 200, idempotencyKey: 'k1'),
      );

      expect(replay.id, first.id);
      expect(world.store.settlements, hasLength(1));
    });

    test('the same key with a different payload is a conflict', () async {
      final world = sharedCrib();
      world.signIn('a');

      await world.repositories.settlements.create(
        settlement(id: 's1', from: 'a', to: 'me', amount: 200, idempotencyKey: 'k1'),
      );

      await expectLater(
        world.repositories.settlements.create(
          settlement(
            id: 's2',
            from: 'a',
            to: 'me',
            amount: 300,
            idempotencyKey: 'k1',
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
      expect(world.store.settlements, hasLength(1));
    });

    test('the same key used by another sender does not return their row',
        () async {
      final world = sharedCrib();
      world.signIn('a');
      final first = await world.repositories.settlements.create(
        settlement(id: 's1', from: 'a', to: 'me', amount: 200, idempotencyKey: 'k1'),
      );

      // "d" reuses the key. The key is scoped to the sender, so this is a
      // different request and never returns the settlement of "a".
      world.signIn('d');
      final second = await world.repositories.settlements.create(
        settlement(id: 's2', from: 'd', to: 'me', amount: 100, idempotencyKey: 'k1'),
      );

      expect(second.id, isNot(first.id));
      expect(world.store.settlements, hasLength(2));
    });
  });

  group('auditable corrections', () {
    test('a confirmed settlement is never silently changed', () async {
      final world = sharedCrib();
      world.signIn('a');
      await world.repositories.settlements.create(
        settlement(
          id: 's1',
          from: 'a',
          to: 'me',
          amount: 200,
          status: SettlementStatus.pending,
        ),
      );
      world.signIn('me');
      await world.repositories.settlements.updateStatus(
        's1',
        SettlementStatus.confirmed,
      );

      final before = world.store.settlements.single;
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
      expect(world.store.settlements.single.amountMinor, before.amountMinor);
    });

    test('the activity feed keeps every settlement event', () async {
      final world = sharedCrib();
      world.signIn('a');
      await world.repositories.settlements.create(
        settlement(id: 's1', from: 'a', to: 'me', amount: 200),
      );

      final actions = world.store.activity.map((event) => event.action).toList();
      expect(actions, contains('settlement_created'));
    });
  });

  group('suggested transfers stay recordable', () {
    test('every suggested transfer is inside the debt of that pair', () async {
      final world = sharedCrib();

      final transfers = FinancialLedger.suggestedTransfers(
        crib: world.store.cribs.first,
        expenses: world.store.expenses,
        settlements: world.store.settlements,
      );

      expect(transfers, isNotEmpty);
      for (final transfer in transfers) {
        final debt = FinancialLedger.pairwiseDebt(
          crib: world.store.cribs.first,
          expenses: world.store.expenses,
          settlements: world.store.settlements,
          fromId: transfer.fromId,
          toId: transfer.toId,
        );
        expect(
          transfer.amountMinor,
          lessThanOrEqualTo(debt),
          reason: '${transfer.fromId} to ${transfer.toId} must stay inside the debt',
        );
      }
    });

    test('a suggested transfer of a net square crib is not refused', () async {
      // "me" paid for "a", "a" paid for "me". The crib is square, so there
      // is nothing to settle.
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
          Expense(
            id: 'e2',
            cribId: 'c1',
            description: 'Lunch',
            totalMinor: 1000,
            currency: 'INR',
            payerId: 'a',
            shares: {'a': 500, 'me': 500},
            date: DateTime(2026),
            category: 'other',
          ),
        ],
      );

      final transfers = FinancialLedger.suggestedTransfers(
        crib: world.store.cribs.first,
        expenses: world.store.expenses,
        settlements: world.store.settlements,
      );

      expect(transfers, isEmpty);
    });

    test('every suggested transfer can actually be recorded', () async {
      // The settle-up sheet offers the suggested transfers and records them
      // through the repository. A suggestion the repository refuses would
      // break the sheet.
      final world = sharedCrib();

      final transfers = FinancialLedger.suggestedTransfers(
        crib: world.store.cribs.first,
        expenses: world.store.expenses,
        settlements: world.store.settlements,
      );
      expect(transfers, isNotEmpty);

      for (final transfer in transfers) {
        world.signIn(transfer.fromId);
        final recorded = await world.repositories.settlements.create(
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
        expect(recorded.amountMinor, transfer.amountMinor);
      }
    });

    test('recording the suggested transfers brings the crib to zero', () async {
      final world = sharedCrib();

      final transfers = FinancialLedger.suggestedTransfers(
        crib: world.store.cribs.first,
        expenses: world.store.expenses,
        settlements: world.store.settlements,
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

      final balances = FinancialLedger.balances(
        crib: world.store.cribs.first,
        expenses: world.store.expenses,
        settlements: world.store.settlements,
      );
      for (final balance in balances.values) {
        expect(balance, 0, reason: 'every member has to be square');
      }
    });
  });

  group('the ledger stays consistent', () {
    test('the net balance is the pairwise debt of every pair, summed up', () {
      // The net position of a member and the pairwise debt have to agree, or
      // the settle-up sheet and the validation would contradict each other.
      final world = sharedCrib();
      final crib = world.store.cribs.first;

      final balances = FinancialLedger.balances(
        crib: crib,
        expenses: world.store.expenses,
        settlements: world.store.settlements,
      );
      final debts = FinancialLedger.pairwiseDebts(
        crib: crib,
        expenses: world.store.expenses,
        settlements: world.store.settlements,
      );

      final derived = <String, int>{};
      for (final entry in debts.entries) {
        for (final to in entry.value.entries) {
          derived[entry.key] = (derived[entry.key] ?? 0) - to.value;
          derived[to.key] = (derived[to.key] ?? 0) + to.value;
        }
      }
      for (final member in crib.members) {
        expect(
          derived[member.id] ?? 0,
          balances[member.id] ?? 0,
          reason: 'the net position of ${member.id} has to match the pairwise debt',
        );
      }
    });

    test('a rejected settlement does not touch the ledger', () async {
      final world = sharedCrib();
      world.signIn('a');
      final before = FinancialLedger.balances(
        crib: world.store.cribs.first,
        expenses: world.store.expenses,
        settlements: world.store.settlements,
      );
      final expensesBefore = world.store.expenses.length;
      final eventsBefore = world.store.activity.length;

      await expectLater(
        world.repositories.settlements.create(
          settlement(id: 's1', from: 'a', to: 'r', amount: 100),
        ),
        throwsA(isA<RepositoryException>()),
      );

      expect(world.store.settlements, isEmpty);
      expect(world.store.expenses.length, expensesBefore);
      expect(world.store.activity.length, eventsBefore);
      expect(
        FinancialLedger.balances(
          crib: world.store.cribs.first,
          expenses: world.store.expenses,
          settlements: world.store.settlements,
        ),
        before,
      );
    });
  });
}
