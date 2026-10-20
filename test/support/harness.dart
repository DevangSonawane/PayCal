import 'package:paycal/data/in_memory_repositories.dart';
import 'package:paycal/data/models.dart';

/// Shared helpers for the repository tests.
///
/// Every test builds its own store, so the prototype seed data is never
/// touched.
AuthUser testUser(String id, {String? name}) =>
    AuthUser(id: id, name: name ?? id, email: '$id@test.com');

Crib testCrib({
  String id = 'c1',
  String name = 'Flat',
  String currency = 'INR',
  String ownerId = 'me',
  List<Member>? members,
  List<String>? categories,
}) => Crib(
  id: id,
  name: name,
  currency: currency,
  ownerId: ownerId,
  members:
      members ??
      [
        Member(id: 'me', name: 'Me', role: MemberRole.owner),
        Member(id: 'a', name: 'Asha'),
        Member(id: 'r', name: 'Ravi'),
      ],
  categories: categories ?? const ['other'],
);

Expense testExpense({
  String id = 'e1',
  String cribId = 'c1',
  String payerId = 'me',
  int amount = 1000,
  String currency = 'INR',
  String? createdById,
}) => Expense(
  id: id,
  cribId: cribId,
  description: 'Dinner',
  totalMinor: amount,
  currency: currency,
  payerId: payerId,
  shares: {payerId: amount},
  date: DateTime(2026),
  category: 'other',
  createdById: createdById,
);

class TestHarness {
  TestHarness({
    List<Crib>? cribs,
    List<Expense>? expenses,
    List<Settlement>? settlements,
    List<ActivityEvent>? activity,
    AuthUser? currentUser,
    DateTime? now,
  }) : store = InMemoryStore(
         cribs: cribs ?? [testCrib()],
         expenses: expenses ?? [],
         settlements: settlements ?? [],
         activity: activity ?? [],
         currentUser: currentUser ?? testUser('me'),
       ) {
    if (now != null) store.clock = () => now;
  }

  final InMemoryStore store;
  late final PayCalRepositories repositories =
      PayCalRepositories.forStore(store);

  /// Switches the signed-in member, so a test can act as somebody else.
  void signIn(String id, {String? name}) {
    store.currentUser = testUser(id, name: name);
  }

  /// Signs nobody in.
  void signOut() {
    store.currentUser = null;
  }

  /// Pins the moment the repositories use, so a removal, an expiry or an
  /// activity timestamp is deterministic.
  set now(DateTime value) => store.clock = () => value;
  DateTime get now => store.now;
}

/// A crib that belongs to somebody else, used by the isolation tests.
Crib foreignCrib({
  String id = 'c2',
  String name = 'Neighbour',
  String ownerId = 'stranger',
}) => Crib(
  id: id,
  name: name,
  currency: 'INR',
  ownerId: ownerId,
  members: [
    Member(id: ownerId, name: 'Stranger', role: MemberRole.owner),
    Member(id: 'other', name: 'Other'),
  ],
  categories: const ['other'],
);
