import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'hive_service.dart';
import 'api_service.dart';
import '../models/sync_action.dart';

import 'package:firebase_auth/firebase_auth.dart';

class SyncResult {
  final bool isSuccess;
  final int pushedCount;
  final int failedCount;
  final int remainingPending;
  final String? errorMessage;
  final DateTime timestamp;

  SyncResult({
    required this.isSuccess,
    required this.pushedCount,
    required this.failedCount,
    required this.remainingPending,
    this.errorMessage,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() =>
      'SyncResult(success: $isSuccess, pushed: $pushedCount, failed: $failedCount, remaining: $remainingPending, error: $errorMessage)';
}

class SyncService {
  final ApiService _apiService = ApiService();

  static const String _lastSyncKey = 'last_sync_timestamp';

  DateTime? getLastSyncTime() {
    try {
      final box = HiveService.getAppSettings();
      final str = box.get(_lastSyncKey);
      if (str != null) {
        return DateTime.tryParse(str);
      }
    } catch (_) {}
    return null;
  }

  Future<void> setLastSyncTime(DateTime time) async {
    try {
      final box = HiveService.getAppSettings();
      await box.put(_lastSyncKey, time.toIso8601String());
    } catch (e) {
      debugPrint('Failed to save last sync time: $e');
    }
  }

  int getPendingCount() {
    try {
      return HiveService.getSyncQueue().length;
    } catch (_) {
      return 0;
    }
  }

  Map<String, int> getPendingBreakdown() {
    final Map<String, int> breakdown = {
      'expenses': 0,
      'categories': 0,
      'finance': 0,
      'other': 0,
    };

    try {
      final queueBox = HiveService.getSyncQueue();
      for (var val in queueBox.values) {
        final actionMap = jsonDecode(val) as Map<String, dynamic>;
        final collection = (actionMap['collection'] as String? ?? '').toLowerCase();

        if (collection.contains('expense')) {
          breakdown['expenses'] = (breakdown['expenses'] ?? 0) + 1;
        } else if (collection.contains('categor')) {
          breakdown['categories'] = (breakdown['categories'] ?? 0) + 1;
        } else if (collection.contains('finance')) {
          breakdown['finance'] = (breakdown['finance'] ?? 0) + 1;
        } else {
          breakdown['other'] = (breakdown['other'] ?? 0) + 1;
        }
      }
    } catch (e) {
      debugPrint('Error getting pending breakdown: $e');
    }

    return breakdown;
  }

  /// Ensure user exists in backend database prior to syncing data
  Future<bool> ensureUserSyncedToDatabase() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    try {
      final response = await _apiService.post('/auth/register', body: {
        'email': user.email ?? '',
        'password': 'AppUser_${user.uid.substring(0, 8)}',
        'firebaseUid': user.uid,
      });
      // Cache integer userId returned from register for use in payload sanitization
      if (response is Map && response['userId'] != null) {
        final dbUserId = int.tryParse(response['userId'].toString());
        if (dbUserId != null && dbUserId > 0) {
          final settingsBox = HiveService.getAppSettings();
          await settingsBox.put('db_user_id_${user.uid}', dbUserId.toString());
        }
      }
      return true;
    } on ApiException catch (e) {
      // 409 Conflict, 400 with existing email, or 500 duplicate/conflict means user is in DB
      final msg = e.message.toLowerCase();
      if (e.statusCode == 409 ||
          e.statusCode == 400 ||
          msg.contains('already') ||
          msg.contains('exists') ||
          msg.contains('registered') ||
          msg.contains('duplicate') ||
          msg.contains('unique') ||
          msg.contains('constraint')) {
        return true;
      }
      debugPrint('Pre-sync user check returned error: $e');
      return true;
    } catch (e) {
      debugPrint('Pre-sync user check exception: $e');
      return true;
    }
  }

  /// Push all queued local changes to the live API server
  Future<SyncResult> syncAll() async {
    final queueBox = HiveService.getSyncQueue();
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return SyncResult(
        isSuccess: false,
        pushedCount: 0,
        failedCount: queueBox.length,
        remainingPending: queueBox.length,
        errorMessage: 'No authenticated user found. Please login to sync.',
      );
    }

    // 1. Verify / Sync user account to database before proceeding
    final isUserSynced = await ensureUserSyncedToDatabase();
    if (!isUserSynced) {
      return SyncResult(
        isSuccess: false,
        pushedCount: 0,
        failedCount: queueBox.length,
        remainingPending: queueBox.length,
        errorMessage: 'First sync the user to the database before syncing data.',
      );
    }

    final keys = queueBox.keys.toList();
    if (keys.isEmpty) {
      await setLastSyncTime(DateTime.now());
      return SyncResult(
        isSuccess: true,
        pushedCount: 0,
        failedCount: 0,
        remainingPending: 0,
      );
    }

    final List<MapEntry<dynamic, String>> queueEntries = [];
    for (var key in keys) {
      final val = queueBox.get(key);
      if (val != null) {
        queueEntries.add(MapEntry(key, val));
      }
    }

    // Order items: Categories first, then Finance, then Expenses
    queueEntries.sort((a, b) {
      int getPriority(String jsonStr) {
        if (jsonStr.contains('"categories"')) return 0;
        if (jsonStr.contains('"finance')) return 1;
        if (jsonStr.contains('"expenses"')) return 2;
        return 3;
      }
      return getPriority(a.value).compareTo(getPriority(b.value));
    });

    // Filter out system default categories — they should NEVER be synced or modified
    final List<MapEntry<dynamic, String>> validQueueEntries = [];
    for (var entry in queueEntries) {
      try {
        final syncAction = SyncAction.fromMap(jsonDecode(entry.value));
        if (syncAction.collection.toLowerCase().contains('categor')) {
          Map<String, dynamic> payloadObj = {};
          try {
            final d = jsonDecode(syncAction.payload);
            if (d is Map<String, dynamic>) payloadObj = d;
          } catch (_) {}

          final idStr = payloadObj['id']?.toString() ?? '';
          final idNum = int.tryParse(idStr);
          final catName = (payloadObj['name']?.toString() ?? '').toLowerCase().trim();
          final isDefault = payloadObj['isDefault'] == true ||
              (idNum != null && idNum <= 8) ||
              ['food', 'transport', 'shopping', 'bills', 'entertainment', 'healthcare', 'housing & rent', 'other', 'food & dining', 'transportation', 'bills & utilities'].contains(catName);

          if (isDefault) {
            // Drop system categories from sync queue — they must never be pushed to server
            await queueBox.delete(entry.key);
            continue;
          }
        }
        validQueueEntries.add(entry);
      } catch (_) {
        validQueueEntries.add(entry);
      }
    }

    if (validQueueEntries.isEmpty) {
      await setLastSyncTime(DateTime.now());
      return SyncResult(
        isSuccess: true,
        pushedCount: 0,
        failedCount: 0,
        remainingPending: queueBox.length,
      );
    }

    int pushedCount = 0;
    int failedCount = 0;
    String? lastError;

    // 2. Try Bulk Sync API endpoint (/sync) first
    try {
      final List<Map<String, dynamic>> bulkActions = [];
      for (var entry in validQueueEntries) {
        final syncAction = SyncAction.fromMap(jsonDecode(entry.value));
        Map<String, dynamic> payloadObj = {};
        try {
          final decoded = jsonDecode(syncAction.payload);
          if (decoded is Map<String, dynamic>) {
            payloadObj = decoded;
          }
        } catch (_) {}

        final sanitized = _sanitizePayload(syncAction.collection, syncAction.action, payloadObj);

        bulkActions.add({
          'id': syncAction.id,
          'collection': syncAction.collection,
          'action': syncAction.action,
          'payload': sanitized,
          'timestamp': syncAction.timestamp,
        });
      }

      await _apiService.post('/sync', body: {'actions': bulkActions});

      // Bulk sync succeeded -> clear all queued keys
      for (var entry in validQueueEntries) {
        await queueBox.delete(entry.key);
      }
      pushedCount = validQueueEntries.length;
      await setLastSyncTime(DateTime.now());

      return SyncResult(
        isSuccess: true,
        pushedCount: pushedCount,
        failedCount: 0,
        remainingPending: queueBox.length,
      );
    } on SocketException {
      return SyncResult(
        isSuccess: false,
        pushedCount: 0,
        failedCount: queueEntries.length,
        remainingPending: queueBox.length,
        errorMessage: 'Cannot connect to server. Check your internet connection.',
      );
    } on TimeoutException {
      return SyncResult(
        isSuccess: false,
        pushedCount: 0,
        failedCount: queueEntries.length,
        remainingPending: queueBox.length,
        errorMessage: 'Sync request timed out. Server took too long to respond.',
      );
    } catch (e) {
      debugPrint('Bulk sync failed ($e). Falling back to individual entity endpoints...');
    }

    // 3. Fallback to individual items if bulk sync is not available (404)
    for (var entry in validQueueEntries) {
      final actionKey = entry.key;
      final jsonString = entry.value;

      try {
        final syncAction = SyncAction.fromMap(jsonDecode(jsonString));
        Map<String, dynamic> payloadMap = {};
        try {
          final decoded = jsonDecode(syncAction.payload);
          if (decoded is Map<String, dynamic>) {
            payloadMap = decoded;
          }
        } catch (_) {}

        final sanitizedPayload = _sanitizePayload(syncAction.collection, syncAction.action, payloadMap);

        if (syncAction.action == 'CREATE') {
          await _apiService.post('/${syncAction.collection}', body: sanitizedPayload);
        } else if (syncAction.action == 'UPDATE') {
          final entityId = sanitizedPayload['id'] ?? sanitizedPayload['userId'] ?? '';
          final endpoint = entityId.toString().isNotEmpty
              ? '/${syncAction.collection}/$entityId'
              : '/${syncAction.collection}';
          await _apiService.put(endpoint, body: sanitizedPayload);
        } else if (syncAction.action == 'DELETE') {
          final entityId = sanitizedPayload['id'] ?? sanitizedPayload['userId'] ?? '';
          final endpoint = entityId.toString().isNotEmpty
              ? '/${syncAction.collection}/$entityId'
              : '/${syncAction.collection}';
          await _apiService.delete(endpoint);
        }

        // Successfully pushed -> safely remove from pending queue
        await queueBox.delete(actionKey);
        pushedCount++;
      } on ApiException catch (e) {
        // Handle deduplication: If item already exists on server (409 Conflict), mark as safely deduplicated
        final isDuplicate = e.statusCode == 409 ||
            e.message.toLowerCase().contains('already exists') ||
            e.message.toLowerCase().contains('duplicate');

        if (isDuplicate) {
          debugPrint('Item already exists on server (deduplicated) at key $actionKey');
          await queueBox.delete(actionKey);
          pushedCount++;
        } else {
          // On any other client/server error, keep the item INTACT in the queue
          debugPrint('Sync error on key $actionKey: ${e.message} (retaining item in queue)');
          lastError = e.message;
          failedCount = validQueueEntries.length - pushedCount;
          break;
        }
      } on SocketException {
        lastError = 'Cannot connect to server. Check your internet connection.';
        failedCount = validQueueEntries.length - pushedCount;
        break;
      } on TimeoutException {
        lastError = 'Sync request timed out. Server took too long to respond.';
        failedCount = validQueueEntries.length - pushedCount;
        break;
      } catch (e, stackTrace) {
        debugPrint('Sync unexpected error at key $actionKey: $e (retaining item in queue)');
        debugPrint('StackTrace: $stackTrace');
        lastError = e.toString();
        failedCount = validQueueEntries.length - pushedCount;
        break;
      }
    }

    final remaining = queueBox.length;
    final isSuccess = (remaining == 0);

    if (pushedCount > 0 || isSuccess) {
      await setLastSyncTime(DateTime.now());
    }

    return SyncResult(
      isSuccess: isSuccess,
      pushedCount: pushedCount,
      failedCount: failedCount,
      remainingPending: remaining,
      errorMessage: lastError,
    );
  }

  Map<String, dynamic> _sanitizePayload(
    String collection,
    String action,
    Map<String, dynamic> payload,
  ) {
    final clean = Map<String, dynamic>.from(payload);

    if (collection.toLowerCase().contains('categor')) {
      if (action == 'CREATE' || int.tryParse(clean['id']?.toString() ?? '') == null) {
        clean.remove('id'); // Remove string UUIDs so System.Int32 parse does not fail!
      }
      clean['name'] = clean['name'] ?? 'Category';
      clean['icon'] = clean['icon'] ?? 'category';
      clean['color'] = clean['color'] ?? '#2196F3';
      clean['timestamp'] = DateTime.now().millisecondsSinceEpoch;
      clean['isDeleted'] = false;

      // Resolve Firebase UID string → integer DB userId for category ownership
      final rawUserId = clean['userId'];
      if (rawUserId != null && int.tryParse(rawUserId.toString()) == null) {
        // It's a Firebase UID string — look up the cached integer userId
        final firebaseUid = rawUserId.toString();
        final settingsBox = HiveService.getAppSettings();
        final cachedId = settingsBox.get('db_user_id_$firebaseUid');
        final dbUserId = cachedId != null ? int.tryParse(cachedId) : null;
        if (dbUserId != null && dbUserId > 0) {
          clean['userId'] = dbUserId; // Use integer userId
        } else {
          clean.remove('userId'); // Unknown — store as NULL (global) rather than crashing
        }
      }
    } else if (collection.toLowerCase().contains('expense')) {
      if (action == 'CREATE' || int.tryParse(clean['id']?.toString() ?? '') == null) {
        clean['clientExpenseId'] = clean['id']?.toString();
        clean.remove('id'); // Remove string UUID for CREATE
      }

      // Move Firebase UID string from 'userId' to 'firebaseUid'.
      // The backend ExpenseDto.UserId is int — sending a Firebase UID string
      // causes "System.Nullable<Int32>" deserialization failure.
      final rawUserId = clean['userId'];
      if (rawUserId != null) {
        final asInt = int.tryParse(rawUserId.toString());
        if (asInt == null) {
          // It's a Firebase UID string — move it to firebaseUid
          clean['firebaseUid'] = rawUserId.toString();
          clean.remove('userId'); // Remove so backend doesn't fail parsing int
        }
        // If it parsed as int, leave userId as-is
      }

      // Resolve categoryId to a valid database ID (1-8 or custom)
      int categoryId = int.tryParse(clean['categoryId']?.toString() ?? '') ?? 0;
      final catName = (clean['category'] ?? clean['categoryName'] ?? '').toString().toLowerCase().trim();

      if (categoryId <= 0) {
        // Direct match against standard system categories
        if (catName.contains('food') || catName.contains('dining') || catName.contains('restaurant')) {
          categoryId = 1;
        } else if (catName.contains('transport') || catName.contains('car') || catName.contains('fuel') || catName.contains('petrol')) {
          categoryId = 2;
        } else if (catName.contains('shop') || catName.contains('cart')) {
          categoryId = 3;
        } else if (catName.contains('bill') || catName.contains('utilit')) {
          categoryId = 4;
        } else if (catName.contains('entertain') || catName.contains('movie')) {
          categoryId = 5;
        } else if (catName.contains('health') || catName.contains('medic') || catName.contains('doctor') || catName.contains('hospital')) {
          categoryId = 6;
        } else if (catName.contains('house') || catName.contains('rent') || catName.contains('home')) {
          categoryId = 7;
        } else if (catName.contains('other')) {
          categoryId = 8;
        } else {
          // Search in local Hive categories
          final catBox = HiveService.getCategories();
          for (var val in catBox.values) {
            try {
              final cat = jsonDecode(val) as Map<String, dynamic>;
              final parsedId = int.tryParse(cat['id']?.toString() ?? '');
              final name = (cat['name']?.toString() ?? '').toLowerCase().trim();
              if (parsedId != null && parsedId > 0 && (name == catName || catName.contains(name) || name.contains(catName))) {
                categoryId = parsedId;
                break;
              }
            } catch (_) {}
          }
        }

        if (categoryId <= 0) {
          categoryId = 1; // Fallback to Food (Id 1)
        }
      }
      clean['categoryId'] = categoryId;
      clean['note'] = clean['title'] ?? clean['note'] ?? 'Expense';
      clean['amount'] = (clean['amount'] as num?)?.toDouble() ?? 0.0;
      clean['expenseDate'] = clean['date'] ?? clean['expenseDate'] ?? DateTime.now().toIso8601String();
    }

    return clean;
  }

  static void queueAction(SyncAction action) {
    try {
      final queueBox = HiveService.getSyncQueue();
      queueBox.add(jsonEncode(action.toMap()));
    } catch (e) {
      debugPrint('Failed to queue sync action: $e');
    }
  }

  /// Clear all queued sync actions (used in testing or manual reset)
  Future<void> clearQueue() async {
    final queueBox = HiveService.getSyncQueue();
    await queueBox.clear();
  }
}

