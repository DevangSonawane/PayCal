import 'package:paycal/data/models.dart';
import 'package:paycal/domain/financial_ledger.dart';

/// Legacy adapter retained while screens are migrated to [FinancialLedger].
/// New domain code must use FinancialLedger directly.
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
  /// Equal split. Remainder minor units go to the payer first.
  static Map<String, int> equalSplit({
    required int totalMinor,
    required List<String> memberIds,
    required String payerId,
  }) {
    return FinancialLedger.equalSplit(
      totalMinor: totalMinor,
      participantIds: memberIds,
      payerId: payerId,
    );
  }

  /// Net per member: positive = owed to them, negative = they owe.
  static Map<String, int> nets(
    List<ExpenseInput> expenses,
    List<String> memberIds,
  ) {
    final crib = Crib(
      id: '_legacy',
      name: '_legacy',
      currency: '_legacy',
      members: [for (final id in memberIds) Member(id: id, name: id)],
      categories: const [],
    );
    final ledgerExpenses = expenses
        .map(
          (expense) => Expense(
            id: '${expense.payerId}-${expense.totalMinor}',
            cribId: crib.id,
            description: '_legacy',
            totalMinor: expense.totalMinor,
            currency: crib.currency,
            payerId: expense.payerId,
            shares: expense.shares,
            date: DateTime.fromMillisecondsSinceEpoch(0),
            category: '_legacy',
          ),
        )
        .toList();
    return FinancialLedger.balances(crib: crib, expenses: ledgerExpenses);
  }
}
