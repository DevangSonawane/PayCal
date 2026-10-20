import 'models.dart';

/// Seed data for the prototype.
///
/// This class is a data source, not a place where the app writes. Money
/// entries, settlements and membership changes go through the repositories in
/// `data/repositories.dart`; only [memberName] is kept here as a read-only
/// display helper for prototype screens.
class MockData {
  static const meId = 'me';
  static final Member me = Member(
    id: meId,
    name: 'You',
    isAdmin: true,
  );

  static final cribs = <Crib>[
    Crib(
      id: 'c1',
      name: 'Our flat',
      currency: 'INR',
      ownerId: meId,
      members: [
        me,
        Member(id: 'a', name: 'Asha'),
        Member(id: 'r', name: 'Ravi'),
        Member(id: 'n', name: 'Neha'),
        Member(id: 'k', name: 'Kabir'),
      ],
      categories: ['rent', 'groceries', 'electricity', 'internet', 'other'],
    ),
    Crib(
      id: 'c2',
      name: 'Goa trip',
      currency: 'INR',
      ownerId: meId,
      members: [
        me,
        Member(id: 'n', name: 'Neha'),
        Member(id: 'k', name: 'Kabir'),
        Member(id: 'z', name: 'Zoya'),
      ],
      categories: ['stay', 'transport', 'food', 'activities', 'other'],
    ),
  ];

  static final expenses = <Expense>[
    Expense(
      id: 'e1',
      cribId: 'c1',
      description: 'Groceries',
      totalMinor: 125000,
      currency: 'INR',
      payerId: meId,
      shares: {meId: 25000, 'a': 25000, 'r': 25000, 'n': 25000, 'k': 25000},
      date: DateTime.now().subtract(const Duration(days: 1)),
      category: 'groceries',
      createdById: meId,
    ),
    Expense(
      id: 'e2',
      cribId: 'c1',
      description: 'Electricity',
      totalMinor: 90000,
      currency: 'INR',
      payerId: 'a',
      shares: {meId: 18000, 'a': 18000, 'r': 18000, 'n': 18000, 'k': 18000},
      date: DateTime.now().subtract(const Duration(days: 3)),
      category: 'electricity',
      unpaid: true,
      createdById: 'a',
    ),
    Expense(
      id: 'e3',
      cribId: 'c2',
      description: 'Beach shack',
      totalMinor: 240000,
      currency: 'INR',
      payerId: 'n',
      shares: {meId: 60000, 'n': 60000, 'k': 60000, 'z': 60000},
      date: DateTime.now().subtract(const Duration(days: 5)),
      category: 'food',
      disputed: true,
      createdById: 'n',
    ),
    Expense(
      id: 'e4',
      cribId: 'c1',
      description: 'Internet bill',
      totalMinor: 149900,
      currency: 'INR',
      payerId: 'r',
      shares: {meId: 29980, 'a': 29980, 'r': 29980, 'n': 29980, 'k': 29980},
      date: DateTime.now().subtract(const Duration(days: 2)),
      category: 'internet',
      createdById: 'r',
    ),
    Expense(
      id: 'e5',
      cribId: 'c1',
      description: 'Water cans',
      totalMinor: 60000,
      currency: 'INR',
      payerId: 'n',
      shares: {meId: 12000, 'a': 12000, 'r': 12000, 'n': 12000, 'k': 12000},
      date: DateTime.now(),
      category: 'other',
      createdById: 'n',
    ),
  ];

  static final recurringPayments = <RecurringPayment>[];

  /// Kept separate from expenses so settling never changes tracked spending.
  static final settlements = <Settlement>[];

  static final activity = <ActivityEvent>[
    ActivityEvent(
      title: 'Asha added Electricity',
      subtitle: '₹900.00 · Our flat',
      time: '2h',
      cribName: 'Our flat',
    ),
    ActivityEvent(
      title: 'You added Groceries',
      subtitle: '₹1,250.00 · Our flat',
      time: '1d',
      cribName: 'Our flat',
    ),
    ActivityEvent(
      title: 'Neha flagged Beach shack',
      subtitle: '₹2,400.00 · Goa trip',
      time: '5d',
      cribName: 'Goa trip',
    ),
  ];

  /// Read-only lookup used by prototype screens to show a member name.
  static String memberName(String id) {
    for (final b in cribs) {
      for (final m in b.members) {
        if (m.id == id) return m.name;
      }
    }
    return 'Someone';
  }
}
