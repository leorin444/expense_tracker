// lib/features/expense/providers/day_end_provider.dart
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

class DayEndProvider extends ChangeNotifier {
  static const String _boxName = 'dayEndBox';
  late Box _box;
  String? _currentUserId;

  DayEndProvider() {
    _initBox();
  }

  Future<void> _initBox() async {
    _box = await Hive.openBox(_boxName);
  }

  String? get currentUserId => _currentUserId;

  void setCurrentUser(String userId) {
    _currentUserId = userId;
    notifyListeners();
  }

  bool get isClosedToday {
    if (_currentUserId == null) return false;
    return _box.get('${_currentUserId}_dayClosed', defaultValue: false);
  }

  /// Check if we can add expense today
  bool canAddExpense() => !isClosedToday;

  /// Close the day
  void closeToday() {
    if (_currentUserId == null) return;
    _box.put('${_currentUserId}_dayClosed', true);
    notifyListeners();
  }

  /// Optional: reset for a new day
  void openNewDay() {
    if (_currentUserId == null) return;
    _box.put('${_currentUserId}_dayClosed', false);
    notifyListeners();
  }
}
