import 'package:hive_flutter/hive_flutter.dart';
import '../models/expense.dart';

class ExpenseLocalDataSource {
  static const String _boxName = 'expensesBox';

  Future<Box<Expense>> _getBox() async => Hive.box<Expense>(_boxName);

  List<Expense> getExpenses() {
    final box = Hive.box<Expense>(_boxName);
    return box.values.toList();
  }

  Future<void> addExpense(Expense expense) async {
    final box = await _getBox();
    await box.put(expense.id, expense);
  }

  Future<void> updateExpense(Expense expense) async {
    final box = await _getBox();
    if (box.containsKey(expense.id)) {
      await box.put(expense.id, expense);
    }
  }

  Future<void> deleteExpense(String id) async {
    final box = await _getBox();
    if (box.containsKey(id)) {
      await box.delete(id);
    }
  }
}
