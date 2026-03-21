import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/finance_profile.dart';

class FinanceProvider with ChangeNotifier {
  static const String _boxName = 'financeProfilesBox';

  FinanceProfile? _profile;
  String? _currentUserId;

  bool _isLoading = true;

  late Box<FinanceProfile> _box;

  /// 🔥 NEW: Extra income sources
  List<Map<String, dynamic>> _extraIncomeSources = [];

  /// ================= GETTERS =================

  FinanceProfile? get profile => _profile;

  String? get currentUserId => _currentUserId;

  bool get isConfigured => _profile != null;

  bool get isLoading => _isLoading;

  List<Map<String, dynamic>> get extraIncomeSources => _extraIncomeSources;

  late Box<FinanceProfile> _profileBox;
  late Box _extraIncomeBox; // dynamic box

  /// 🔥 Financial Metrics

  double get baseIncome => _profile?.monthlyIncome ?? 0.0;

  double get extraIncomeTotal =>
      _extraIncomeSources.fold(0.0, (sum, e) => sum + (e['amount'] as double));

  /// ✅ FINAL TOTAL INCOME
  double get totalIncome => baseIncome + extraIncomeTotal;

  double get savingsAmount =>
      totalIncome * ((_profile?.savingsPercentage ?? 0) / 100);

  double get fixedExpenses => _profile?.fixedExpenses ?? 0.0;

  /// ✅ FINAL SPENDABLE (UPDATED LOGIC)
  double get spendableAmount {
    final value = totalIncome - savingsAmount - fixedExpenses;

    return value < 0 ? 0 : value; // 🔥 prevents negative
  }

  /// ================= INIT =================

  FinanceProvider() {
    _init();
  }

  get monthlyIncome => null;

  Future<void> _init() async {
    _profileBox = await Hive.openBox<FinanceProfile>(_boxName);
    _extraIncomeBox = await Hive.openBox('extraIncomeBox');

    FirebaseAuth.instance.authStateChanges().listen((user) {
      _handleUserChange(user?.uid);
    });
  }

  /// ================= USER SWITCH =================

  Future<void> _handleUserChange(String? uid) async {
    _isLoading = true;
    notifyListeners();

    _currentUserId = uid;

    if (uid == null) {
      _profile = null;
      _extraIncomeSources = [];
    } else {
      final key = 'profile_$uid';
      _profile = _profileBox.get(key);

      /// ✅ Load extra income safely
      final extraKey = 'extra_income_$uid';
      final raw = _extraIncomeBox.get(extraKey);

      if (raw != null && raw is List) {
        _extraIncomeSources = List<Map<String, dynamic>>.from(
          (raw as List).map(
            (e) => Map<String, dynamic>.from(e as Map<dynamic, dynamic>),
          ),
        );
      } else {
        _extraIncomeSources = [];
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  /// ================= SETUP =================

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

    final key = 'profile_$_currentUserId';

    await _profileBox.put(key, profile); // ✅ FIXED

    _profile = profile;

    notifyListeners();
  }

  /// ================= UPDATE =================

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

    final key = 'profile_$_currentUserId';

    await _profileBox.put(key, updated); // ✅ FIXED

    _profile = updated;

    notifyListeners();
  }

  /// ================= 🔥 ADD EXTRA INCOME =================

  void addExtraIncome({required String source, required double amount}) {
    if (_currentUserId == null) return;

    final extraKey = 'extra_income_$_currentUserId';

    final newEntry = {
      'source': source,
      'amount': amount,
      'date': DateTime.now().toIso8601String(),
    };

    _extraIncomeSources.add(newEntry);

    // persist to Hive
    _extraIncomeBox.put(extraKey, _extraIncomeSources);

    notifyListeners();
  }

  /// ================= RESET =================

  Future<void> resetFinance() async {
    if (_currentUserId == null) return;

    final key = 'profile_$_currentUserId';
    final extraKey = 'extra_income_$_currentUserId';

    await _profileBox.delete(key); // ✅ FIXED
    await _profileBox.delete(extraKey);

    _profile = null;
    _extraIncomeSources = [];

    notifyListeners();
  }
}
