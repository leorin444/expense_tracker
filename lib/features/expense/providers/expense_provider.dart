

import 'package:flutter/material.dart';
import '../models/expense.dart';
import 'package:uuid/uuid.dart';

class ExpenseProvider with ChangeNotifier {
  final List<Expense> _expenses = [];

  List<Expense> get expenses => List.unmodifiable(_expenses);

  void addExpense({required String title, required double amount, required String category, required DateTime date}) {
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

  void removeExpense(String id) {
    _expenses.removeWhere((e) => e.id == id);
    notifyListeners();
  }

  double get totalAmount => _expenses.fold(0, (sum, e) => sum + e.amount);
}
