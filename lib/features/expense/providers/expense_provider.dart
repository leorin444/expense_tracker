import 'package:flutter/material.dart';
import '../models/expense.dart';
import 'package:uuid/uuid.dart';

class ExpenseProvider with ChangeNotifier {
  final List<Expense> _expenses = [];
  final _uuid = const Uuid();

  // -------------------- USER PROFILE --------------------
  double _monthlyLimit = 50000; // default value
  double get monthlyLimit => _monthlyLimit;

  void setMonthlyLimit(double limit) {
    _monthlyLimit = limit;
    notifyListeners();
  }

  // -------------------- EXPENSE LIST --------------------
  List<Expense> get expenses => List.unmodifiable(_expenses);

  bool _isAdding = false;

  // -------------------- ADD EXPENSE --------------------
  void addExpense({
    required BuildContext context,
    required String title,
    required double amount,
    required String category,
    required DateTime date,
  }) {
    if (_isAdding) return; // prevent duplicate calls
    _isAdding = true;

    // --------- Monthly limit validation ---------
    final now = DateTime.now();
    final monthlySpent = _expenses
        .where((e) => e.date.year == now.year && e.date.month == now.month)
        .fold<double>(0, (sum, e) => sum + e.amount);

    if (monthlySpent + amount > _monthlyLimit) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Expense limit exceeded for this month! Limit: Rs $_monthlyLimit',
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
      _isAdding = false;
      return;
    }

    // --------- Add the expense ---------
    final newExpense = Expense(
      id: _uuid.v4(),
      title: title,
      amount: amount,
      category: category,
      date: date,
    );

    _expenses.insert(0, newExpense);
    notifyListeners();

    Future.microtask(() => _isAdding = false);
  }

  // -------------------- UPDATE EXPENSE --------------------
  void updateExpense({
    required String id,
    required String title,
    required double amount,
    required String category,
    required DateTime date,
  }) {
    final index = _expenses.indexWhere((e) => e.id == id);
    if (index == -1) return;

    _expenses[index] = Expense(
      id: id,
      title: title,
      amount: amount,
      category: category,
      date: date,
    );

    notifyListeners();
  }

  // -------------------- REMOVE EXPENSE --------------------
  void removeExpense(String id) {
    _expenses.removeWhere((e) => e.id == id);
    notifyListeners();
  }
}
