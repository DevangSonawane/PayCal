/// Pure-Dart balance / split engine. All screens read balances from here.
/// Money is integer minor units. No doubles for money.
class ExpenseInput {
  ExpenseInput({
    required this.totalMinor,
    required this.payerId,
    required this.shares,
  });
  final int totalMinor;
  final String payerId;
  final Map<String, int> shares;
}

class BalanceEngine {
  /// Equal split. Remainder minor units go to the payer (temporary default, TODO: PRD decision).
  static Map<String, int> equalSplit({
    required int totalMinor,
    required List<String> memberIds,
    required String payerId,
  }) {
    if (memberIds.isEmpty) return {};
    final per = totalMinor ~/ memberIds.length;
    var remainder = totalMinor - per * memberIds.length;
    final shares = <String, int>{for (final m in memberIds) m: per};
    shares[payerId] = (shares[payerId] ?? 0) + remainder;
    remainder = 0;
    return shares;
  }

  /// Net per member: positive = owed to them, negative = they owe.
  static Map<String, int> nets(
    List<ExpenseInput> expenses,
    List<String> memberIds,
  ) {
    final paid = <String, int>{for (final m in memberIds) m: 0};
    final share = <String, int>{for (final m in memberIds) m: 0};
    for (final e in expenses) {
      paid[e.payerId] = (paid[e.payerId] ?? 0) + e.totalMinor;
      for (final entry in e.shares.entries) {
        share[entry.key] = (share[entry.key] ?? 0) + entry.value;
      }
    }
    return {for (final m in memberIds) m: (paid[m] ?? 0) - (share[m] ?? 0)};
  }
}
