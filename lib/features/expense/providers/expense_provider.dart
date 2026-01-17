import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/expense.dart';

class ExpenseProvider extends ChangeNotifier {
  final List<Expense> _expenses = [];

  List<Expense> get expenses => List.unmodifiable(_expenses);

  void addExpense({
    required String title,
    required double amount,
    required String category,
    required DateTime date,
  }) {
    final newExpense = Expense(
      id: const Uuid().v4(),
      title: title,
      amount: amount,
      category: category,
      date: date,
    );

    _expenses.add(newExpense);
    notifyListeners();
  }

  void clearExpenses() {
    _expenses.clear();
    notifyListeners();
  }
}
