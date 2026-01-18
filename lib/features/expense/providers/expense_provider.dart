import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';
import '../models/expense.dart';

final _logger = Logger();

class ExpenseProvider extends ChangeNotifier {
  final List<Expense> _expenses = [];
  final _uuid = const Uuid();

  /// Immutable list for UI
  List<Expense> get expenses => List.unmodifiable(_expenses);

  /// Total of all expenses
  double get totalAmount => _expenses.fold(0, (sum, e) => sum + e.amount);

  /// Add new expense
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

  /// Remove expense
  void removeExpense(String id) {
    final index = _expenses.indexWhere((e) => e.id == id);
    if (index == -1) return;

    final removed = _expenses.removeAt(index);
    _logger.w('Expense removed: ${removed.toJson()}');
    notifyListeners();
  }

  // =========================
  // Day 9 – Analytics helpers
  // =========================

  /// Category-wise totals
  Map<String, double> get categoryTotals {
    final Map<String, double> totals = {};

    for (final e in _expenses) {
      totals[e.category] = (totals[e.category] ?? 0) + e.amount;
    }

    return totals;
  }

  /// Expenses for a given month
  List<Expense> expensesForMonth(DateTime month) {
    return _expenses
        .where((e) => e.date.month == month.month && e.date.year == month.year)
        .toList();
  }
}
