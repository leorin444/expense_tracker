import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../expense/models/expense.dart';
import '../models/budget.dart';

class BudgetProvider with ChangeNotifier {
  final List<Budget> _budgets = [];

  List<Budget> get budgets => _budgets;

  void setBudget(String category, double limit) {
    final index = _budgets.indexWhere((b) => b.category == category);

    if (index != -1) {
      _budgets[index] = Budget(
        id: _budgets[index].id,
        category: category,
        limit: limit,
      );
    } else {
      _budgets.add(
        Budget(id: const Uuid().v4(), category: category, limit: limit),
      );
    }

    notifyListeners();
  }

  double spentForCategory(String category, List<Expense> expenses) {
    return expenses
        .where((e) => e.category == category)
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  double remaining(String category, List<Expense> expenses) {
    final budget = _budgets.firstWhere(
      (b) => b.category == category,
      orElse: () {
        return Budget(id: '', category: category, limit: 0);
      },
    );

    return budget.limit - spentForCategory(category, expenses);
  }
}
