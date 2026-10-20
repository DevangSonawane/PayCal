import 'package:flutter_test/flutter_test.dart';
import 'package:paycal/data/models.dart';
import 'package:paycal/data/repositories.dart';

import 'support/harness.dart';

/// Every read of a repository is scoped to the signed-in member.
///
/// The in-memory implementation simulates the boundary the database has to
/// enforce later: these tests prove the client never asks for another
/// member's data and never receives it. They do NOT replace the RLS policies
/// of a real database, because a modified client can skip these checks
/// entirely.
void main() {
  late TestHarness world;

  setUp(() {
    world = TestHarness(
      cribs: [testCrib(), foreignCrib()],
      expenses: [
        Expense(
          id: 'mine',
          cribId: 'c1',
          description: 'Our dinner',
          totalMinor: 1000,
          currency: 'INR',
          payerId: 'me',
          shares: {'me': 500, 'a': 500},
          date: DateTime(2026),
          category: 'other',
        ),
        Expense(
          id: 'theirs',
          cribId: 'c2',
          description: 'Their dinner',
          totalMinor: 4000,
          currency: 'INR',
          payerId: 'stranger',
          shares: {'stranger': 2000, 'other': 2000},
          date: DateTime(2026),
          category: 'other',
        ),
      ],
      settlements: [
        Settlement(
          id: 'mine-s',
          cribId: 'c1',
          currency: 'INR',
          fromMemberId: 'a',
          toMemberId: 'me',
          amountMinor: 200,
          status: SettlementStatus.confirmed,
          createdAt: DateTime(2026),
        ),
        Settlement(
          id: 'theirs-s',
          cribId: 'c2',
          currency: 'INR',
          fromMemberId: 'other',
          toMemberId: 'stranger',
          amountMinor: 900,
          status: SettlementStatus.confirmed,
          createdAt: DateTime(2026),
        ),
      ],
      activity: [
        ActivityEvent(
          title: 'our event',
          subtitle: 'Flat',
          time: 'now',
          cribName: 'Flat',
          cribId: 'c1',
        ),
        ActivityEvent(
          title: 'their event',
          subtitle: 'Neighbour',
          time: 'now',
          cribName: 'Neighbour',
          cribId: 'c2',
        ),
      ],
    );
    world.signIn('me');
  });

  group('cribs', () {
    test('a member only sees the cribs they belong to', () async {
      final cribs = await world.repositories.cribs.list();

      expect(cribs.map((crib) => crib.id), ['c1']);
    });

    test('a member cannot open a crib of somebody else', () async {
      await expectLater(
        world.repositories.cribs.getById('c2'),
        throwsA(
          isA<RepositoryException>().having(
            (error) => error.code,
            'code',
            RepositoryErrorCode.notFound,
          ),
        ),
      );
    });

    test('the cache only holds the cribs of the signed-in member', () {
      expect(world.repositories.cribs.cachedCribs.map((crib) => crib.id), ['c1']);
    });
  });

  group('expenses', () {
    test('a member only sees the expenses of their own cribs', () async {
      expect(
        world.repositories.expenses.cachedExpenses.map((expense) => expense.id),
        ['mine'],
      );
    });

    test('a member cannot read the expenses of another crib', () async {
      await expectLater(
        world.repositories.expenses.getById('theirs'),
        throwsA(
          isA<RepositoryException>().having(
            (error) => error.code,
            'code',
            RepositoryErrorCode.notFound,
          ),
        ),
      );
    });

    test('a member cannot list the expenses of another crib', () async {
      await expectLater(
        world.repositories.expenses.list(cribId: 'c2'),
        throwsA(
          isA<RepositoryException>().having(
            (error) => error.code,
            'code',
            RepositoryErrorCode.notFound,
          ),
        ),
      );
    });

    test('a member only sees the expenses of their own crib', () async {
      final expenses = await world.repositories.expenses.list(cribId: 'c1');

      expect(expenses.map((expense) => expense.id), ['mine']);
    });
  });

  group('settlements', () {
    test('a member only sees the settlements of their own cribs', () {
      expect(
        world.repositories.settlements.cachedSettlements.map(
          (settlement) => settlement.id,
        ),
        ['mine-s'],
      );
    });

    test('a member cannot list the settlements of another crib', () async {
      await expectLater(
        world.repositories.settlements.list(cribId: 'c2'),
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

  group('activity', () {
    test('a member only sees the activity of their own cribs', () async {
      final events = await world.repositories.activity.list();

      expect(events.map((event) => event.title), ['our event']);
    });

    test('the cache only holds the activity of the member own cribs', () {
      expect(
        world.repositories.activity.cachedEvents.map((event) => event.title),
        ['our event'],
      );
    });

    test('a member cannot record activity for a crib of somebody else',
        () async {
      await expectLater(
        world.repositories.activity.record(
          ActivityEvent(
            title: 'their event',
            subtitle: 'Neighbour',
            time: 'now',
            cribName: 'Neighbour',
            cribId: 'c2',
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
  });

  group('two members in the same store', () {
    test('every member sees a different set of data', () async {
      world.signIn('stranger');

      expect(
        (await world.repositories.cribs.list()).map((crib) => crib.id),
        ['c2'],
      );
      expect(
        world.repositories.expenses.cachedExpenses.map((expense) => expense.id),
        ['theirs'],
      );
      expect(
        world.repositories.settlements.cachedSettlements.map(
          (settlement) => settlement.id,
        ),
        ['theirs-s'],
      );
      expect(
        world.repositories.activity.cachedEvents.map((event) => event.title),
        ['their event'],
      );

      world.signIn('me');

      expect(
        (await world.repositories.cribs.list()).map((crib) => crib.id),
        ['c1'],
      );
      expect(
        world.repositories.expenses.cachedExpenses.map((expense) => expense.id),
        ['mine'],
      );
    });
  });

  group('a signed-out member', () {
    test('a signed-out member sees nothing at all', () async {
      world.signOut();

      expect(world.repositories.cribs.cachedCribs, isEmpty);
      expect(world.repositories.expenses.cachedExpenses, isEmpty);
      expect(world.repositories.settlements.cachedSettlements, isEmpty);
      expect(world.repositories.activity.cachedEvents, isEmpty);
    });

    test('a signed-out member cannot list anything', () async {
      world.signOut();

      await expectLater(
        world.repositories.cribs.list(),
        throwsA(
          isA<RepositoryException>().having(
            (error) => error.code,
            'code',
            RepositoryErrorCode.unauthorized,
          ),
        ),
      );
      await expectLater(
        world.repositories.expenses.list(cribId: 'c1'),
        throwsA(
          isA<RepositoryException>().having(
            (error) => error.code,
            'code',
            RepositoryErrorCode.unauthorized,
          ),
        ),
      );
      await expectLater(
        world.repositories.settlements.list(cribId: 'c1'),
        throwsA(
          isA<RepositoryException>().having(
            (error) => error.code,
            'code',
            RepositoryErrorCode.unauthorized,
          ),
        ),
      );
      await expectLater(
        world.repositories.activity.list(),
        throwsA(
          isA<RepositoryException>().having(
            (error) => error.code,
            'code',
            RepositoryErrorCode.unauthorized,
          ),
        ),
      );
    });
  });

  group('a member that left', () {
    test('a removed member keeps read access to the history of the crib',
        () async {
      await world.repositories.cribs.removeMember(
        cribId: 'c1',
        memberId: 'a',
      );
      world.signIn('a');

      expect(
        (await world.repositories.cribs.list()).map((crib) => crib.id),
        ['c1'],
      );
      expect(
        world.repositories.expenses.cachedExpenses.map((expense) => expense.id),
        ['mine'],
      );
    });

    test('a removed member still cannot reach another crib', () async {
      await world.repositories.cribs.removeMember(
        cribId: 'c1',
        memberId: 'a',
      );
      world.signIn('a');

      await expectLater(
        world.repositories.cribs.getById('c2'),
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
