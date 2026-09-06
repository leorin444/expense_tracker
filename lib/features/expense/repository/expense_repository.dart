import '../models/expense.dart';
import '../data/expense_remote_datasource.dart';

class ExpenseRepository {
  final ExpenseRemoteDataSource remoteDataSource;

  ExpenseRepository(this.remoteDataSource);

  /// Get expenses for a specific user from local store
  Future<List<Expense>> getExpensesByUser(String userId) async {
    final expenses = await remoteDataSource.getExpensesByUser(userId);
    expenses.sort((a, b) => b.date.compareTo(a.date));
    return expenses;
  }

  /// Pull latest expenses from live server and save to local store
  Future<List<Expense>> fetchExpensesFromServer(String userId) async {
    final expenses = await remoteDataSource.fetchExpensesFromServer(userId);
    expenses.sort((a, b) => b.date.compareTo(a.date));
    return expenses;
  }

  /// Add a new expense
  Future<void> addExpense(Expense expense) async {
    await remoteDataSource.addExpense(expense);
  }

  /// Update an existing expense by id
  Future<void> updateExpense(Expense expense) async {
    await remoteDataSource.updateExpense(expense);
  }

  /// Delete an expense by id
  Future<void> deleteExpense(String id) async {
    await remoteDataSource.deleteExpense(id);
  }
}

