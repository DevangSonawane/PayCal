import 'package:paycal/data/models.dart';
import 'package:paycal/data/repositories.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseActivityRepository implements ActivityRepository {
  SupabaseActivityRepository(this._client);
  final SupabaseClient _client;
  List<ActivityEvent> _cache = const [];

  @override
  List<ActivityEvent> get cachedEvents => List.unmodifiable(_cache);

  @override
  Future<List<ActivityEvent>> list({String? cribName}) async {
    final rows = await _client
        .from('activity_events')
        .select('*, cribs(name)')
        .order('occurred_at', ascending: false);
    _cache = rows
        .map((row) {
          final crib = row['cribs'] as Map<String, dynamic>?;
          final action = row['action'] as String;
          return ActivityEvent(
            title: action.replaceAll('_', ' '),
            subtitle: 'Recorded securely in Tabbb',
            time: '',
            cribName: crib?['name'] as String? ?? 'Crib',
            cribId: row['crib_id'] as String,
            actorId: row['actor_id'] as String?,
            targetId: row['target_id'] as String?,
            action: action,
            occurredAt: DateTime.parse(row['occurred_at'] as String),
          );
        })
        .where((event) => cribName == null || event.cribName == cribName)
        .toList(growable: false);
    return cachedEvents;
  }

  @override
  Future<void> record(ActivityEvent event) => throw const RepositoryException(
    RepositoryErrorCode.unauthorized,
    'Activity is recorded by secure server-side operations.',
  );
}
