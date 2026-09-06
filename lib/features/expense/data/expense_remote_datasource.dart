import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:expense_tracker/core/services/api_service.dart';
import 'package:expense_tracker/core/services/hive_service.dart';
import 'package:expense_tracker/core/services/sync_service.dart';
import 'package:expense_tracker/core/models/sync_action.dart';
import 'package:uuid/uuid.dart';
import '../models/expense.dart';

class ExpenseRemoteDataSource {
  final ApiService apiService;
  final _uuid = const Uuid();

  ExpenseRemoteDataSource(this.apiService);

  Future<List<Expense>> getExpensesByUser(String userId) async {
    final box = HiveService.getExpenses();
    final List<Expense> expenses = [];
    final Set<String> seenSignatures = {};
    final List<dynamic> duplicateKeysToDelete = [];
    
    for (var key in box.keys) {
      final value = box.get(key);
      if (value == null) continue;
      try {
        final map = jsonDecode(value);
        final expense = Expense.fromMap(map);
        if (expense.userId == userId) {
          // Signature based on title, amount, and date to automatically clean up any duplicates
          final signature = '${expense.title.toLowerCase().trim()}_${expense.amount.toStringAsFixed(2)}_${expense.date.year}-${expense.date.month}-${expense.date.day}';
          if (seenSignatures.contains(signature)) {
            duplicateKeysToDelete.add(key);
          } else {
            seenSignatures.add(signature);
            expenses.add(expense);
          }
        }
      } catch (_) {}
    }

    // Clean up duplicate keys from Hive
    for (var dupKey in duplicateKeysToDelete) {
      await box.delete(dupKey);
    }

    return expenses;
  }

  /// Pull latest expenses from live server and save to local Hive with deduplication
  Future<List<Expense>> fetchExpensesFromServer(String userId) async {
    try {
      // Always pass the Firebase UID so the API returns only this user's expenses
      final firebaseUid = FirebaseAuth.instance.currentUser?.uid ?? userId;
      dynamic response;
      try {
        response = await apiService.get('/expenses?firebaseUid=$firebaseUid');
      } catch (e) {
        debugPrint('Error fetching expenses from server: $e');
        // On network error, fall back to local cache
      }

      if (response != null && response is List) {
        final box = HiveService.getExpenses();
        final catBox = HiveService.getCategories();
        
        // Build category lookup map (id/name -> display name)
        final categoryMap = <String, String>{};
        for (var catVal in catBox.values) {
          try {
            final cat = jsonDecode(catVal) as Map<String, dynamic>;
            final id = cat['id']?.toString() ?? '';
            final name = cat['name']?.toString() ?? '';
            if (id.isNotEmpty && name.isNotEmpty) {
              categoryMap[id] = name;
            }
            if (name.isNotEmpty) {
              categoryMap[name.toLowerCase()] = name;
            }
          } catch (_) {}
        }

        // Load existing local expenses to match by id or attributes
        final localExpenses = <String, Expense>{};
        for (var val in box.values) {
          try {
            final e = Expense.fromMap(jsonDecode(val) as Map<String, dynamic>);
            localExpenses[e.id] = e;
          } catch (_) {}
        }

        for (var item in response) {
          if (item is! Map<String, dynamic>) continue;
          final expense = Expense.fromMap(item);
          final serverClientExpenseId = item['clientExpenseId']?.toString();

          // Resolve category display name
          String resolvedCategory = expense.category;
          if (resolvedCategory.isEmpty || resolvedCategory == 'Other') {
            final catName = item['categoryName']?.toString();
            if (catName != null && catName.isNotEmpty) {
              resolvedCategory = catName;
            } else {
              final catId = item['categoryId']?.toString();
              if (catId != null && categoryMap.containsKey(catId)) {
                resolvedCategory = categoryMap[catId]!;
              }
            }
          }

          // Match with existing local expense by ID, clientExpenseId, or attributes
          String targetId = expense.id.isNotEmpty ? expense.id : _uuid.v4();

          final duplicateLocal = localExpenses.values.cast<Expense?>().firstWhere(
            (local) =>
                local != null &&
                (local.id == targetId ||
                 (serverClientExpenseId != null && local.id == serverClientExpenseId) ||
                 (local.title.toLowerCase().trim() == expense.title.toLowerCase().trim() &&
                  (local.amount - expense.amount).abs() < 0.01 &&
                  local.date.year == expense.date.year &&
                  local.date.month == expense.date.month &&
                  local.date.day == expense.date.day)),
            orElse: () => null,
          );

          if (duplicateLocal != null) {
            // Delete the old duplicate key if it differs from the canonical targetId
            if (duplicateLocal.id != targetId) {
              await box.delete(duplicateLocal.id);
            }
            targetId = duplicateLocal.id;
          }

          final fixedExpense = Expense(
            id: targetId,
            userId: userId,
            title: expense.title,
            amount: expense.amount,
            category: resolvedCategory,
            date: expense.date,
            timestamp: expense.timestamp,
          );

          await box.put(fixedExpense.id, jsonEncode(fixedExpense.toMap()));
          localExpenses[fixedExpense.id] = fixedExpense;
        }

        return await getExpensesByUser(userId);
      }
    } catch (e) {
      debugPrint('Failed to fetch expenses from server: $e');
    }
    return getExpensesByUser(userId);
  }

  Future<void> addExpense(Expense expense) async {
    final box = HiveService.getExpenses();
    final jsonStr = jsonEncode(expense.toMap());
    await box.put(expense.id, jsonStr);

    final syncAction = SyncAction(
      id: _uuid.v4(),
      collection: 'expenses',
      action: 'CREATE',
      payload: jsonStr,
    );
    SyncService.queueAction(syncAction);
  }

  Future<void> updateExpense(Expense expense) async {
    final box = HiveService.getExpenses();
    final jsonStr = jsonEncode(expense.toMap());
    await box.put(expense.id, jsonStr);

    final syncAction = SyncAction(
      id: _uuid.v4(),
      collection: 'expenses',
      action: 'UPDATE',
      payload: jsonStr,
    );
    SyncService.queueAction(syncAction);
  }

  Future<void> deleteExpense(String id) async {
    final box = HiveService.getExpenses();
    await box.delete(id);

    final syncAction = SyncAction(
      id: _uuid.v4(),
      collection: 'expenses',
      action: 'DELETE',
      payload: jsonEncode({'id': id}),
    );
    SyncService.queueAction(syncAction);
  }
}

