import 'package:flutter/material.dart';
import '../../expense/providers/expense_provider.dart';

class CategoryAnalyticsProvider with ChangeNotifier {
  final ExpenseProvider expenseProvider;

  CategoryAnalyticsProvider(this.expenseProvider);

  Map<String, double> get categoryTotals {
    final data = <String, double>{};
    for (var expense in expenseProvider.expenses) {
      data.update(
        expense.category,
        (value) => value + expense.amount,
        ifAbsent: () => expense.amount,
      );
    }
    return data;
  }

  double getTotalAmount() {
    return expenseProvider.expenses.fold(
      0.0,
      (previousValue, element) => previousValue + element.amount,
    );
  }
}
