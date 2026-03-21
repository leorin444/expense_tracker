import 'package:flutter/material.dart';
import '../models/expense.dart';

class AnalyticsProvider with ChangeNotifier {
  /// 🔹 Returns totals for the current week (Monday → Sunday)
  List<double> weeklyTotals(List<Expense> expenses) {
    final now = DateTime.now();

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

  /// 🔹 Returns totals for each day of the current month (DYNAMIC FIX)
  List<double> monthlyTotals(List<Expense> expenses) {
    final now = DateTime.now();

    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    List<double> totals = List.filled(daysInMonth, 0);

    for (final expense in expenses) {
      if (expense.date.year == now.year && expense.date.month == now.month) {
        totals[expense.date.day - 1] += expense.amount;
      }
    }

    return totals;
  }

  /// 🔹 NEW: 10-day segmented data for slider
  List<Map<String, dynamic>> monthlySegments(List<Expense> expenses) {
    final dailyTotals = monthlyTotals(expenses);

    return [
      {"label": "1-10", "data": _safeSublist(dailyTotals, 0, 10)},
      {"label": "11-20", "data": _safeSublist(dailyTotals, 10, 20)},
      {
        "label": "21-31",
        "data": _safeSublist(dailyTotals, 20, dailyTotals.length),
      },
    ];
  }

  /// 🔹 Safe sublist to prevent crashes
  List<double> _safeSublist(List<double> list, int start, int end) {
    if (start >= list.length) return [];
    if (end > list.length) end = list.length;
    return list.sublist(start, end);
  }

  /// 🔹 Returns totals per category
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

  /// 🔹 Returns the top spending category
  MapEntry<String, double>? topCategory(List<Expense> expenses) {
    final totals = categoryTotals(expenses);
    if (totals.isEmpty) return null;

    return totals.entries.reduce((a, b) => a.value > b.value ? a : b);
  }

  /// 🔹 Returns expenses for a specific day
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

  /// 🔹 Returns a daily map of totals for heatmap
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

  /// 🔹 Utility: get max value safely (used in charts)
  double maxValue(List<double> data) {
    if (data.isEmpty) return 0;
    return data.reduce((a, b) => a > b ? a : b);
  }

  List<String> generateInsights(List<Expense> expenses) {
    final insights = <String>[];

    final totals = categoryTotals(expenses);

    if (totals.isEmpty) return ["No data yet"];

    final top = totals.entries.reduce((a, b) => a.value > b.value ? a : b);

    insights.add("Top spending category: ${top.key}");

    final total = totals.values.fold(0.0, (a, b) => a + b);

    if (top.value > total * 0.5) {
      insights.add("Warning: More than 50% spent on ${top.key}");
    }

    if (expenses.length > 20) {
      insights.add("High transaction frequency this month");
    }

    return insights;
  }
}
