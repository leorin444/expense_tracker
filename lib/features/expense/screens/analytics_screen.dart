import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/expense_provider.dart';
import '../widgets/charts.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  @override
  Widget build(BuildContext context) {
    final expenses = context.watch<ExpenseProvider>().expenses;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
            /// 1. Category Pie Chart
            _buildCard(
              context,
              title: "Category Breakdown",
              subtitle: "Expense share by category",
              child: expenses.isEmpty
                  ? _emptyState()
                  : CategoryPieChart(expenses: expenses, isDark: isDark),
            ),

            const SizedBox(height: 16),

            /// 2. Weekly Bar Chart
            _buildCard(
              context,
              title: "Weekly Spending",
              subtitle: "Spending comparison for current week",
              child: expenses.isEmpty
                  ? _emptyState()
                  : WeeklyBarChart(expenses: expenses, isDark: isDark),
            ),

            const SizedBox(height: 16),

            /// 3. Spending Trend Line Chart
            _buildCard(
              context,
              title: "Spending Trend",
              subtitle: "Trajectory across this month",
              child: expenses.isEmpty
                  ? _emptyState()
                  : SpendingTrendLineChart(expenses: expenses, isDark: isDark),
            ),
          ],
        ),
      );
  }

  /// 🔹 EMPTY STATE
  Widget _emptyState() {
    return const SizedBox(
      height: 150,
      child: Center(
        child: Text("No data available", style: TextStyle(fontSize: 14)),
      ),
    );
  }

  Widget _buildCard(
    BuildContext context, {
    required String title,
    String? subtitle,
    required Widget child,
  }) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            blurRadius: 10,
            offset: const Offset(0, 4),
            color: theme.brightness == Brightness.dark
                ? Colors.black.withValues(alpha: 0.3)
                : Colors.black.withValues(alpha: 0.05),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
