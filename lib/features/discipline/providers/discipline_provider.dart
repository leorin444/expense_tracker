import 'package:flutter/material.dart';
import '../models/daily_status.dart';
import '../../expense/providers/expense_provider.dart';

class DisciplineProvider extends ChangeNotifier {
  final List<DailyStatus> _history = [];

  List<DailyStatus> get history => List.unmodifiable(_history);

  bool isTodayCompleted(List expenses) {
    final today = DateTime.now();
    return expenses.any(
      (e) =>
          e.date.year == today.year &&
          e.date.month == today.month &&
          e.date.day == today.day,
    );
  }

  void updateToday(List expenses) {
    final today = DateTime.now();
    final completed = isTodayCompleted(expenses);

    _history.removeWhere(
      (d) =>
          d.date.year == today.year &&
          d.date.month == today.month &&
          d.date.day == today.day,
    );

    _history.add(DailyStatus(date: today, completed: completed));

    notifyListeners();
  }

  int get missedDays {
    return _history.where((d) => !d.completed).length;
  }
}
