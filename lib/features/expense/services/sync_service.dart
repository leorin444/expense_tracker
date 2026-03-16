import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import 'package:flutter/foundation.dart';
import '../models/expense.dart';

class SyncService {
  FirebaseFirestore? _firestore;

  FirebaseFirestore get firestore => _firestore ??= FirebaseFirestore.instance;

  Box<Expense> get _expenseBox => Hive.box<Expense>('expensesBox');

  /// Upload single expense per user
  Future<void> uploadExpense(Expense expense) async {
    try {
      await firestore
          .collection('users')
          .doc(expense.userId)
          .collection('expenses')
          .doc(expense.id)
          .set(expense.toMap());

      _expenseBox.put(expense.id, expense); // still store locally
    } catch (e) {
      debugPrint('Error uploading expense: $e');
    }
  }

  /// Fetch all cloud expenses for a given user
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

      // Update local Hive box
      for (var exp in expenses) {
        _expenseBox.put(exp.id, exp);
      }

      return expenses;
    } catch (e) {
      debugPrint('Error fetching expenses: $e');
      return [];
    }
  }

  /// Delete expense for a user
  Future<void> deleteExpense(Expense expense) async {
    try {
      await firestore
          .collection('users')
          .doc(expense.userId)
          .collection('expenses')
          .doc(expense.id)
          .delete();

      _expenseBox.delete(expense.id);
    } catch (e) {
      debugPrint('Error deleting expense: $e');
    }
  }

  Future<void> syncExpenses({String? userId}) async {}
}
