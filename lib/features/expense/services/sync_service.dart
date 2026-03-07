import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import '../models/expense.dart';

class SyncService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Box<Expense> _expenseBox = Hive.box<Expense>('expensesBox');

  // ------------------------- UPLOAD SINGLE EXPENSE -------------------------
  Future<void> uploadExpense(Expense expense) async {
    try {
      await _firestore
          .collection('expenses')
          .doc(expense.id)
          .set(expense.toMap());
    } catch (e) {
      // Error uploading expense
    }
  }

  // ------------------------- FETCH EXPENSES FROM CLOUD -------------------------
  Future<void> fetchExpenses() async {
    try {
      final snapshot = await _firestore.collection('expenses').get();

      for (var doc in snapshot.docs) {
        final expense = ExpenseFirestore.fromMap(doc.data());
        _expenseBox.put(expense.id, expense);
      }
    } catch (e) {
      // Error fetching expenses
    }
  }

  // ------------------------- SYNC LOCAL EXPENSES TO CLOUD -------------------------
  Future<void> syncExpenses() async {
    try {
      for (var expense in _expenseBox.values) {
        await uploadExpense(expense);
      }
    } catch (e) {
      // Error syncing expenses
    }
  }

  // ------------------------- DELETE EXPENSE -------------------------
  Future<void> deleteExpense(String id) async {
    try {
      await _firestore.collection('expenses').doc(id).delete();
    } catch (e) {
      // Error deleting expense
    }

    // Also remove locally
    await _expenseBox.delete(id);
  }
}

// ------------------- Expense ↔ Firestore Mappings -------------------

extension ExpenseFirestore on Expense {
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'category': category,
      'date': date.toIso8601String(),
    };
  }

  static Expense fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      category: map['category'] ?? '',
      date: DateTime.parse(map['date']),
    );
  }
}
