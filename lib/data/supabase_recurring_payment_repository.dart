import 'package:paycal/data/models.dart';
import 'package:paycal/data/repositories.dart';
import 'package:paycal/domain/recurring_scheduler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseRecurringPaymentRepository implements RecurringPaymentRepository {
  SupabaseRecurringPaymentRepository(this._client);
  final SupabaseClient _client;
  List<RecurringPayment> _schedules = const [];
  final List<RecurringOccurrence> _occurrences = const [];
  @override
  List<RecurringPayment> get cachedSchedules => List.unmodifiable(_schedules);
  @override
  List<RecurringOccurrence> get cachedOccurrences =>
      List.unmodifiable(_occurrences);

  @override
  Future<RecurringPayment> create(RecurringPayment value) async =>
      _save('create_recurring_schedule', value);

  @override
  Future<RecurringPayment> update(RecurringPayment value) async =>
      _save('update_recurring_schedule', value);

  Future<RecurringPayment> _save(String rpc, RecurringPayment value) async {
    final params = <String, dynamic>{
      'schedule_description': value.description,
      'schedule_amount_minor': value.amountMinor,
      'schedule_category': value.category,
      'schedule_frequency': value.frequency.name,
      'schedule_recipient_id': value.recipientId,
      'schedule_start_date': _date(value.startDate),
      'schedule_time_zone': value.timeZone,
      'schedule_local_hour': value.localHour,
      'schedule_local_minute': value.localMinute,
      'schedule_anchor_day': value.anchorDay,
    };
    if (rpc == 'create_recurring_schedule') {
      params.addAll({
        'target_crib_id': value.cribId,
        'schedule_currency': value.currency,
      });
    } else {
      params['target_schedule_id'] = value.id;
    }
    final row = await _client.rpc(rpc, params: params);
    final result = _map(row as Map<String, dynamic>);
    _replace(result);
    return result;
  }

  @override
  Future<void> cancel(String id) async {
    final row = await _client.rpc(
      'set_recurring_schedule_state',
      params: {'target_schedule_id': id, 'next_active': false},
    );
    _replace(_map(row as Map<String, dynamic>));
  }

  @override
  Future<RecurringPayment> assignPayer(String id, String payerId) async {
    final row = await _client.rpc(
      'set_recurring_schedule_state',
      params: {
        'target_schedule_id': id,
        'next_active': true,
        'next_payer_id': payerId,
      },
    );
    final result = _map(row as Map<String, dynamic>);
    _replace(result);
    return result;
  }

  @override
  Future<List<Expense>> generateDue({
    required String cribId,
    required DateTime now,
  }) async {
    final rows = await _client
        .from('recurring_schedules')
        .select()
        .eq('crib_id', cribId)
        .eq('active', true);
    _schedules = rows.map(_map).toList(growable: false);
    final generated = <Expense>[];
    for (final schedule in _schedules) {
      if (schedule.payerId == null) continue;
      var due = schedule.resumeFrom ?? schedule.startDate;
      while (!RecurringScheduler.instantFor(
        localDate: due,
        timeZone: schedule.timeZone,
        hour: schedule.localHour,
        minute: schedule.localMinute,
      ).isAfter(now)) {
        final row = await _client.rpc(
          'generate_recurring_occurrence',
          params: {
            'target_schedule_id': schedule.id,
            'target_due_date': _date(due),
          },
        );
        generated.add(_expense(row as Map<String, dynamic>));
        due = RecurringScheduler.nextDueDate(
          current: due,
          frequency: schedule.frequency,
          anchorDay: schedule.anchorDay,
        );
      }
    }
    return generated;
  }

  void _replace(RecurringPayment value) =>
      _schedules = [..._schedules.where((item) => item.id != value.id), value];
  String _date(DateTime value) => value.toIso8601String().substring(0, 10);
  RecurringPayment _map(Map<String, dynamic> row) => RecurringPayment(
    id: row['id'] as String,
    cribId: row['crib_id'] as String,
    description: row['description'] as String,
    amountMinor: (row['amount_minor'] as num).toInt(),
    currency: row['currency'] as String,
    category: row['category'] as String,
    frequency: RecurringFrequency.values.byName(row['frequency'] as String),
    recipientId: row['recipient_id'] as String,
    createdById: row['created_by'] as String,
    payerId: row['payer_id'] as String?,
    startDate: DateTime.parse(row['start_date'] as String),
    timeZone: row['time_zone'] as String,
    localHour: (row['local_hour'] as num).toInt(),
    localMinute: (row['local_minute'] as num).toInt(),
    anchorDay: (row['anchor_day'] as num).toInt(),
    active: row['active'] as bool,
    resumeFrom: row['resume_from'] == null
        ? null
        : DateTime.parse(row['resume_from'] as String),
  );
  Expense _expense(Map<String, dynamic> row) => Expense(
    id: row['id'] as String,
    cribId: row['crib_id'] as String,
    description: row['description'] as String,
    totalMinor: (row['total_minor'] as num).toInt(),
    currency: row['currency'] as String,
    payerId: row['payer_id'] as String,
    createdById: row['created_by'] as String?,
    shares: {row['payer_id'] as String: (row['total_minor'] as num).toInt()},
    date: DateTime.parse(row['occurred_on'] as String),
    category: row['category'] as String,
    version: (row['version'] as num).toInt(),
  );
}
