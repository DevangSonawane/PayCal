import 'package:flutter_test/flutter_test.dart';
import 'package:paycal/data/models.dart';
import 'package:paycal/data/repositories.dart';
import 'package:paycal/domain/recurring_scheduler.dart';

import 'support/harness.dart';

void main() {
  RecurringPayment monthlySchedule({
    String id = 'r1',
    DateTime? startDate,
    String timeZone = 'UTC',
    int localHour = 9,
  }) => RecurringPayment(
    id: id,
    cribId: 'c1',
    description: 'Pocket money',
    amountMinor: 50000,
    currency: 'INR',
    category: 'other',
    frequency: RecurringFrequency.monthly,
    recipientId: 'a',
    createdById: 'me',
    startDate: startDate ?? DateTime(2026, 1, 31, localHour),
    timeZone: timeZone,
    localHour: localHour,
  );

  group('recurrence rules', () {
    test('a monthly schedule falls back to the last day of short months', () {
      final next = RecurringScheduler.nextDueDate(
        current: DateTime(2026, 1, 31),
        frequency: RecurringFrequency.monthly,
        anchorDay: 31,
      );

      expect(next, DateTime(2026, 2, 28));
    });

    test('a monthly schedule returns to its anchor day afterwards', () {
      final february = RecurringScheduler.nextDueDate(
        current: DateTime(2026, 1, 31),
        frequency: RecurringFrequency.monthly,
        anchorDay: 31,
      );
      final march = RecurringScheduler.nextDueDate(
        current: february,
        frequency: RecurringFrequency.monthly,
        anchorDay: 31,
      );

      expect(march, DateTime(2026, 3, 31));
    });

    test('a leap day yearly schedule lands on the 28th in a common year', () {
      final next = RecurringScheduler.nextDueDate(
        current: DateTime(2028, 2, 29),
        frequency: RecurringFrequency.yearly,
        anchorDay: 29,
      );

      expect(next, DateTime(2029, 2, 28));
    });

    test('the scheduled local time is kept', () {
      final next = RecurringScheduler.nextDueDate(
        current: DateTime(2026, 1, 31, 9, 30),
        frequency: RecurringFrequency.monthly,
        anchorDay: 31,
      );

      expect(next.hour, 9);
      expect(next.minute, 30);
    });

    test('the occurrence key is the schedule id plus the due date', () {
      final key = RecurringScheduler.occurrenceKey(
        scheduleId: 'r1',
        dueDate: DateTime(2026, 1, 31),
      );

      expect(key, 'r1|2026-01-31');
    });
  });

  group('timezones', () {
    test('a local time is converted with the offset of its zone', () {
      final instant = RecurringScheduler.instantFor(
        localDate: DateTime(2026, 1, 31),
        timeZone: 'Asia/Kolkata',
        hour: 9,
        minute: 0,
      );

      expect(instant, DateTime.utc(2026, 1, 31, 3, 30));
    });

    test('a daylight saving change keeps the local time', () {
      final winter = RecurringScheduler.instantFor(
        localDate: DateTime(2026, 1, 15),
        timeZone: 'America/New_York',
        hour: 9,
        minute: 0,
      );
      final summer = RecurringScheduler.instantFor(
        localDate: DateTime(2026, 7, 15),
        timeZone: 'America/New_York',
        hour: 9,
        minute: 0,
      );

      expect(winter, DateTime.utc(2026, 1, 15, 14));
      expect(summer, DateTime.utc(2026, 7, 15, 13));
      expect(winter.hour, winter.toUtc().hour);
    });

    test('a fixed offset zone is understood', () {
      final instant = RecurringScheduler.instantFor(
        localDate: DateTime(2026, 1, 31),
        timeZone: 'UTC+05:30',
        hour: 9,
        minute: 0,
      );

      expect(instant, DateTime.utc(2026, 1, 31, 3, 30));
      expect(RecurringScheduler.isKnownTimeZone('UTC+05:30'), isTrue);
    });

    test('an unknown zone is rejected', () {
      expect(RecurringScheduler.isKnownTimeZone('Mars/Olympus'), isFalse);
    });

    test('a schedule with an unknown zone is rejected', () async {
      final world = TestHarness();

      await expectLater(
        world.repositories.recurring.create(
          monthlySchedule(timeZone: 'Mars/Olympus'),
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

  group('occurrence generation', () {
    test('a due occurrence becomes one expense', () async {
      final world = TestHarness();
      await world.repositories.recurring.create(
        monthlySchedule(startDate: DateTime(2026, 1, 31, 9)),
      );

      final generated = await world.repositories.recurring.generateDue(
        cribId: 'c1',
        now: DateTime.utc(2026, 2, 5),
      );

      expect(generated, hasLength(1));
      expect(generated.single.totalMinor, 50000);
      expect(generated.single.payerId, 'me');
      expect(world.store.expenses, hasLength(1));
      expect(world.store.occurrences, hasLength(1));
      expect(
        world.store.occurrences.single.idempotencyKey,
        'r1|2026-01-31',
      );
    });

    test('running the generation twice does not create a second expense', () async {
      final world = TestHarness();
      await world.repositories.recurring.create(
        monthlySchedule(startDate: DateTime(2026, 1, 31, 9)),
      );

      await world.repositories.recurring.generateDue(
        cribId: 'c1',
        now: DateTime.utc(2026, 2, 5),
      );
      final second = await world.repositories.recurring.generateDue(
        cribId: 'c1',
        now: DateTime.utc(2026, 2, 5),
      );

      expect(second, isEmpty);
      expect(world.store.expenses, hasLength(1));
      expect(world.store.occurrences, hasLength(1));
    });

    test('missed occurrences are caught up once', () async {
      final world = TestHarness();
      await world.repositories.recurring.create(
        monthlySchedule(startDate: DateTime(2026, 1, 31, 9)),
      );

      final generated = await world.repositories.recurring.generateDue(
        cribId: 'c1',
        now: DateTime.utc(2026, 4, 5),
      );

      expect(generated, hasLength(3));
      expect(
        world.store.occurrences.map((item) => item.idempotencyKey),
        containsAll(['r1|2026-01-31', 'r1|2026-02-28', 'r1|2026-03-31']),
      );
      expect(world.store.expenses, hasLength(3));
    });

    test('an occurrence that is not due yet is not generated', () async {
      final world = TestHarness();
      await world.repositories.recurring.create(
        monthlySchedule(startDate: DateTime(2026, 1, 31, 9)),
      );

      final generated = await world.repositories.recurring.generateDue(
        cribId: 'c1',
        now: DateTime.utc(2026, 1, 20),
      );

      expect(generated, isEmpty);
    });

    test('cancelling a schedule stops the future occurrences', () async {
      final world = TestHarness();
      await world.repositories.recurring.create(
        monthlySchedule(startDate: DateTime(2026, 1, 31, 9)),
      );
      await world.repositories.recurring.cancel('r1');

      final generated = await world.repositories.recurring.generateDue(
        cribId: 'c1',
        now: DateTime.utc(2026, 4, 5),
      );

      expect(generated, isEmpty);
      expect(world.store.schedules.single.active, isFalse);
      expect(
        world.store.activity.map((event) => event.action),
        contains('recurring_cancelled'),
      );
    });

    test('only the owner can set up a recurring transfer', () async {
      final world = TestHarness();
      world.store.currentUser = testUser('a');

      await expectLater(
        world.repositories.recurring.create(monthlySchedule()),
        throwsA(
          isA<RepositoryException>().having(
            (error) => error.code,
            'code',
            RepositoryErrorCode.unauthorized,
          ),
        ),
      );
    });

    test('a member outside the crib cannot trigger a catch-up', () async {
      final world = TestHarness();
      await world.repositories.recurring.create(
        monthlySchedule(startDate: DateTime(2026, 1, 31, 9)),
      );
      world.store.currentUser = testUser('stranger');

      await expectLater(
        world.repositories.recurring.generateDue(
          cribId: 'c1',
          now: DateTime.utc(2026, 2, 5),
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
}
