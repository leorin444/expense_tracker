import '../models/expense.dart';

class InsightService {
  static List<String> generateInsights(
    List<Expense> expenses,
    double monthlyBudget,
  ) {
    if (expenses.isEmpty) return ["No data available"];

    final now = DateTime.now();

    final thisMonth = expenses.where(
      (e) => e.date.month == now.month && e.date.year == now.year,
    );

    final lastMonth = expenses.where(
      (e) => e.date.month == now.month - 1 && e.date.year == now.year,
    );

    double thisMonthTotal = thisMonth.fold(0, (sum, e) => sum + e.amount);

    double lastMonthTotal = lastMonth.fold(0, (sum, e) => sum + e.amount);

    List<String> insights = [];

    /// 🔹 Budget insight
    if (thisMonthTotal > monthlyBudget) {
      insights.add("⚠️ You exceeded your monthly budget");
    } else if (thisMonthTotal > monthlyBudget * 0.9) {
      insights.add("⚠️ You are close to your monthly limit");
    } else {
      insights.add("✅ You are within your budget");
    }

    /// 🔹 Month comparison
    if (lastMonthTotal > 0) {
      final change = ((thisMonthTotal - lastMonthTotal) / lastMonthTotal) * 100;

      if (change > 10) {
        insights.add("📈 Spending increased by ${change.toStringAsFixed(0)}%");
      } else if (change < -10) {
        insights.add(
          "📉 Spending decreased by ${change.abs().toStringAsFixed(0)}%",
        );
      }
    }

    /// 🔹 Top category
    final categoryMap = <String, double>{};
    for (var e in expenses) {
      categoryMap[e.category] = (categoryMap[e.category] ?? 0) + e.amount;
    }

    if (categoryMap.isNotEmpty) {
      final top = categoryMap.entries.reduce(
        (a, b) => a.value > b.value ? a : b,
      );

      insights.add("💡 Top spending: ${top.key}");
    }

    return insights;
  }
}
