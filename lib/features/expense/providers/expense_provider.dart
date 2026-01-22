import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/expense.dart';
import 'package:uuid/uuid.dart';

class ExpenseProvider with ChangeNotifier {
  final List<Expense> _expenses = [];
  final _uuid = const Uuid();
  late Box<Expense> _box;

  bool _isAdding = false;

  ExpenseProvider() {
    _init();
  }

  Future<void> _init() async {
    _box = Hive.box<Expense>('expensesBox');
    _expenses.addAll(_box.values.toList().reversed); // most recent first
    notifyListeners();
  }

  List<Expense> get expenses => List.unmodifiable(_expenses);

  void addExpense({
    required String title,
    required double amount,
    required String category,
    required DateTime date,
  }) {
    if (_isAdding) return;
    _isAdding = true;

    final newExpense = Expense(
      id: _uuid.v4(),
      title: title,
      amount: amount,
      category: category,
      date: date,
    );

    _expenses.insert(0, newExpense);
    _box.put(newExpense.id, newExpense);

    notifyListeners();

    Future.microtask(() => _isAdding = false);
  }

  void updateExpense({
    required String id,
    required String title,
    required double amount,
    required String category,
    required DateTime date,
  }) {
    final index = _expenses.indexWhere((e) => e.id == id);
    if (index == -1) return;

    final updatedExpense = Expense(
      id: id,
      title: title,
      amount: amount,
      category: category,
      date: date,
    );

    _expenses[index] = updatedExpense;
    _box.put(id, updatedExpense);

    notifyListeners();
  }

  void removeExpense(String id) {
    _expenses.removeWhere((e) => e.id == id);
    _box.delete(id);
    notifyListeners();
  }
}
