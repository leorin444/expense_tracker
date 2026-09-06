class FinanceProfile {
  final String userId;
  final double monthlyIncome;
  final double savingsPercentage;
  
  /// Fixed recurring expenses (rent, bills, etc.)
  final double fixedExpenses;

  FinanceProfile({
    required this.userId,
    required this.monthlyIncome,
    required this.savingsPercentage,
    this.fixedExpenses = 0.0,
  });

  /// ✅ Helper (based only on base income)
  /// NOTE: This does NOT include extra income.
  double get savingsAmount => monthlyIncome * (savingsPercentage / 100);

  /// ⚠️ Base spendable (without extra income)
  /// Final spendable should be calculated in FinanceProvider
  double get baseSpendable => monthlyIncome - savingsAmount - fixedExpenses;

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'monthlyIncome': monthlyIncome,
      'savingsPercentage': savingsPercentage,
      'fixedExpenses': fixedExpenses,
    };
  }

  factory FinanceProfile.fromMap(Map<String, dynamic> map) {
    return FinanceProfile(
      userId: map['userId']?.toString() ?? '',
      monthlyIncome: (map['monthlyIncome'] as num?)?.toDouble() ?? 0.0,
      savingsPercentage: (map['savingsPercentage'] as num?)?.toDouble() ?? 0.0,
      fixedExpenses: (map['fixedExpenses'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
