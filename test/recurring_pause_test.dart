import 'package:flutter_test/flutter_test.dart';
import 'package:paycal/data/models.dart';
import 'package:paycal/data/repositories.dart';
import 'package:paycal/domain/recurring_scheduler.dart';

import 'support/harness.dart';

/// The "keep the default" marker of the recurring schedule model.
const _unsetMarker = Object();

/// Decision B: when the member who pays a recurring schedule leaves the
/// crib, the schedule is paused until an active member is assigned as the
/// new payer.
void main() {
  /// The moment the repositories use, so the pause point is deterministic.
  final pausedAt = DateTime.utc(2026, 6, 15, 12);

  RecurringPayment monthlySchedule({
    String id = 'r1',
    DateTime? startDate,
    String createdById = 'me',
    String recipientId = 'r',
    Object? payerId = _unsetMarker,
  }) => RecurringPayment(
    id: id,
    cribId: 'c1',
    description: 'Pocket money',
    amountMinor: 50000,
    currency: 'INR',
    category: 'other',
    frequency: RecurringFrequency.monthly,
    recipientId: recipientId,
    createdById: createdById,
    startDate: startDate ?? DateTime(2026, 1, 31, 9),
    timeZone: 'UTC',
    payerId: payerId,
  );

  group('a schedule is paid by one member at a time', () {
    test('the creator is the payer of a new schedule', () async {
      final world = TestHarness(now: pausedAt);

      final created = await world.repositories.recurring.create(
        monthlySchedule(),
      );

      expect(created.payerId, 'me');
      expect(created.isPaused, isFalse);
    });

    test('the payer of a new schedule has to be an active member', () async {
      final world = TestHarness(now: pausedAt);
      await world.repositories.cribs.removeMember(
        cribId: 'c1',
        memberId: 'r',
      );

      await expectLater(
        world.repositories.recurring.create(
          monthlySchedule(payerId: 'r'),
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

  group('the payer leaves the crib', () {
    test('the schedule is paused', () async {
      final world = TestHarness(now: pausedAt);
      await world.repositories.recurring.create(monthlySchedule());

      await world.repositories.recurring.assignPayer('r1', 'a');
      await world.repositories.cribs.removeMember(
        cribId: 'c1',
        memberId: 'a',
      );

      final schedule = world.store.schedules.single;
      expect(schedule.isPaused, isTrue);
      expect(schedule.payerId, isNull);
      expect(schedule.active, isTrue, reason: 'paused is not cancelled');
    });

    test('a paused schedule generates nothing', () async {
      final world = TestHarness(now: pausedAt);
      await world.repositories.recurring.create(
        monthlySchedule(startDate: DateTime(2026, 1, 31, 9)),
      );
      await world.repositories.recurring.assignPayer('r1', 'a');
      await world.repositories.cribs.removeMember(
        cribId: 'c1',
        memberId: 'a',
      );

      final generated = await world.repositories.recurring.generateDue(
        cribId: 'c1',
        now: DateTime.utc(2026, 8, 5),
      );

      expect(generated, isEmpty);
      expect(world.store.expenses, isEmpty);
      expect(world.store.occurrences, isEmpty);
    });

    test('the pause is recorded in the activity feed', () async {
      final world = TestHarness(now: pausedAt);
      await world.repositories.recurring.create(monthlySchedule());

      await world.repositories.recurring.assignPayer('r1', 'a');
      await world.repositories.cribs.removeMember(
        cribId: 'c1',
        memberId: 'a',
      );

      expect(
        world.store.activity.map((event) => event.action),
        containsAll(['member_removed', 'recurring_paused']),
      );
    });

    test('the generated expenses and occurrences stay intact', () async {
      final world = TestHarness(now: pausedAt);
      await world.repositories.recurring.create(
        monthlySchedule(startDate: DateTime(2026, 1, 31, 9)),
      );
      await world.repositories.recurring.generateDue(
        cribId: 'c1',
        now: DateTime.utc(2026, 2, 5),
      );
      expect(world.store.expenses, hasLength(1));

      await world.repositories.recurring.assignPayer('r1', 'a');
      await world.repositories.cribs.removeMember(
        cribId: 'c1',
        memberId: 'a',
      );

      expect(world.store.expenses, hasLength(1));
      expect(world.store.occurrences, hasLength(1));
      expect(world.store.expenses.single.payerId, 'me');
    });

    test('a schedule paid by somebody else is not paused', () async {
      final world = TestHarness(now: pausedAt);
      await world.repositories.recurring.create(monthlySchedule());

      // The schedule is paid by "a", so the removal of "r" does not touch it.
      await world.repositories.recurring.assignPayer('r1', 'a');
      await world.repositories.cribs.removeMember(
        cribId: 'c1',
        memberId: 'r',
      );

      expect(world.store.schedules.single.isPaused, isFalse);
      expect(world.store.schedules.single.payerId, 'a');
    });
  });

  group('assigning a new payer', () {
    test('the owner can assign an active member and the schedule resumes',
        () async {
      final world = TestHarness(now: pausedAt);
      await world.repositories.recurring.create(monthlySchedule());
      await world.repositories.recurring.assignPayer('r1', 'a');
      await world.repositories.cribs.removeMember(
        cribId: 'c1',
        memberId: 'a',
      );

      final assigned = await world.repositories.recurring.assignPayer(
        'r1',
        'r',
      );

      expect(assigned.payerId, 'r');
      expect(assigned.isPaused, isFalse);
    });

    test('a member cannot assign a payer', () async {
      final world = TestHarness(now: pausedAt);
      await world.repositories.recurring.create(monthlySchedule());
      await world.repositories.recurring.assignPayer('r1', 'a');
      await world.repositories.cribs.removeMember(
        cribId: 'c1',
        memberId: 'a',
      );
      world.signIn('r');

      await expectLater(
        world.repositories.recurring.assignPayer('r1', 'r'),
        throwsA(
          isA<RepositoryException>().having(
            (error) => error.code,
            'code',
            RepositoryErrorCode.unauthorized,
          ),
        ),
      );
    });

    test('only an active member can be assigned', () async {
      final world = TestHarness(now: pausedAt);
      await world.repositories.recurring.create(monthlySchedule());
      await world.repositories.recurring.assignPayer('r1', 'a');
      await world.repositories.cribs.removeMember(
        cribId: 'c1',
        memberId: 'a',
      );
      // "r" is removed as well, so it cannot be the payer any more.
      await world.repositories.cribs.removeMember(
        cribId: 'c1',
        memberId: 'r',
      );

      await expectLater(
        world.repositories.recurring.assignPayer('r1', 'r'),
        throwsA(
          isA<RepositoryException>().having(
            (error) => error.code,
            'code',
            RepositoryErrorCode.validation,
          ),
        ),
      );
    });

    test('a member outside the crib cannot be assigned', () async {
      final world = TestHarness(now: pausedAt);
      await world.repositories.recurring.create(monthlySchedule());
      await world.repositories.recurring.assignPayer('r1', 'a');
      await world.repositories.cribs.removeMember(
        cribId: 'c1',
        memberId: 'a',
      );

      await expectLater(
        world.repositories.recurring.assignPayer('r1', 'stranger'),
        throwsA(
          isA<RepositoryException>().having(
            (error) => error.code,
            'code',
            RepositoryErrorCode.validation,
          ),
        ),
      );
    });

    test('a schedule that already has a payer changes its payer', () async {
      final world = TestHarness(now: pausedAt);
      await world.repositories.recurring.create(monthlySchedule());

      final assigned = await world.repositories.recurring.assignPayer(
        'r1',
        'r',
      );

      expect(assigned.payerId, 'r');
      expect(assigned.isPaused, isFalse);
    });

    test('a cancelled schedule cannot be resumed', () async {
      final world = TestHarness(now: pausedAt);
      await world.repositories.recurring.create(monthlySchedule());
      await world.repositories.recurring.assignPayer('r1', 'a');
      await world.repositories.cribs.removeMember(
        cribId: 'c1',
        memberId: 'a',
      );
      await world.repositories.recurring.cancel('r1');

      await expectLater(
        world.repositories.recurring.assignPayer('r1', 'r'),
        throwsA(
          isA<RepositoryException>().having(
            (error) => error.code,
            'code',
            RepositoryErrorCode.conflict,
          ),
        ),
      );
    });

    test('the assignment is recorded in the activity feed', () async {
      final world = TestHarness(now: pausedAt);
      await world.repositories.recurring.create(monthlySchedule());
      await world.repositories.recurring.assignPayer('r1', 'a');
      await world.repositories.cribs.removeMember(
        cribId: 'c1',
        memberId: 'a',
      );

      await world.repositories.recurring.assignPayer('r1', 'r');

      expect(
        world.store.activity.map((event) => event.action),
        contains('recurring_payer_assigned'),
      );
    });
  });

  group('resuming', () {
    test('the schedule generates again and the new payer pays', () async {
      final world = TestHarness(now: pausedAt);
      await world.repositories.recurring.create(
        monthlySchedule(startDate: DateTime(2026, 1, 31, 9)),
      );
      await world.repositories.recurring.assignPayer('r1', 'a');
      await world.repositories.cribs.removeMember(
        cribId: 'c1',
        memberId: 'a',
      );
      await world.repositories.recurring.assignPayer('r1', 'r');

      final generated = await world.repositories.recurring.generateDue(
        cribId: 'c1',
        now: DateTime.utc(2026, 8, 5),
      );

      expect(generated, isNotEmpty);
      for (final expense in generated) {
        expect(expense.payerId, 'r');
        expect(expense.shares.keys, ['r']);
      }
    });

    test('resuming does not duplicate an occurrence that exists already',
        () async {
      final world = TestHarness(now: pausedAt);
      await world.repositories.recurring.create(
        monthlySchedule(startDate: DateTime(2026, 1, 31, 9)),
      );
      await world.repositories.recurring.generateDue(
        cribId: 'c1',
        now: DateTime.utc(2026, 2, 5),
      );
      expect(world.store.expenses, hasLength(1));

      await world.repositories.recurring.assignPayer('r1', 'a');
      await world.repositories.cribs.removeMember(
        cribId: 'c1',
        memberId: 'a',
      );
      await world.repositories.recurring.assignPayer('r1', 'r');
      await world.repositories.recurring.generateDue(
        cribId: 'c1',
        now: DateTime.utc(2026, 8, 5),
      );

      final keys = world.store.occurrences.map((item) => item.idempotencyKey);
      expect(keys.toSet().length, keys.length, reason: 'no duplicate key');
      expect(keys, contains('r1|2026-01-31'));
      expect(
        world.store.expenses
            .where((expense) => expense.id == 'rec-r1-2026-01-31')
            .length,
        1,
      );
    });

    test('a pause does not create a backlog of the missed occurrences',
        () async {
      final world = TestHarness(now: pausedAt);
      await world.repositories.recurring.create(
        monthlySchedule(startDate: DateTime(2026, 1, 31, 9)),
      );
      // Only the occurrences up to March are generated before the pause.
      await world.repositories.recurring.generateDue(
        cribId: 'c1',
        now: DateTime.utc(2026, 4, 5),
      );
      expect(world.store.expenses, hasLength(3));

      await world.repositories.recurring.assignPayer('r1', 'a');
      await world.repositories.cribs.removeMember(
        cribId: 'c1',
        memberId: 'a',
      );
      await world.repositories.recurring.assignPayer('r1', 'r');

      final generated = await world.repositories.recurring.generateDue(
        cribId: 'c1',
        now: DateTime.utc(2026, 8, 5),
      );

      // The pause happened on 15 June, so the schedule continues at the first
      // due date after it. The occurrences that were missed before the pause
      // are not generated afterwards, and the paused window is skipped.
      final keys = generated.map((expense) => expense.id).toList();
      expect(keys, isNot(contains('rec-r1-2026-04-30')));
      expect(keys, isNot(contains('rec-r1-2026-05-31')));
      expect(keys, contains('rec-r1-2026-06-30'));
      expect(keys, contains('rec-r1-2026-07-31'));
    });

    test('the schedule continues at the first due date after the pause',
        () async {
      final world = TestHarness(now: pausedAt);
      final schedule = monthlySchedule(startDate: DateTime(2026, 1, 31, 9));
      await world.repositories.recurring.create(schedule);

      await world.repositories.recurring.assignPayer('r1', 'a');
      await world.repositories.cribs.removeMember(
        cribId: 'c1',
        memberId: 'a',
      );

      final paused = world.store.schedules.single;
      expect(
        paused.resumeFrom,
        RecurringScheduler.nextDueDateAfter(schedule: schedule, now: pausedAt),
      );
    });
  });

  group('a payer that leaves later', () {
    test('the schedule is paused again', () async {
      final world = TestHarness(now: pausedAt);
      await world.repositories.recurring.create(monthlySchedule());
      await world.repositories.recurring.assignPayer('r1', 'a');
      await world.repositories.cribs.removeMember(
        cribId: 'c1',
        memberId: 'a',
      );
      await world.repositories.recurring.assignPayer('r1', 'r');

      await world.repositories.cribs.removeMember(
        cribId: 'c1',
        memberId: 'r',
      );

      expect(world.store.schedules.single.isPaused, isTrue);
      expect(world.store.schedules.single.payerId, isNull);
    });
  });
}
