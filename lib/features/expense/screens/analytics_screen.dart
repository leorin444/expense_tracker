import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/expense_provider.dart';
import '../providers/analytics_provider.dart';
import '../widgets/charts.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  int _selectedSegment = 0;

  @override
  Widget build(BuildContext context) {
    final expenses = context.watch<ExpenseProvider>().expenses;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final analytics = context.watch<AnalyticsProvider>();
    final segments = analytics.monthlySegments(expenses);

    final hasSegments = segments.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Analytics"),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            /// 🔹 WEEKLY
            _buildCard(
              context,
              title: "Weekly Spending",
              child: expenses.isEmpty
                  ? _emptyState()
                  : WeeklyBarChart(expenses: expenses, isDark: isDark),
            ),

            const SizedBox(height: 16),

            /// 🔹 MONTHLY
            _buildCard(
              context,
              title: "Monthly Spending",
              child: !hasSegments
                  ? _emptyState()
                  : Column(
                      children: [
                        Slider(
                          value: _selectedSegment
                              .clamp(0, segments.length - 1)
                              .toDouble(),
                          min: 0,
                          max: (segments.length - 1).toDouble(),
                          divisions: segments.length > 1
                              ? segments.length - 1
                              : 1,
                          label: segments[_selectedSegment]['label'],
                          onChanged: (value) {
                            setState(() => _selectedSegment = value.toInt());
                          },
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 220,
                          child: SegmentBarChart(
                            data: segments[_selectedSegment]['data'],
                            isDark: isDark,
                          ),
                        ),
                      ],
                    ),
            ),

            const SizedBox(height: 16),

            /// 🔹 CATEGORY
            _buildCard(
              context,
              title: "Category Distribution",
              child: expenses.isEmpty
                  ? _emptyState()
                  : CategoryPieChart(expenses: expenses, isDark: isDark),
            ),
          ],
        ),
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

  /// 🔹 REUSABLE CARD
  Widget _buildCard(
    BuildContext context, {
    required String title,
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
                ? Colors.black.withOpacity(0.3)
                : Colors.black.withOpacity(0.05),
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
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
