import 'package:flutter_test/flutter_test.dart';
import 'package:paycal/data/in_memory_repositories.dart';
import 'package:paycal/data/dtos.dart';
import 'package:paycal/data/models.dart';
import 'package:paycal/data/repositories.dart';
import 'package:paycal/domain/financial_ledger.dart';

void main() {
  late InMemoryStore store;
  late InMemoryCribRepository cribs;
  late InMemoryExpenseRepository expenses;
  late InMemorySettlementRepository settlements;
  late InMemoryActivityRepository activity;
  late InMemoryInvitationRepository invitations;

  setUp(() {
    final crib = Crib(
      id: 'c1',
      name: 'Flat',
      currency: 'INR',
      members: [
        Member(id: 'me', name: 'Me', isAdmin: true),
        Member(id: 'a', name: 'Asha'),
      ],
      categories: const ['other'],
    );
    store = InMemoryStore(
      cribs: [crib],
      expenses: [],
      settlements: [],
      activity: [],
      currentUser: const AuthUser(id: 'me', name: 'Me', email: 'me@test.com'),
    );
    cribs = InMemoryCribRepository(store);
    expenses = InMemoryExpenseRepository(store);
    settlements = InMemorySettlementRepository(store);
    activity = InMemoryActivityRepository(store);
    invitations = InMemoryInvitationRepository(store);
  });

  Expense expense({String id = 'e1', int amount = 1000}) => Expense(
    id: id,
    cribId: 'c1',
    description: 'Dinner',
    totalMinor: amount,
    currency: 'INR',
    payerId: 'me',
    shares: {'me': amount ~/ 2, 'a': amount - amount ~/ 2},
    date: DateTime(2026),
    category: 'other',
  );

  test('crib repository supports create, read, update and delete', () async {
    final created = Crib(
      id: 'c2',
      name: 'Trip',
      currency: 'INR',
      members: [],
      categories: const [],
    );
    await cribs.create(created);
    expect((await cribs.getById('c2')).name, 'Trip');
    // The creator is stored as the owner, so the update carries the members
    // that were read back.
    final stored = await cribs.getById('c2');
    await cribs.update(stored.copyWith(name: 'Goa'));
    expect((await cribs.getById('c2')).name, 'Goa');
    await cribs.delete('c2');
    expect(() => cribs.getById('c2'), throwsA(isA<RepositoryException>()));
  });

  test(
    'expense repository validates, detects duplicates and missing records',
    () async {
      await expenses.create(expense());
      expect((await expenses.list(cribId: 'c1')).single.id, 'e1');
      await expectLater(
        expenses.create(expense()),
        throwsA(
          isA<RepositoryException>().having(
            (e) => e.code,
            'code',
            RepositoryErrorCode.conflict,
          ),
        ),
      );
      await expectLater(
        expenses.getById('missing'),
        throwsA(
          isA<RepositoryException>().having(
            (e) => e.code,
            'code',
            RepositoryErrorCode.notFound,
          ),
        ),
      );
      await expectLater(
        expenses.create(expense(id: 'invalid', amount: 0)),
        throwsA(
          isA<RepositoryException>().having(
            (e) => e.code,
            'code',
            RepositoryErrorCode.validation,
          ),
        ),
      );
      await expenses.update(expense(amount: 1200));
      expect((await expenses.getById('e1')).totalMinor, 1200);
      await expenses.delete('e1');
      expect(await expenses.list(cribId: 'c1'), isEmpty);
    },
  );

  test(
    'settlements are separate from spending and update ledger balances',
    () async {
      await expenses.create(expense());
      store.currentUser = const AuthUser(
        id: 'a',
        name: 'Asha',
        email: 'a@test.com',
      );
      // The sender asks for a settlement, the recipient confirms it.
      await settlements.create(
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
      store.currentUser = const AuthUser(
        id: 'me',
        name: 'Me',
        email: 'me@test.com',
      );
      await settlements.updateStatus('s1', SettlementStatus.confirmed);
      expect((await expenses.list(cribId: 'c1')).single.totalMinor, 1000);
      final balance = FinancialLedger.balances(
        crib: (await cribs.getById('c1')),
        expenses: await expenses.list(cribId: 'c1'),
        settlements: await settlements.list(cribId: 'c1'),
      );
      expect(balance, {'me': 300, 'a': -300});
    },
  );

  test('repositories reject writes without an authenticated user', () async {
    store.currentUser = null;
    await expectLater(
      expenses.create(expense()),
      throwsA(
        isA<RepositoryException>().having(
          (e) => e.code,
          'code',
          RepositoryErrorCode.unauthorized,
        ),
      ),
    );
  });

  test(
    'activity and invitations support prototype contract operations',
    () async {
      await activity.record(
        ActivityEvent(
          title: 'Added dinner',
          subtitle: '₹10',
          time: 'now',
          cribName: 'Flat',
          cribId: 'c1',
        ),
      );
      expect(
        (await activity.list(cribName: 'Flat')).single.title,
        'Added dinner',
      );
      final invitation = await invitations.create(
        cribId: 'c1',
        createdById: 'me',
        expiresAt: DateTime.now().add(const Duration(days: 1)),
      );
      await invitations.revoke(invitation.id);
      expect((await invitations.getById(invitation.id)).revoked, isTrue);
    },
  );

  test('expense and settlement DTOs preserve contract fields', () {
    expect(
      ExpenseDto.fromJson(ExpenseDto(expense()).toJson()).shares,
      expense().shares,
    );
    final value = Settlement(
      id: 's2',
      cribId: 'c1',
      currency: 'INR',
      fromMemberId: 'a',
      toMemberId: 'me',
      amountMinor: 10,
      status: SettlementStatus.pending,
      createdAt: DateTime.utc(2026),
    );
    expect(
      SettlementDto.fromJson(SettlementDto(value).toJson()).status,
      SettlementStatus.pending,
    );
  });
}
