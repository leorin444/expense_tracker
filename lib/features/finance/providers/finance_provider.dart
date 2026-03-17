import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/finance_profile.dart';

class FinanceProvider with ChangeNotifier {
  static const String _boxName = 'financeProfilesBox';

  FinanceProfile? _profile;
  String? _currentUserId;

  bool _isLoading = true;

  FinanceProfile? get profile => _profile;
  String? get currentUserId => _currentUserId;
  bool get isConfigured => _profile != null;
  bool get isLoading => _isLoading;

  late Box<FinanceProfile> _box;

  FinanceProvider() {
    _init();
  }

  Future<void> _init() async {
    _box = Hive.box<FinanceProfile>(_boxName);

    FirebaseAuth.instance.authStateChanges().listen((user) {
      _handleUserChange(user?.uid);
    });
  }

  Future<void> _handleUserChange(String? uid) async {
    _isLoading = true;
    notifyListeners();

    _currentUserId = uid;

    if (uid == null) {
      _profile = null;
    } else {
      final key = 'profile_$uid';

      // migration for old versions
      if (_box.containsKey('profile') && !_box.containsKey(key)) {
        final legacy = _box.get('profile');
        if (legacy != null) {
          await _box.put(key, legacy);
        }
        await _box.delete('profile');
      }

      _profile = _box.get(key);
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> setupFinance({
    required double income,
    required double savingsPercent,
  }) async {
    if (_currentUserId == null) return;

    final profile = FinanceProfile(
      userId: _currentUserId!,
      monthlyIncome: income,
      savingsPercentage: savingsPercent,
    );

    final key = 'profile_$_currentUserId';

    await _box.put(key, profile);

    _profile = profile;

    notifyListeners();
  }

  Future<void> resetFinance() async {
    if (_currentUserId == null) return;

    final key = 'profile_$_currentUserId';

    await _box.delete(key);

    _profile = null;

    notifyListeners();
  }
}
