import 'package:flutter/material.dart';
import '../models/finance_profile.dart';

class FinanceProvider with ChangeNotifier {
  FinanceProfile? _profile;

  FinanceProfile? get profile => _profile;

  bool get isConfigured => _profile != null;

  void setupFinance({
    required double income,
    required double savingsPercent,
  }) {
    _profile = FinanceProfile(
      monthlyIncome: income,
      savingsPercentage: savingsPercent,
    );
    notifyListeners();
  }
}
