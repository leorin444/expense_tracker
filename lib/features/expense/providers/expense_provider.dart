import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/expense.dart';
import '../repository/expense_repository.dart';
import '../../expense/services/sync_service.dart';
import '../../finance/providers/finance_provider.dart';

class ExpenseProvider with ChangeNotifier {
  final ExpenseRepository repository;
  final SyncService _syncService = SyncService();
  final _uuid = const Uuid();

  List<Expense> _expenses = [];
  List<Expense> get expenses => List.unmodifiable(_expenses);

  bool _isAdding = false;
  bool get isAdding => _isAdding;

  double _monthlyLimit = 50000;
  double get monthlyLimit => _monthlyLimit;

  String? _currentUserId;

  ExpenseProvider(this.repository) {
    // Listen for Firebase auth changes to switch users automatically
    FirebaseAuth.instance.authStateChanges().listen((user) {
      _handleUserChange(user?.uid);
    });
  }

  void setMonthlyLimit(double limit) {
    _monthlyLimit = limit;
    notifyListeners();
  }

  /// Called whenever the logged-in user changes
  Future<void> _handleUserChange(String? uid) async {
    _currentUserId = uid;
    await loadExpenses();
  }

  /// Load only expenses belonging to current user
  Future<void> loadExpenses() async {
    if (_currentUserId == null) {
      _expenses = [];
      notifyListeners();
      return;
    }

    try {
      _expenses = repository
          .getExpenses()
          .where((e) => e.userId == _currentUserId)
          .toList();
      _expenses.sort((a, b) => b.date.compareTo(a.date));
      notifyListeners();
    } catch (e) {
      debugPrint("Error loading expenses: $e");
    }
  }

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

  Future<void> addExpense({
    required BuildContext context,
    required String title,
    required double amount,
    required String category,
    required DateTime date,
  }) async {
    if (_isAdding || _currentUserId == null) return;

    _isAdding = true;
    notifyListeners();

    try {
      final finance = context.read<FinanceProvider>();
      final limit = finance.profile?.spendableAmount ?? _monthlyLimit;
      final monthlySpent = getMonthlySpent(date);

      if (monthlySpent + amount > limit) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Expense limit exceeded! Limit: Rs $limit'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
        return;
      }

      final newExpense = Expense(
        id: _uuid.v4(),
        userId: _currentUserId!,
        title: title,
        amount: amount,
        category: category,
        date: date,
      );

      await repository.addExpense(newExpense);
      _expenses.insert(0, newExpense);
      notifyListeners();

      // Sync to cloud asynchronously
      _syncService.uploadExpense(newExpense).catchError((e) {
        debugPrint('Failed to sync expense: $e');
      });
    } catch (e) {
      debugPrint("Error adding expense: $e");
    } finally {
      _isAdding = false;
      notifyListeners();
    }
  }

  Future<void> updateExpense({
    required String id,
    required String title,
    required double amount,
    required String category,
    required DateTime date,
  }) async {
    if (_currentUserId == null) return;

    final index = _expenses.indexWhere((e) => e.id == id);
    if (index == -1) return;

    try {
      final updated = Expense(
        id: id,
        userId: _currentUserId!,
        title: title,
        amount: amount,
        category: category,
        date: date,
      );

      await repository.updateExpense(updated);
      _expenses[index] = updated;
      notifyListeners();

      _syncService.uploadExpense(updated).catchError((e) {
        debugPrint('Failed to sync updated expense: $e');
      });
    } catch (e) {
      debugPrint("Error updating expense: $e");
    }
  }

  Future<void> removeExpense(String id) async {
    if (_currentUserId == null) return;

    try {
      await repository.deleteExpense(id);
      _expenses.removeWhere((e) => e.id == id);
      notifyListeners();

      _syncService.deleteExpense(id as Expense).catchError((e) {
        debugPrint('Failed to sync delete expense: $e');
      });
    } catch (e) {
      debugPrint("Error deleting expense: $e");
    }
  }

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

  List<Expense> getRecentExpenses(int count) {
    return _expenses.take(count).toList();
  }

  Future<void> syncAllExpenses() async {
    try {
      await _syncService.syncExpenses(userId: _currentUserId);
      await fetchCloudExpenses();
    } catch (e) {
      debugPrint("Sync failed: $e");
    }
  }

  Future<void> addExistingExpense(Expense expense) async {
    try {
      await repository.addExpense(expense);
      _expenses.insert(0, expense);
      notifyListeners();

      _syncService.uploadExpense(expense).catchError((e) {
        debugPrint('Failed to sync restored expense: $e');
      });
    } catch (e) {
      debugPrint("Error restoring expense: $e");
    }
  }

  Future<void> fetchCloudExpenses() async {
    if (_currentUserId == null) return;

    try {
      await _syncService.fetchExpenses(userId: _currentUserId!);
      await loadExpenses();
    } catch (e) {
      debugPrint("Fetch cloud expenses failed: $e");
    }
  }
}
