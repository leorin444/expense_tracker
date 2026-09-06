import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../../../core/services/hive_service.dart';
import '../../../core/services/sync_service.dart';
import '../../../core/services/api_service.dart';
import '../../../core/models/sync_action.dart';
import '../models/finance_profile.dart';

class FinanceProvider with ChangeNotifier {
  final Uuid _uuid = const Uuid();

  FinanceProfile? _profile;
  String? _currentUserId;
  bool _isLoading = true;
  List<Map<String, dynamic>> _extraIncomeSources = [];

  FinanceProfile? get profile => _profile;
  String? get currentUserId => _currentUserId;
  bool get isConfigured => _profile != null;
  bool get isLoading => _isLoading;
  List<Map<String, dynamic>> get extraIncomeSources => _extraIncomeSources;

  double get baseIncome => _profile?.monthlyIncome ?? 0.0;
  double get extraIncomeTotal =>
      _extraIncomeSources.fold(0.0, (sum, e) => sum + ((e['amount'] as num?)?.toDouble() ?? 0.0));
  double get totalIncome => baseIncome + extraIncomeTotal;
  double get savingsAmount =>
      totalIncome * ((_profile?.savingsPercentage ?? 0) / 100);
  double get fixedExpenses => _profile?.fixedExpenses ?? 0.0;

  double get spendableAmount {
    final value = totalIncome - savingsAmount - fixedExpenses;
    return value < 0 ? 0 : value; 
  }

  double? get monthlyIncome => _profile?.monthlyIncome;

  FinanceProvider() {
    FirebaseAuth.instance.authStateChanges().listen((user) {
      _handleUserChange(user?.uid);
    });
  }

  Future<void> _handleUserChange(String? uid) async {
    _isLoading = true;
    notifyListeners();

    final previousUid = _currentUserId;
    _currentUserId = uid;

    if (uid == null) {
      // Clear this user's finance data from local Hive on logout
      if (previousUid != null) {
        try {
          final box = HiveService.getFinance();
          await box.delete('profile_$previousUid');
          await box.delete('extra_$previousUid');
        } catch (_) {}
      }
      _profile = null;
      _extraIncomeSources = [];
    } else {
      await _loadFinanceData(uid);
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _loadFinanceData(String uid) async {
    try {
      final box = HiveService.getFinance();
      
      final profileStr = box.get('profile_$uid');
      if (profileStr != null) {
        _profile = FinanceProfile.fromMap(jsonDecode(profileStr));
      } else {
        _profile = null;
      }

      final extraStr = box.get('extra_$uid');
      if (extraStr != null) {
        final List<dynamic> decoded = jsonDecode(extraStr);
        _extraIncomeSources = List<Map<String, dynamic>>.from(decoded);
      } else {
        _extraIncomeSources = [];
      }
    } catch (e) {
      debugPrint("Error loading finance data: $e");
    }
  }

  /// Pull latest finance setup from server
  Future<void> fetchFinanceFromServer(String uid) async {
    final apiService = ApiService();
    final box = HiveService.getFinance();

    // 1. Fetch Finance Profile
    try {
      dynamic response;
      try {
        response = await apiService.get('/finance/profile?userId=$uid');
      } catch (_) {
        try {
          response = await apiService.get('/finance/profile');
        } catch (_) {}
      }

      if (response != null && response is Map<String, dynamic>) {
        final profile = FinanceProfile.fromMap(response);
        await box.put('profile_$uid', jsonEncode(profile.toMap()));
        _profile = profile;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Failed to fetch finance profile from server: $e');
    }

    // 2. Fetch Extra Income Sources
    try {
      dynamic extraResponse;
      try {
        extraResponse = await apiService.get('/finance/extra-income?userId=$uid');
      } catch (_) {
        try {
          extraResponse = await apiService.get('/finance/extra-income');
        } catch (_) {}
      }

      if (extraResponse != null && extraResponse is List) {
        final List<Map<String, dynamic>> extraList = [];
        for (var item in extraResponse) {
          if (item is Map<String, dynamic>) {
            extraList.add({
              'id': item['id']?.toString() ?? _uuid.v4(),
              'source': item['source']?.toString() ?? 'Extra Income',
              'amount': (item['amount'] as num?)?.toDouble() ?? 0.0,
              'date': item['date']?.toString() ?? DateTime.now().toIso8601String(),
              'userId': uid,
            });
          }
        }
        await box.put('extra_$uid', jsonEncode(extraList));
        _extraIncomeSources = extraList;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Failed to fetch extra income from server: $e');
    }
  }

  Future<void> setupFinance({
    required double income,
    required double savingsPercent,
    double fixedExpenses = 0.0,
  }) async {
    if (_currentUserId == null) return;

    final profile = FinanceProfile(
      userId: _currentUserId!,
      monthlyIncome: income,
      savingsPercentage: savingsPercent,
      fixedExpenses: fixedExpenses,
    );

    try {
      final box = HiveService.getFinance();
      final jsonStr = jsonEncode(profile.toMap());
      await box.put('profile_$_currentUserId', jsonStr);

      final syncAction = SyncAction(
        id: _uuid.v4(),
        collection: 'finance/profile',
        action: 'CREATE',
        payload: jsonStr,
      );
      SyncService.queueAction(syncAction);

      _profile = profile;
      notifyListeners();
    } catch (e) {
      debugPrint("Error setting up finance: $e");
    }
  }

  Future<void> updateFinance({
    double? income,
    double? savingsPercent,
    double? fixedExpenses,
  }) async {
    if (_currentUserId == null || _profile == null) return;

    final updated = FinanceProfile(
      userId: _currentUserId!,
      monthlyIncome: income ?? _profile!.monthlyIncome,
      savingsPercentage: savingsPercent ?? _profile!.savingsPercentage,
      fixedExpenses: fixedExpenses ?? _profile!.fixedExpenses,
    );

    try {
      final box = HiveService.getFinance();
      final jsonStr = jsonEncode(updated.toMap());
      await box.put('profile_$_currentUserId', jsonStr);

      final syncAction = SyncAction(
        id: _uuid.v4(),
        collection: 'finance/profile',
        action: 'UPDATE',
        payload: jsonStr,
      );
      SyncService.queueAction(syncAction);

      _profile = updated;
      notifyListeners();
    } catch (e) {
      debugPrint("Error updating finance: $e");
    }
  }

  Future<void> addExtraIncome({required String source, required double amount}) async {
    if (_currentUserId == null) return;

    final newEntry = {
      'id': _uuid.v4(),
      'source': source,
      'amount': amount,
      'date': DateTime.now().toIso8601String(),
      'userId': _currentUserId,
    };

    try {
      _extraIncomeSources.add(newEntry);
      final box = HiveService.getFinance();
      await box.put('extra_$_currentUserId', jsonEncode(_extraIncomeSources));

      final syncAction = SyncAction(
        id: _uuid.v4(),
        collection: 'finance/extra-income',
        action: 'CREATE',
        payload: jsonEncode(newEntry),
      );
      SyncService.queueAction(syncAction);

      notifyListeners();
    } catch (e) {
      debugPrint("Error adding extra income: $e");
    }
  }

  Future<void> resetFinance() async {
    if (_currentUserId == null) return;

    try {
      final box = HiveService.getFinance();
      await box.delete('profile_$_currentUserId');
      await box.delete('extra_$_currentUserId');

      final syncActionProfile = SyncAction(
        id: _uuid.v4(),
        collection: 'finance/profile',
        action: 'DELETE',
        payload: jsonEncode({'userId': _currentUserId}),
      );
      SyncService.queueAction(syncActionProfile);

      final syncActionExtra = SyncAction(
        id: _uuid.v4(),
        collection: 'finance/extra-income',
        action: 'DELETE',
        payload: jsonEncode({'userId': _currentUserId}),
      );
      SyncService.queueAction(syncActionExtra);

      _profile = null;
      _extraIncomeSources = [];
      notifyListeners();
    } catch (e) {
      debugPrint("Error resetting finance: $e");
    }
  }
}
