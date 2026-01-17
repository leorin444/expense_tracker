import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';
import '../models/expense.dart';

final _logger = Logger();

class ExpenseProvider extends ChangeNotifier {
  final List<Expense> _expenses = [];
  final _uuid = const Uuid();

  List<Expense> get expenses => List.unmodifiable(_expenses);

  double get totalAmount => _expenses.fold(0, (sum, e) => sum + e.amount);

  void addExpense({
    required String title,
    required double amount,
    required String category,
    required DateTime date,
  }) {
    final expense = Expense(
      id: _uuid.v4(),
      title: title.trim(),
      amount: amount,
      category: category,
      date: date,
    );

    _expenses.insert(0, expense);

    _logger.i('Expense added: ${expense.toJson()}');
    notifyListeners();
  }

  void removeExpense(String id) {
    final index = _expenses.indexWhere((e) => e.id == id);
    if (index == -1) return;

    final removed = _expenses.removeAt(index);
    _logger.w('Expense removed: ${removed.toJson()}');
    notifyListeners();
  }
}
