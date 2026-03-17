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
  final Uuid _uuid = const Uuid();
  List<Expense> _expenses = [];
  List<Expense> get expenses => List.unmodifiable(_expenses);
  bool _isAdding = false;
  bool get isAdding => _isAdding;
  double _monthlyLimit = 50000;
  double get monthlyLimit => _monthlyLimit;
  String? _currentUserId;
  ExpenseProvider(this.repository) {
    // Listen for Firebase auth changes
    FirebaseAuth.instance.authStateChanges().listen((user) {
      _handleUserChange(user?.uid);
    });
  }
  Future<void> _handleUserChange(String? uid) async {
    _currentUserId = uid;
    if (uid == null) {
      _expenses = [];
      notifyListeners();
      return;
    }
    await Future.delayed(const Duration(milliseconds: 100));
    await loadExpenses();
  }

  Future<void> loadExpenses() async {
    if (_currentUserId == null) {
      _expenses = [];
      notifyListeners();
      return;
    }
    try {
      final allExpenses = repository.getExpenses();
      _expenses = allExpenses.where((e) => e.userId == _currentUserId).toList()
        ..sort((a, b) => b.date.compareTo(a.date));
      notifyListeners();
    } catch (e) {
      debugPrint("Load error: $e");
    }
  }

  void setMonthlyLimit(double limit) {
    _monthlyLimit = limit;
    notifyListeners();
  }

  double getMonthlySpent(DateTime date) {
    return _expenses
        .where((e) => e.date.year == date.year && e.date.month == date.month)
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  double getRemainingBudget(DateTime date) {
    return _monthlyLimit - getMonthlySpent(date);
  }

  List<Expense> getExpensesByDate(DateTime date) {
    return _expenses.where((e) {
      return e.date.year == date.year &&
          e.date.month == date.month &&
          e.date.day == date.day;
    }).toList();
  }

  Future<bool> addExpense({
    required BuildContext context,
    required String title,
    required double amount,
    required String category,
    required DateTime date,
  }) async {
    if (_isAdding || _currentUserId == null) return false;
    _isAdding = true;
    notifyListeners();
    try {
      final finance = context.read<FinanceProvider>();
      final limit = finance.profile?.spendableAmount ?? _monthlyLimit;
      final spent = getMonthlySpent(date);
      if (spent + amount > limit) return false;
      final expense = Expense(
        id: _uuid.v4(),
        userId: _currentUserId!,
        title: title,
        amount: amount,
        category: category,
        date: date,
      );
      await repository.addExpense(expense);
      _expenses = [expense, ..._expenses];
      notifyListeners();
      _syncService
          .uploadExpense(expense)
          .catchError((e) => debugPrint("Sync add failed: $e"));
      return true;
    } catch (e) {
      debugPrint("Add error: $e");
      return false;
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
      final old = _expenses[index];
      final updated = Expense(
        id: old.id,
        userId: old.userId,
        title: title,
        amount: amount,
        category: category,
        date: date,
      );
      await repository.updateExpense(updated);
      _expenses = List.from(_expenses)..[index] = updated;
      notifyListeners();
      _syncService
          .uploadExpense(updated)
          .catchError((e) => debugPrint("Sync update failed: $e"));
    } catch (e) {
      debugPrint("Update error: $e");
    }
  }

  Future<void> removeExpense(String id) async {
    if (_currentUserId == null) return;
    try {
      await repository.deleteExpense(id);
      _expenses = _expenses.where((e) => e.id != id).toList();
      notifyListeners();
      _syncService
          .deleteExpense(userId: _currentUserId!, expenseId: id)
          .catchError((e) => debugPrint("Sync delete failed: $e"));
    } catch (e) {
      debugPrint("Delete error: $e");
    }
  }

  Map<String, double> getCategoryTotals() {
    final Map<String, double> data = {};
    for (var e in _expenses) {
      data.update(
        e.category,
        (value) => value + e.amount,
        ifAbsent: () => e.amount,
      );
    }
    return data;
  }

  List<Expense> getRecentExpenses(int count) {
    return _expenses.take(count).toList();
  }

  Future<void> syncAllExpenses() async {
    if (_currentUserId == null) return;
    try {
      await _syncService.syncExpenses(userId: _currentUserId!);
      await fetchCloudExpenses();
    } catch (e) {
      debugPrint("Sync error: $e");
    }
  }

  Future<void> fetchCloudExpenses() async {
    if (_currentUserId == null) return;
    try {
      await _syncService.fetchExpenses(userId: _currentUserId!);
      await loadExpenses();
    } catch (e) {
      debugPrint("Fetch error: $e");
    }
  }

  Future<void> addExistingExpense(Expense expense) async {
    try {
      await repository.addExpense(expense);
      _expenses = [expense, ..._expenses];
      notifyListeners();
      _syncService
          .uploadExpense(expense)
          .catchError((e) => debugPrint("Sync restore failed: $e"));
    } catch (e) {
      debugPrint("Restore error: $e");
    }
  }
}
