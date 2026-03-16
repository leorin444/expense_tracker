import '../models/expense.dart';
import '../data/expense_local_datasource.dart';

class ExpenseRepository {
  final ExpenseLocalDataSource localDataSource;

  ExpenseRepository(this.localDataSource);

  /// Get all expenses (legacy fallback)
  List<Expense> getExpenses() {
    final expenses = localDataSource.getExpenses();
    expenses.sort((a, b) => b.date.compareTo(a.date));
    return expenses;
  }

  /// Get expenses for a specific user
  List<Expense> getExpensesByUser(String userId) {
    final expenses = localDataSource
        .getExpenses()
        .where((e) => e.userId == userId)
        .toList();

    expenses.sort((a, b) => b.date.compareTo(a.date));
    return expenses;
  }

  /// Add a new expense
  Future<void> addExpense(Expense expense) async {
    await localDataSource.addExpense(expense);
  }

  /// Update an existing expense by id
  Future<void> updateExpense(Expense expense) async {
    await localDataSource.updateExpense(expense);
  }

  /// Delete an expense by id
  Future<void> deleteExpense(String id) async {
    await localDataSource.deleteExpense(id);
  }
}
