// lib/features/expense/providers/day_end_provider.dart
import 'package:flutter/material.dart';

class DayEndProvider extends ChangeNotifier {
  bool _isDayClosed = false;

  bool get isClosedToday => _isDayClosed;

  /// Check if we can add expense today
  bool canAddExpense() => !_isDayClosed;

  /// Close the day
  void closeToday() {
    _isDayClosed = true;
    notifyListeners();
  }

  /// Optional: reset for a new day
  void openNewDay() {
    _isDayClosed = false;
    notifyListeners();
  }
}
