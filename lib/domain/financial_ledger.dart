import 'package:paycal/core/utils/money.dart';
import 'package:paycal/data/models.dart';

/// Thrown before a financial record enters the ledger. Repositories can map
/// this deterministic domain failure to their own validation error later.
class FinancialValidationException implements Exception {
  FinancialValidationException(this.message);
  final String message;

  @override
  String toString() => 'FinancialValidationException: $message';
}

/// Pure-Dart source of truth for PayCal's financial rules.
///
/// All values are integer minor units. A crib has exactly one currency and a
/// settlement affects balances only when confirmed or self-managed.
class FinancialLedger {
  static const int percentBasisPoints = 10000;

  static Map<String, int> equalSplit({
    required int totalMinor,
    required Iterable<String> participantIds,
    required String payerId,
  }) {
    final participants = _uniqueIds(participantIds, 'participants');
    _positiveAmount(totalMinor);
    final each = totalMinor ~/ participants.length;
    var remainder = totalMinor % participants.length;
    // Deterministic rule: payer receives the first remainder unit; the rest
    // follow the supplied participant order. This keeps every split exact.
    final ordered = participants.contains(payerId)
        ? [payerId, ...participants.where((id) => id != payerId)]
        : participants;
    return Map.unmodifiable({
      for (final id in ordered) id: each + (remainder-- > 0 ? 1 : 0),
    });
  }

  /// Converts exact percentage shares expressed in basis points (100% = 10000)
  /// into minor units. The same deterministic remainder rule as [equalSplit]
  /// is used after flooring each allocation.
  static Map<String, int> percentageSplit({
    required int totalMinor,
    required Map<String, int> basisPoints,
    required String payerId,
  }) {
    _positiveAmount(totalMinor);
    final participants = _uniqueIds(
      basisPoints.keys,
      'percentage participants',
    );
    final sum = basisPoints.values.fold<int>(
      0,
      (total, value) => total + value,
    );
    if (basisPoints.values.any((value) => value < 0) ||
        sum != percentBasisPoints) {
      throw FinancialValidationException(
        'Percentage shares must be non-negative and total exactly 100%.',
      );
    }
    final shares = <String, int>{
      for (final id in participants)
        id: totalMinor * basisPoints[id]! ~/ percentBasisPoints,
    };
    var remainder = totalMinor - shares.values.fold<int>(0, (a, b) => a + b);
    final ordered = participants.contains(payerId)
        ? [payerId, ...participants.where((id) => id != payerId)]
        : participants;
    for (final id in ordered) {
      if (remainder == 0) break;
      shares[id] = shares[id]! + 1;
      remainder--;
    }
    return Map.unmodifiable(shares);
  }

  /// Validates the structure of an expense.
  ///
  /// Membership is checked against every member of the crib, including
  /// members that left later, so the history of a crib keeps validating.
  /// Use [validateNewExpense] for an expense that is about to be recorded.
  static void validateExpense({
    required Crib crib,
    required Expense expense,
  }) {
    if (expense.cribId != crib.id) {
      throw FinancialValidationException(
        'The expense belongs to another crib.',
      );
    }
    if (expense.currency != crib.currency) {
      throw FinancialValidationException(
        'An expense must use its crib currency.',
      );
    }
    _positiveAmount(expense.totalMinor);
    final members = crib.members.map((member) => member.id).toSet();
    if (!members.contains(expense.payerId)) {
      throw FinancialValidationException('The payer must be a crib member.');
    }
    if (expense.shares.isEmpty) {
      throw FinancialValidationException(
        'An expense needs at least one participant.',
      );
    }
    for (final entry in expense.shares.entries) {
      if (!members.contains(entry.key)) {
        throw FinancialValidationException(
          'Every participant must be a crib member.',
        );
      }
      if (entry.value < 0) {
        throw FinancialValidationException('A share cannot be negative.');
      }
    }
    final sharesTotal = expense.shares.values.fold<int>(
      0,
      (sum, value) => sum + value,
    );
    if (sharesTotal != expense.totalMinor) {
      throw FinancialValidationException(
        'Shares must add up exactly to the expense total.',
      );
    }
  }

  /// Validates an expense that is about to be recorded.
  ///
  /// On top of [validateExpense] the payer and every participant have to be
  /// an active member, so a member that left is never charged again. The
  /// expenses they already took part in keep validating, so the history of a
  /// crib stays complete.
  static void validateNewExpense({
    required Crib crib,
    required Expense expense,
  }) {
    validateExpense(crib: crib, expense: expense);
    final active = crib.activeMembers.map((member) => member.id).toSet();
    if (!active.contains(expense.payerId)) {
      throw FinancialValidationException(
        'The payer must be an active crib member.',
      );
    }
    for (final id in expense.shares.keys) {
      if (!active.contains(id)) {
        throw FinancialValidationException(
          'Every participant must be an active crib member.',
        );
      }
    }
  }

  /// Validates the structure of a settlement.
  ///
  /// Membership is checked against every member of the crib, including
  /// members that left later, so a settlement that was confirmed while they
  /// were still a member keeps validating. Use [validateNewSettlement] for a
  /// settlement that is about to be recorded.
  static void validateSettlement({
    required Crib crib,
    required Settlement settlement,
  }) {
    if (settlement.cribId != crib.id ||
        settlement.currency != crib.currency) {
      throw FinancialValidationException(
        'A settlement must belong to its crib and currency.',
      );
    }
    _positiveAmount(settlement.amountMinor);
    final members = crib.members.map((member) => member.id).toSet();
    if (!members.contains(settlement.fromMemberId) ||
        !members.contains(settlement.toMemberId)) {
      throw FinancialValidationException(
        'Settlement members must belong to the crib.',
      );
    }
    if (settlement.fromMemberId == settlement.toMemberId) {
      throw FinancialValidationException(
        'A member cannot settle with themselves.',
      );
    }
  }

  /// Validates a settlement that is about to be recorded.
  ///
  /// Both members have to be active members of the crib. A removed member
  /// cannot take part in a new financial operation.
  static void validateNewSettlement({
    required Crib crib,
    required Settlement settlement,
  }) {
    validateSettlement(crib: crib, settlement: settlement);
    final active = crib.activeMembers.map((member) => member.id).toSet();
    if (!active.contains(settlement.fromMemberId) ||
        !active.contains(settlement.toMemberId)) {
      throw FinancialValidationException(
        'Settlement members must be active crib members.',
      );
    }
  }

  /// Whether two share allocations are the same.
  ///
  /// The maps are compared by content. Comparing them with `==` would
  /// compare the identity of the map objects, and every expense carries its
  /// own unmodifiable copy of the shares, so that would report every expense
  /// as changed.
  static bool sameShares(Map<String, int> a, Map<String, int> b) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (!b.containsKey(entry.key)) return false;
      if (b[entry.key] != entry.value) return false;
    }
    return true;
  }

  /// The outstanding debt from [fromId] to [toId].
  ///
  /// A member owes a specific person the part of that person's money they
  /// consumed: their share in the expenses the other member paid. Settlements
  /// that already happened reduce that debt, and only settlements that count
  /// towards the balance do.
  ///
  /// This is deliberately different from the net balance in [balances]. The
  /// net balance says how much a member is owed by the crib as a whole, the
  /// pairwise debt says who owes whom. A settlement is validated against the
  /// pairwise debt, so a member can never pay off a debt to somebody they do
  /// not owe, and never pays more than they owe to that person.
  static int pairwiseDebt({
    required Crib crib,
    required Iterable<Expense> expenses,
    Iterable<Settlement> settlements = const [],
    required String fromId,
    required String toId,
  }) {
    if (fromId == toId) return 0;
    var debt = 0;
    for (final expense in expenses) {
      if (expense.cribId != crib.id) continue;
      if (expense.payerId != toId) continue;
      debt += expense.shares[fromId] ?? 0;
    }
    for (final settlement in settlements) {
      if (settlement.cribId != crib.id) continue;
      if (settlement.status != SettlementStatus.confirmed &&
          settlement.status != SettlementStatus.selfManaged) {
        continue;
      }
      if (settlement.fromMemberId != fromId) continue;
      if (settlement.toMemberId != toId) continue;
      debt -= settlement.amountMinor;
    }
    return debt > 0 ? debt : 0;
  }

  /// Every outstanding pairwise debt of a crib, keyed by the member who owes
  /// the money and then by the member they owe it to.
  static Map<String, Map<String, int>> pairwiseDebts({
    required Crib crib,
    required Iterable<Expense> expenses,
    Iterable<Settlement> settlements = const [],
  }) {
    final debts = <String, Map<String, int>>{};
    void add(String from, String to, int amount) {
      if (from == to || amount == 0) return;
      final row = debts.putIfAbsent(from, () => <String, int>{});
      row[to] = (row[to] ?? 0) + amount;
    }
    for (final expense in expenses) {
      if (expense.cribId != crib.id) continue;
      for (final entry in expense.shares.entries) {
        add(entry.key, expense.payerId, entry.value);
      }
    }
    for (final settlement in settlements) {
      if (settlement.cribId != crib.id) continue;
      if (settlement.status != SettlementStatus.confirmed &&
          settlement.status != SettlementStatus.selfManaged) {
        continue;
      }
      add(
        settlement.fromMemberId,
        settlement.toMemberId,
        -settlement.amountMinor,
      );
    }
    for (final from in debts.keys.toList()) {
      final row = debts[from]!;
      row.removeWhere((_, amount) => amount <= 0);
      if (row.isEmpty) debts.remove(from);
    }
    return debts;
  }

  /// Positive means the member is owed; negative means they owe.
  static Map<String, int> balances({
    required Crib crib,
    required Iterable<Expense> expenses,
    Iterable<Settlement> settlements = const [],
  }) {
    final balances = <String, int>{
      for (final member in crib.members) member.id: 0,
    };
    for (final expense in expenses) {
      validateExpense(crib: crib, expense: expense);
      balances[expense.payerId] =
          balances[expense.payerId]! + expense.totalMinor;
      for (final share in expense.shares.entries) {
        balances[share.key] = balances[share.key]! - share.value;
      }
    }
    for (final settlement in settlements) {
      validateSettlement(crib: crib, settlement: settlement);
      if (settlement.status == SettlementStatus.confirmed ||
          settlement.status == SettlementStatus.selfManaged) {
        balances[settlement.fromMemberId] =
            balances[settlement.fromMemberId]! + settlement.amountMinor;
        balances[settlement.toMemberId] =
            balances[settlement.toMemberId]! - settlement.amountMinor;
      }
    }
    return Map.unmodifiable(balances);
  }

  /// A settlement plan that brings every member of the crib to zero.
  ///
  /// The plan is built from the pairwise debts, so every transfer it suggests
  /// stays inside the debt of that exact pair and can therefore be recorded.
  /// Mutual debts and debt cycles are cancelled first, so a crib that is
  /// already square does not suggest transfers that would cancel each other
  /// out.
  ///
  /// The net position of a member is still reported by [balances]. The two
  /// are different questions: the net position says how much a member is owed
  /// by the crib, the pairwise debt says who owes whom.
  static List<SettlementTransfer> suggestedTransfers({
    required Crib crib,
    required Iterable<Expense> expenses,
    Iterable<Settlement> settlements = const [],
  }) {
    final debts = _withoutCycles(
      _withoutMutualDebts(
        pairwiseDebts(
          crib: crib,
          expenses: expenses,
          settlements: settlements,
        ),
      ),
    );
    final transfers = <SettlementTransfer>[];
    final froms = debts.keys.toList()..sort();
    for (final from in froms) {
      final tos = debts[from]!.keys.toList()..sort();
      for (final to in tos) {
        final amount = debts[from]![to]!;
        if (amount > 0) {
          transfers.add(
            SettlementTransfer(
              fromId: from,
              toId: to,
              amountMinor: amount,
            ),
          );
        }
      }
    }
    return List.unmodifiable(transfers);
  }

  /// Cancels the part two members owe each other.
  ///
  /// When A owes B and B owes A, the smaller of the two debts is settled by
  /// the larger one. Neither of them has to pay it.
  static Map<String, Map<String, int>> _withoutMutualDebts(
    Map<String, Map<String, int>> debts,
  ) {
    final result = _copyDebts(debts);
    for (final from in result.keys.toList()) {
      for (final to in result[from]!.keys.toList()) {
        final back = result[to]?[from];
        if (back == null || back <= 0) continue;
        final forward = result[from]![to]!;
        final mutual = forward < back ? forward : back;
        result[from]![to] = forward - mutual;
        result[to]![from] = back - mutual;
      }
    }
    return _pruneDebts(result);
  }

  /// Cancels debts that run in a circle.
  ///
  /// A owes B, B owes C and C owes A: the three debts cancel each other out,
  /// so nobody has to pay anything.
  static Map<String, Map<String, int>> _withoutCycles(
    Map<String, Map<String, int>> debts,
  ) {
    final result = _copyDebts(debts);
    var guard = 0;
    while (guard++ < 1000) {
      final cycle = _findCycle(result);
      if (cycle == null) break;
      var smallest = result[cycle.first.$1]![cycle.first.$2]!;
      for (final edge in cycle) {
        final amount = result[edge.$1]![edge.$2]!;
        if (amount < smallest) smallest = amount;
      }
      for (final edge in cycle) {
        result[edge.$1]![edge.$2] = result[edge.$1]![edge.$2]! - smallest;
      }
      _pruneDebts(result);
    }
    return result;
  }

  /// Finds one cycle in the debt graph, if there is one.
  static List<(String, String)>? _findCycle(
    Map<String, Map<String, int>> graph,
  ) {
    final path = <String>[];
    final onPath = <String>{};
    final cycle = <(String, String)>[];

    bool visit(String node) {
      path.add(node);
      onPath.add(node);
      final edges = graph[node];
      if (edges != null) {
        for (final next in edges.keys) {
          if ((edges[next] ?? 0) <= 0) continue;
          if (onPath.contains(next)) {
            final start = path.indexOf(next);
            cycle
              ..clear()
              ..addAll([
                for (var i = start; i < path.length - 1; i++)
                  (path[i], path[i + 1]),
                (path.last, next),
              ]);
            return true;
          }
          if (visit(next)) return true;
        }
      }
      path.removeLast();
      onPath.remove(node);
      return false;
    }

    for (final node in graph.keys) {
      if (visit(node)) return cycle;
    }
    return null;
  }

  static Map<String, Map<String, int>> _copyDebts(
    Map<String, Map<String, int>> debts,
  ) => {
    for (final entry in debts.entries) entry.key: Map.of(entry.value),
  };

  static Map<String, Map<String, int>> _pruneDebts(
    Map<String, Map<String, int>> debts,
  ) {
    for (final from in debts.keys.toList()) {
      final row = debts[from]!;
      row.removeWhere((_, amount) => amount <= 0);
      if (row.isEmpty) debts.remove(from);
    }
    return debts;
  }

  static List<String> _uniqueIds(Iterable<String> ids, String label) {
    final result = ids.toList(growable: false);
    if (result.isEmpty ||
        result.any((id) => id.trim().isEmpty) ||
        result.toSet().length != result.length) {
      throw FinancialValidationException(
        '$label must be non-empty and unique.',
      );
    }
    return result;
  }

  static void _positiveAmount(int amount) {
    if (amount <= 0) {
      throw FinancialValidationException(
        'An amount must be greater than zero.',
      );
    }
    if (amount > Money.maxMinorUnits) {
      throw FinancialValidationException('An amount is too large.');
    }
  }
}

class SettlementTransfer {
  const SettlementTransfer({
    required this.fromId,
    required this.toId,
    required this.amountMinor,
  });
  final String fromId;
  final String toId;
  final int amountMinor;
}
