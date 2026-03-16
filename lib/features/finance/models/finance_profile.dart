import 'package:hive/hive.dart';

part 'finance_profile.g.dart';

@HiveType(typeId: 1)
class FinanceProfile {
  @HiveField(0)
  final double monthlyIncome;
  @HiveField(1)
  final double savingsPercentage;

  FinanceProfile({
    required this.monthlyIncome,
    required this.savingsPercentage,
  });

  double get savingsAmount => monthlyIncome * (savingsPercentage / 100);

  double get spendableAmount => monthlyIncome - savingsAmount;
}
