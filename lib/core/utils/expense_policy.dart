enum ExpenseDecisionType { ok, warnSpendableExceeded, needsIncome, block }

class ExpenseDecision {
  final ExpenseDecisionType type;
  final String? message;

  ExpenseDecision(this.type, {this.message});
}

class ExpensePolicy {
  static ExpenseDecision evaluate({
    required double amount,
    required double spent,
    required double spendable,
    required double totalIncome,
  }) {
    final projectedTotal = spent + amount;

    // ❌ INVALID
    if (amount <= 0) {
      return ExpenseDecision(
        ExpenseDecisionType.block,
        message: "Invalid amount",
      );
    }

    // 🚨 LEVEL 2: TOTAL INCOME EXCEEDED
    if (projectedTotal > totalIncome) {
      return ExpenseDecision(
        ExpenseDecisionType.needsIncome,
        message: "Monthly income exceeded. Add extra income?",
      );
    }

    // ⚠️ LEVEL 1: SPENDABLE EXCEEDED
    if (projectedTotal > spendable) {
      return ExpenseDecision(
        ExpenseDecisionType.warnSpendableExceeded,
        message: "Spendable limit exceeded. Savings will be reduced.",
      );
    }

    // ✅ OK
    return ExpenseDecision(ExpenseDecisionType.ok);
  }
}
