import 'package:paycal/data/models.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Thrown when a schedule carries a timezone the app cannot resolve.
class RecurrenceException implements Exception {
  const RecurrenceException(this.message);
  final String message;

  @override
  String toString() => 'RecurrenceException: $message';
}

/// Pure recurrence rules for recurring transfers.
///
/// Two rules matter for v1:
///
///  * A monthly schedule anchored on the 29th, 30th or 31st runs on the last
///    day of shorter months and returns to its anchor day afterwards.
///  * Every occurrence is identified by `schedule id + due date`, so a due
///    occurrence produces at most one expense.
///
/// This class only computes dates. It never writes anything, so a backend can
/// reuse the same rules when it moves generation to a server job.
class RecurringScheduler {
  RecurringScheduler._();

  static bool _databaseReady = false;

  static void _ensureDatabase() {
    if (_databaseReady) return;
    tzdata.initializeTimeZones();
    _databaseReady = true;
  }

  /// The next due date after [current], as a local wall-clock date in the
  /// schedule's own timezone.
  static DateTime nextDueDate({
    required DateTime current,
    required RecurringFrequency frequency,
    required int anchorDay,
  }) {
    final year =
        frequency == RecurringFrequency.monthly ? current.year : current.year + 1;
    final month =
        frequency == RecurringFrequency.monthly ? current.month + 1 : current.month;
    // DateTime normalises overflowing months, so December rolls into January.
    final normalized = DateTime(year, month, 1);
    final lastDay = DateTime(normalized.year, normalized.month + 1, 0).day;
    final day = anchorDay > lastDay ? lastDay : anchorDay;
    return DateTime(
      normalized.year,
      normalized.month,
      day,
      current.hour,
      current.minute,
    );
  }

  /// The first due date strictly after [now].
  ///
  /// The schedule is walked from its start date, so missed runs are still
  /// part of the series.
  static DateTime nextDueDateAfter({
    required RecurringPayment schedule,
    required DateTime now,
  }) {
    var due = schedule.startDate;
    var guard = 0;
    while (guard++ < 5000) {
      final instant = instantFor(
        localDate: due,
        timeZone: schedule.timeZone,
        hour: schedule.localHour,
        minute: schedule.localMinute,
      );
      if (instant.isAfter(now)) return due;
      due = nextDueDate(
        current: due,
        frequency: schedule.frequency,
        anchorDay: schedule.anchorDay,
      );
    }
    throw const RecurrenceException(
      'The recurrence rule could not be resolved within 5000 steps.',
    );
  }

  /// The UTC instant of a local wall-clock date in [timeZone].
  static DateTime instantFor({
    required DateTime localDate,
    required String timeZone,
    required int hour,
    required int minute,
  }) {
    final offset = _fixedOffset(timeZone);
    if (offset != null) {
      return DateTime.utc(
        localDate.year,
        localDate.month,
        localDate.day,
        hour,
        minute,
      ).subtract(offset);
    }
    final location = _location(timeZone);
    return tz.TZDateTime(
      location,
      localDate.year,
      localDate.month,
      localDate.day,
      hour,
      minute,
    ).toUtc();
  }

  /// The local wall-clock date of [instant] in [timeZone].
  static DateTime localDateFor({
    required DateTime instant,
    required String timeZone,
  }) {
    final offset = _fixedOffset(timeZone);
    if (offset != null) return instant.toUtc().add(offset);
    final location = _location(timeZone);
    final local = tz.TZDateTime.from(instant.toUtc(), location);
    return DateTime(local.year, local.month, local.day, local.hour, local.minute);
  }

  /// The stable idempotency key of one occurrence: schedule id plus due date.
  static String occurrenceKey({
    required String scheduleId,
    required DateTime dueDate,
  }) {
    final month = dueDate.month.toString().padLeft(2, '0');
    final day = dueDate.day.toString().padLeft(2, '0');
    return '$scheduleId|${dueDate.year}-$month-$day';
  }

  /// The deterministic id of the expense generated for one occurrence.
  static String occurrenceExpenseId({
    required String scheduleId,
    required DateTime dueDate,
  }) {
    final month = dueDate.month.toString().padLeft(2, '0');
    final day = dueDate.day.toString().padLeft(2, '0');
    return 'rec-$scheduleId-${dueDate.year}-$month-$day';
  }

  /// Whether [timeZone] can be resolved by this build.
  static bool isKnownTimeZone(String timeZone) {
    final trimmed = timeZone.trim();
    if (trimmed.isEmpty) return false;
    if (trimmed.toUpperCase() == 'UTC') return true;
    if (_fixedOffset(trimmed) != null) return true;
    try {
      _location(trimmed);
      return true;
    } on RecurrenceException {
      return false;
    }
  }

  /// The device's current offset rendered as a fixed-offset zone id.
  ///
  /// The platform does not expose an IANA zone id without an extra plugin, so
  /// a schedule created on the device records the offset it was created with.
  static String deviceTimeZone([DateTime? now]) {
    final offset = (now ?? DateTime.now()).timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final total = offset.inMinutes.abs();
    final hours = (total ~/ 60).toString().padLeft(2, '0');
    final minutes = (total % 60).toString().padLeft(2, '0');
    return 'UTC$sign$hours:$minutes';
  }

  static tz.Location _location(String timeZone) {
    _ensureDatabase();
    try {
      return tz.getLocation(timeZone);
    } on tz.LocationNotFoundException {
      throw RecurrenceException('Unknown timezone "$timeZone".');
    }
  }

  /// Parses a fixed offset zone such as `UTC+05:30`. Returns null when the
  /// value is not a fixed offset and has to be looked up in the tz database.
  static Duration? _fixedOffset(String timeZone) {
    final trimmed = timeZone.trim();
    if (trimmed.toUpperCase() == 'UTC') return Duration.zero;
    final match = RegExp(
      r'^UTC([+-])(\d{1,2}):(\d{2})$',
    ).firstMatch(trimmed.toUpperCase());
    if (match == null) return null;
    final sign = match.group(1) == '-' ? -1 : 1;
    final hours = int.parse(match.group(2)!);
    final minutes = int.parse(match.group(3)!);
    if (hours > 14 || minutes > 59) return null;
    return Duration(minutes: sign * (hours * 60 + minutes));
  }
}
