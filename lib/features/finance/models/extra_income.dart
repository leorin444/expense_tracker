import 'package:hive/hive.dart';

part 'extra_income.g.dart';

@HiveType(typeId: 5) // ⚠️ use a unique ID
class ExtraIncome {
  @HiveField(0)
  final String source;

  @HiveField(1)
  final double amount;

  @HiveField(2)
  final DateTime date;

  @HiveField(3)
  final String userId;

  ExtraIncome({
    required this.source,
    required this.amount,
    required this.date,
    required this.userId,
  });
}
