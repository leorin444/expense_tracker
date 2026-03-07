import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/expense.dart';
import '../repository/expense_repository.dart';
import '../../expense/services/sync_service.dart';

class ExpenseProvider with ChangeNotifier {
  final ExpenseRepository repository;
  final SyncService _syncService = SyncService();
  final _uuid = const Uuid();

  ExpenseProvider(this.repository) {
    loadExpenses();
  }

  List<Expense> _expenses = [];
  List<Expense> get expenses => List.unmodifiable(_expenses);

  bool _isAdding = false;

  // -------------------- USER PROFILE --------------------

  double _monthlyLimit = 50000;
  double get monthlyLimit => _monthlyLimit;

  void setMonthlyLimit(double limit) {
    _monthlyLimit = limit;
    notifyListeners();
  }

  // -------------------- LOAD EXPENSES --------------------

  Future<void> loadExpenses() async {
    try {
      _expenses = repository.getExpenses();
      _expenses.sort((a, b) => b.date.compareTo(a.date));
      notifyListeners();
    } catch (e) {
      debugPrint("Error loading expenses: $e");
    }
  }

  // -------------------- MONTHLY SPENDING --------------------

  double getMonthlySpent(DateTime date) {
    return _expenses
        .where((e) => e.date.year == date.year && e.date.month == date.month)
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  double getRemainingBudget(DateTime date) {
    final spent = getMonthlySpent(date);
    return _monthlyLimit - spent;
  }

  List<Expense> getExpensesByDate(DateTime date) {
    return _expenses.where((expense) {
      return expense.date.year == date.year &&
          expense.date.month == date.month &&
          expense.date.day == date.day;
    }).toList();
  }

  // -------------------- ADD EXPENSE --------------------

  Future<void> addExpense({
    required BuildContext context,
    required String title,
    required double amount,
    required String category,
    required DateTime date,
  }) async {
    if (_isAdding) return;
    _isAdding = true;

    try {
      final monthlySpent = getMonthlySpent(date);

      if (monthlySpent + amount > _monthlyLimit) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Expense limit exceeded! Limit: Rs $_monthlyLimit'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
        return;
      }

      final newExpense = Expense(
        id: _uuid.v4(),
        title: title,
        amount: amount,
        category: category,
        date: date,
      );

      // Save locally
      await repository.addExpense(newExpense);

      _expenses.insert(0, newExpense);
      notifyListeners();

      // Upload to cloud
      await _syncService.uploadExpense(newExpense);
    } catch (e) {
      debugPrint("Error adding expense: $e");
    } finally {
      _isAdding = false;
    }
  }

  // -------------------- ADD EXISTING (SYNC / UNDO) --------------------

  Future<void> addExistingExpense(Expense expense) async {
    try {
      if (_expenses.any((e) => e.id == expense.id)) return;

      await repository.addExpense(expense);

      _expenses.insert(0, expense);
      notifyListeners();

      await _syncService.uploadExpense(expense);
    } catch (e) {
      debugPrint("Error restoring expense: $e");
    }
  }

  // -------------------- UPDATE EXPENSE --------------------

  Future<void> updateExpense({
    required String id,
    required String title,
    required double amount,
    required String category,
    required DateTime date,
  }) async {
    final index = _expenses.indexWhere((e) => e.id == id);
    if (index == -1) return;

    try {
      final updated = Expense(
        id: id,
        title: title,
        amount: amount,
        category: category,
        date: date,
      );

      await repository.updateExpense(updated);

      _expenses[index] = updated;
      notifyListeners();

      await _syncService.uploadExpense(updated);
    } catch (e) {
      debugPrint("Error updating expense: $e");
    }
  }

  // -------------------- REMOVE EXPENSE --------------------

  Future<void> removeExpense(String id) async {
    try {
      await repository.deleteExpense(id);

      _expenses.removeWhere((e) => e.id == id);
      notifyListeners();

      await _syncService.deleteExpense(id);
    } catch (e) {
      debugPrint("Error deleting expense: $e");
    }
  }

  // -------------------- CATEGORY ANALYTICS --------------------

  Map<String, double> getCategoryTotals() {
    final Map<String, double> data = {};

    for (var expense in _expenses) {
      data.update(
        expense.category,
        (value) => value + expense.amount,
        ifAbsent: () => expense.amount,
      );
    }

    return data;
  }

  // -------------------- RECENT EXPENSES --------------------

  List<Expense> getRecentExpenses(int count) {
    return _expenses.take(count).toList();
  }

  // -------------------- CLOUD SYNC --------------------

  Future<void> syncAllExpenses() async {
    try {
      await _syncService.syncExpenses();
      await fetchCloudExpenses();
    } catch (e) {
      debugPrint("Sync failed: $e");
    }
  }

  Future<void> fetchCloudExpenses() async {
    try {
      await _syncService.fetchExpenses();
      await loadExpenses();
    } catch (e) {
      debugPrint("Fetch cloud expenses failed: $e");
    }
  }
}
