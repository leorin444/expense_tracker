import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import '../models/expense.dart';

class SyncService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Box<Expense> _expenseBox = Hive.box<Expense>('expensesBox');

  /// Upload all local expenses to Firestore
  Future<void> syncAllToCloud() async {
    try {
      for (var expense in _expenseBox.values) {
        await _firestore
            .collection('expenses')
            .doc(expense.id)
            .set(expense.toMap());
      }
    } catch (e) {
      // Error syncing to cloud
    }
  }

  /// Listen to Firestore and update local Hive box
  void listenToCloudChanges() {
    _firestore.collection('expenses').snapshots().listen((snapshot) {
      for (var docChange in snapshot.docChanges) {
        final data = docChange.doc.data();
        if (data == null) continue;

        final expense = Expense.fromMap(data);

        switch (docChange.type) {
          case DocumentChangeType.added:
          case DocumentChangeType.modified:
            _expenseBox.put(expense.id, expense);
            break;
          case DocumentChangeType.removed:
            _expenseBox.delete(expense.id);
            break;
        }
      }
    });
  }

  /// Add or update a single expense in cloud
  Future<void> syncExpense(Expense expense) async {
    try {
      await _firestore
          .collection('expenses')
          .doc(expense.id)
          .set(expense.toMap());
    } catch (e) {
      // Error syncing expense
    }
  }

  /// Delete a single expense from cloud
  Future<void> deleteExpense(String id) async {
    try {
      await _firestore.collection('expenses').doc(id).delete();
    } catch (e) {
      // Error deleting expense in cloud
    }
  }
}

// ------------------- Expense model helpers -------------------

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
