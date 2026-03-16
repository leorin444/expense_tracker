import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/finance_profile.dart';

class FinanceProvider with ChangeNotifier {
  static const String _boxName = 'financeProfilesBox';
  FinanceProfile? _profile;
  String? _currentUserId;
  String? get currentUserId => _currentUserId;
  FinanceProvider() {
    // listen to auth state so we can keep profiles per-user
    FirebaseAuth.instance.authStateChanges().listen((user) {
      _handleUserChange(user?.uid);
    });
  }

  Future<void> _handleUserChange(String? uid) async {
    _currentUserId = uid;
    if (_currentUserId == null) {
      // logged out, clear profile in memory
      _profile = null;
    } else {
      final box = await Hive.openBox<FinanceProfile>(_boxName);
      // migrate any legacy non-user-specific profile if present
      if (box.containsKey('profile') &&
          !box.containsKey('profile_$_currentUserId')) {
        final legacy = box.get('profile');
        if (legacy != null) {
          await box.put('profile_$_currentUserId', legacy);
        }
        // remove the old global entry so it doesn't get used again
        await box.delete('profile');
      }

      _profile = box.get('profile_$_currentUserId');
    }
    notifyListeners();
  }

  FinanceProfile? get profile => _profile;

  bool get isConfigured => _profile != null;

  Future<void> setupFinance({
    required double income,
    required double savingsPercent,
  }) async {
    if (_currentUserId == null) return;
    _profile = FinanceProfile(
      monthlyIncome: income,
      savingsPercentage: savingsPercent,
    );
    final box = await Hive.openBox<FinanceProfile>(_boxName);
    await box.put('profile_$_currentUserId', _profile!);
    notifyListeners();
  }

  void resetFinance() {
    if (_currentUserId == null) return;
    _profile = null;
    Hive.openBox<FinanceProfile>(
      _boxName,
    ).then((box) => box.delete('profile_$_currentUserId'));
    notifyListeners();
  }
}
