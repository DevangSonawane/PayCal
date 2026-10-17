class Member {
  Member({required this.id, required this.name, this.isAdmin = false});
  final String id;
  final String name;
  final bool isAdmin;
  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final w = parts.first.toUpperCase();
      return w.length >= 2 ? w.substring(0, 2) : w;
    }
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }
}

class Expense {
  Expense({
    required this.id,
    required this.batchId,
    required this.description,
    required this.totalMinor,
    required this.currency,
    required this.payerId,
    required this.shares,
    required this.date,
    required this.category,
    this.disputed = false,
    this.unpaid = false,
  });
  final String id;
  final String batchId;
  final String description;
  final int totalMinor;
  final String currency;
  final String payerId;
  final Map<String, int> shares;
  final DateTime date;
  final String category;
  final bool disputed;
  final bool unpaid;
}

class Batch {
  Batch({required this.id, required this.name, required this.currency, required this.members, required this.categories});
  final String id;
  final String name;
  final String currency;
  final List<Member> members;
  final List<String> categories;
}

class ActivityEvent {
  ActivityEvent({required this.title, required this.subtitle, required this.time, required this.batchName});
  final String title;
  final String subtitle;
  final String time;
  final String batchName;
}
