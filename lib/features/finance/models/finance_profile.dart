class FinanceProfile {
  final double monthlyIncome;
  final double savingsPercentage;

  FinanceProfile({
    required this.monthlyIncome,
    required this.savingsPercentage,
  });

  double get savingsAmount => monthlyIncome * (savingsPercentage / 100);

  double get spendableAmount => monthlyIncome - savingsAmount;
}
