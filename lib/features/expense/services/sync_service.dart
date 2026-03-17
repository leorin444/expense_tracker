import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import '../models/expense.dart';

class SyncService {
  FirebaseFirestore? _firestore;
  FirebaseFirestore get firestore => _firestore ??= FirebaseFirestore.instance;
  Box<Expense> get _expenseBox => Hive.box<Expense>('expensesBox');
  Future<void> uploadExpense(Expense expense) async {
    try {
      await firestore
          .collection('users')
          .doc(expense.userId)
          .collection('expenses')
          .doc(expense.id)
          .set(expense.toMap());
      _expenseBox.put(expense.id, expense);
    } catch (e) {
      debugPrint('Error uploading expense: $e');
    }
  }

  Future<List<Expense>> fetchExpenses({required String userId}) async {
    try {
      final snapshot = await firestore
          .collection('users')
          .doc(userId)
          .collection('expenses')
          .get();
      final expenses = snapshot.docs
          .map((doc) => Expense.fromMap(doc.data()))
          .toList();
      for (var exp in expenses) {
        _expenseBox.put(exp.id, exp);
      }
      return expenses;
    } catch (e) {
      debugPrint('Error fetching expenses: $e');
      return [];
    }
  }

  Future<void> deleteExpense({
    required String userId,
    required String expenseId,
  }) async {
    try {
      await firestore
          .collection('users')
          .doc(userId)
          .collection('expenses')
          .doc(expenseId)
          .delete();
      _expenseBox.delete(expenseId);
    } catch (e) {
      debugPrint('Error deleting expense: $e');
    }
  }

  Future<void> syncExpenses({required String userId}) async {
    try {
      final localExpenses = _expenseBox.values.where((e) => e.userId == userId);
      for (var exp in localExpenses) {
        await uploadExpense(exp);
      }
      await fetchExpenses(userId: userId);
    } catch (e) {
      debugPrint('Error syncing expenses: $e');
    }
  }
}
