import 'package:hive/hive.dart';

part 'finance_profile.g.dart';

@HiveType(typeId: 2)
class FinanceProfile extends HiveObject {
  @HiveField(0)
  final String userId;

  @HiveField(1)
  final double monthlyIncome;

  @HiveField(2)
  final double savingsPercentage;

  /// Fixed recurring expenses (rent, bills, etc.)
  @HiveField(3)
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
}
