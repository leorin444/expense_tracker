import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/expense.dart';
import '../repository/expense_repository.dart';
import '../../finance/providers/finance_provider.dart';
import '../../../core/utils/expense_policy.dart';
import '../../../core/services/hive_service.dart';

enum AddExpenseResult { success, cancelled, needsIncome }

class ExpenseProvider with ChangeNotifier {
  final ExpenseRepository repository;

  List<Expense> _expenses = [];
  List<Expense> get expenses => List.unmodifiable(_expenses);

  bool _isAdding = false;
  bool get isAdding => _isAdding;

  double _monthlyLimit = 50000;
  double get monthlyLimit => _monthlyLimit;

  String? _currentUserId;
  String? get currentUserId => _currentUserId;

  ExpenseProvider(this.repository) {
    FirebaseAuth.instance.authStateChanges().listen((user) {
      _handleUserChange(user?.uid);
    });
  }

  Future<void> _handleUserChange(String? uid) async {
    _currentUserId = uid;

    if (uid == null) {
      // Clear this user's expenses from local storage on logout for security
      try {
        final box = HiveService.getExpenses();
        await box.clear();
      } catch (_) {}
      _expenses = [];
      notifyListeners();
      return;
    }

    await Future.delayed(const Duration(milliseconds: 100));
    await loadExpenses();
  }

  /// ================= LOAD =================
  Future<void> loadExpenses() async {
    if (_currentUserId == null) {
      _expenses = [];
      notifyListeners();
      return;
    }

    try {
      final allExpenses = await repository.getExpensesByUser(_currentUserId!);

      _expenses = allExpenses..sort((a, b) => b.date.compareTo(a.date));

      notifyListeners();
    } catch (e) {
      debugPrint("Load error: $e");
    }
  }

  /// ================= FETCH FROM SERVER =================
  Future<void> fetchExpensesFromServer() async {
    _currentUserId ??= FirebaseAuth.instance.currentUser?.uid;
    if (_currentUserId == null) return;

    try {
      final serverExpenses = await repository.fetchExpensesFromServer(_currentUserId!);

      if (serverExpenses.isNotEmpty) {
        _expenses = serverExpenses..sort((a, b) => b.date.compareTo(a.date));
        notifyListeners();
      }
      // If server returns empty (network blip / not synced yet), keep existing local data
    } catch (e) {
      debugPrint("Fetch expenses from server error: $e");
    }
  }

  /// ================= EXPORT CSV =================
  Future<String?> exportToCSV(List<Expense> expenses) async {
    try {
      final buffer = StringBuffer();
      buffer.writeln("Title,Amount,Category,Date");

      for (var e in expenses) {
        // Escape commas/quotes in fields
        final title = '"${e.title.replaceAll('"', '""')}"';
        final category = '"${e.category.replaceAll('"', '""')}"';
        buffer.writeln("$title,${e.amount},$category,${e.date.toIso8601String()}");
      }

      // Choose export directory based on platform
      String dirPath;
      if (Platform.isAndroid) {
        dirPath = '/storage/emulated/0/Download';
      } else {
        dirPath = Directory.systemTemp.path;
      }

      final directory = Directory(dirPath);
      if (!directory.existsSync()) {
        directory.createSync(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${directory.path}/expenses_$timestamp.csv');
      await file.writeAsString(buffer.toString());
      return file.path;
    } catch (e) {
      debugPrint('CSV export failed: $e');
      return null;
    }
  }

  /// ================= ANALYTICS =================
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

  double getMonthlySpent(DateTime date) {
    return _expenses
        .where((e) => e.date.year == date.year && e.date.month == date.month)
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  List<Expense> getExpensesByDate(DateTime date) {
    return _expenses.where((e) {
      return e.date.year == date.year &&
          e.date.month == date.month &&
          e.date.day == date.day;
    }).toList();
  }

  List<Expense> getExpensesByCategory(String category) {
    return _expenses.where((e) => e.category == category).toList();
  }

  Map<String, double> getCategoryTotalsByMonth(DateTime date) {
    final Map<String, double> data = {};

    for (var e in _expenses) {
      if (e.date.year == date.year && e.date.month == date.month) {
        data.update(
          e.category,
          (value) => value + e.amount,
          ifAbsent: () => e.amount,
        );
      }
    }

    return data;
  }

  List<Expense> getRecentExpenses(int count) {
    return _expenses.take(count).toList();
  }

  /// ================= BUDGET =================
  void setMonthlyLimit(double limit) {
    _monthlyLimit = limit;
    notifyListeners();
  }

  double getRemainingBudget(BuildContext context, DateTime date) {
    final finance = context.read<FinanceProvider>();

    final limit = finance.isConfigured
        ? finance.spendableAmount
        : _monthlyLimit;

    return limit - getMonthlySpent(date);
  }

  ExpenseDecision checkExpense({
    required double amount,
    required DateTime date,
    required double spendable,
    required double totalIncome,
  }) {
    final spent = getMonthlySpent(date);

    return ExpensePolicy.evaluate(
      amount: amount,
      spent: spent,
      spendable: spendable,
      totalIncome: totalIncome,
    );
  }

  /// ================= ADD EXPENSE =================
  Future<AddExpenseResult> addExpense(Expense expense) async {
    if (_isAdding || _currentUserId == null) {
      return AddExpenseResult.cancelled;
    }

    _isAdding = true;
    notifyListeners();

    try {
      await repository.addExpense(expense);

      _expenses = [expense, ..._expenses];
      notifyListeners();

      return AddExpenseResult.success;
    } catch (e) {
      return AddExpenseResult.cancelled;
    } finally {
      _isAdding = false;

      notifyListeners();
    }
  }

  /// ================= UPDATE =================
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
    } catch (e) {
      debugPrint("Update error: $e");
    }
  }

  /// ================= DELETE =================
  Future<void> removeExpense(String id) async {
    if (_currentUserId == null) return;

    try {
      await repository.deleteExpense(id);

      _expenses = _expenses.where((e) => e.id != id).toList();

      notifyListeners();
    } catch (e) {
      debugPrint("Delete error: $e");
    }
  }

  Future<void> addExistingExpense(Expense expense) async {
    try {
      await repository.addExpense(expense);

      _expenses = [expense, ..._expenses];
      notifyListeners();
    } catch (e) {
      debugPrint("Restore error: $e");
    }
  }
}
