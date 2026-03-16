import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';

import '../models/expense.dart';
import '../providers/expense_provider.dart';
import '../providers/analytics_provider.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final expenses = context.watch<ExpenseProvider>().expenses;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Weekly Spending",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          _WeeklyBarChart(expenses: expenses),
          const SizedBox(height: 20),
          const Text(
            "Monthly Spending",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _MonthlyBarChart(expenses: expenses),
          const SizedBox(height: 20),
          const Text(
            "Category Distribution",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          _CategoryPieChart(expenses: expenses),
        ],
      ),
    );
  }
}

class _WeeklyBarChart extends StatelessWidget {
  final List<Expense> expenses;
  const _WeeklyBarChart({required this.expenses});

  @override
  Widget build(BuildContext context) {
    final data = context.read<AnalyticsProvider>().weeklyTotals(expenses);

    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: (data.reduce((a, b) => a > b ? a : b) * 1.2).ceilToDouble(),
          barTouchData: BarTouchData(enabled: true),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 40),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  const days = [
                    'Mon',
                    'Tue',
                    'Wed',
                    'Thu',
                    'Fri',
                    'Sat',
                    'Sun',
                  ];
                  final index = value.toInt();
                  if (index >= 0 && index < days.length) {
                    return Text(days[index]);
                  }
                  return const Text('');
                },
              ),
            ),
          ),
          barGroups: List.generate(data.length, (i) {
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: data[i],
                  width: 16,
                  borderRadius: BorderRadius.circular(4),
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            );
          }),
        ),
        duration: const Duration(milliseconds: 500), // <-- updated here
      ),
    );
  }
}

class _MonthlyBarChart extends StatelessWidget {
  final List<Expense> expenses;
  const _MonthlyBarChart({required this.expenses});

  @override
  Widget build(BuildContext context) {
    final data = context.read<AnalyticsProvider>().monthlyTotals(expenses);
    final displayData = data.take(30).toList();

    return SizedBox(
      height: 250,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: (displayData.reduce((a, b) => a > b ? a : b) * 1.2)
              .ceilToDouble(),
          barTouchData: BarTouchData(enabled: true),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 40),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 4,
                getTitlesWidget: (value, meta) {
                  final day = value.toInt() + 1;
                  if (day % 5 == 0 || day == 1) return Text(day.toString());
                  return const Text('');
                },
              ),
            ),
          ),
          barGroups: List.generate(displayData.length, (i) {
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: displayData[i],
                  width: 8,
                  borderRadius: BorderRadius.circular(2),
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ],
            );
          }),
        ),
        duration: const Duration(milliseconds: 500), // <-- updated here
      ),
    );
  }
}

class _CategoryPieChart extends StatelessWidget {
  final List<Expense> expenses;
  const _CategoryPieChart({required this.expenses});

  @override
  Widget build(BuildContext context) {
    final categoryTotals = context.read<ExpenseProvider>().getCategoryTotals();

    if (categoryTotals.isEmpty) {
      return const Center(child: Text("No expenses to show"));
    }

    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.red,
      Colors.purple,
      Colors.teal,
      Colors.brown,
    ];

    int colorIndex = 0;

    final sections = categoryTotals.entries.map((e) {
      final section = PieChartSectionData(
        value: e.value,
        title: e.key,
        color: colors[colorIndex % colors.length],
        radius: 50,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
      colorIndex++;
      return section;
    }).toList();

    return SizedBox(
      height: 250,
      child: PieChart(
        PieChartData(
          sections: sections,
          sectionsSpace: 2,
          centerSpaceRadius: 30,
        ),
        duration: const Duration(milliseconds: 600), // <-- updated here
        curve: Curves.easeInOut, // optional for smooth curve
      ),
    );
  }
}
