import 'package:flutter/material.dart';
import '../models/expense.dart';

class AnalyticsProvider with ChangeNotifier {
  /// Returns totals for the current week (Monday → Sunday)
  List<double> weeklyTotals(List<Expense> expenses) {
    final now = DateTime.now();

    // Monday of current week
    final startOfWeek = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));

    List<double> totals = List.filled(7, 0);

    for (final expense in expenses) {
      final expenseDate = DateTime(
        expense.date.year,
        expense.date.month,
        expense.date.day,
      );

      final difference = expenseDate.difference(startOfWeek).inDays;
      if (difference >= 0 && difference < 7) {
        totals[difference] += expense.amount;
      }
    }

    return totals;
  }

  /// Returns totals for each day of the current month
  List<double> monthlyTotals(List<Expense> expenses) {
    final now = DateTime.now();

    List<double> totals = List.filled(31, 0);

    for (final expense in expenses) {
      if (expense.date.year == now.year && expense.date.month == now.month) {
        totals[expense.date.day - 1] += expense.amount;
      }
    }

    return totals;
  }

  /// Returns totals per category
  Map<String, double> categoryTotals(List<Expense> expenses) {
    final Map<String, double> totals = {};
    for (final expense in expenses) {
      totals.update(
        expense.category,
        (v) => v + expense.amount,
        ifAbsent: () => expense.amount,
      );
    }
    return totals;
  }

  /// Returns the top spending category
  MapEntry<String, double>? topCategory(List<Expense> expenses) {
    final totals = categoryTotals(expenses);
    if (totals.isEmpty) return null;
    final top = totals.entries.reduce((a, b) => a.value > b.value ? a : b);
    return top;
  }

  /// Returns expenses for a specific day
  List<Expense> expensesByDate(List<Expense> expenses, DateTime day) {
    return expenses
        .where(
          (e) =>
              e.date.year == day.year &&
              e.date.month == day.month &&
              e.date.day == day.day,
        )
        .toList();
  }

  /// Returns a daily map of totals for heatmap
  Map<DateTime, double> dailyTotals(List<Expense> expenses) {
    final Map<DateTime, double> totals = {};
    for (var expense in expenses) {
      final day = DateTime(
        expense.date.year,
        expense.date.month,
        expense.date.day,
      );
      totals.update(
        day,
        (v) => v + expense.amount,
        ifAbsent: () => expense.amount,
      );
    }
    return totals;
  }
}
