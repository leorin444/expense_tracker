import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';

import '../models/expense.dart';
import '../providers/analytics_provider.dart';
import '../providers/expense_provider.dart';

/// ================= WEEKLY BAR CHART =================
class WeeklyBarChart extends StatelessWidget {
  final List<Expense> expenses;
  final bool isDark;

  const WeeklyBarChart({
    super.key,
    required this.expenses,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final data = context.read<AnalyticsProvider>().weeklyTotals(expenses);
    final theme = Theme.of(context);

    final maxY = (data.isEmpty || data.every((e) => e == 0))
        ? 100.0
        : (data.reduce((a, b) => a > b ? a : b) * 1.2);

    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY,
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            show: true,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: isDark ? Colors.white10 : Colors.black12),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                getTitlesWidget: (value, meta) => Text(
                  value.toInt().toString(),
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                  return Text(
                    days[value.toInt()],
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  );
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
                  width: 14,
                  borderRadius: BorderRadius.circular(6),
                  color: theme.colorScheme.primary,
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

/// ================= MONTHLY SEGMENT BAR =================
class SegmentBarChart extends StatelessWidget {
  final List<double> data;
  final bool isDark;

  const SegmentBarChart({super.key, required this.data, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final maxY = (data.isEmpty || data.every((e) => e == 0))
        ? 100.0
        : (data.reduce((a, b) => a > b ? a : b) * 1.2);

    return BarChart(
      BarChartData(
        maxY: maxY,
        alignment: BarChartAlignment.spaceAround,
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          show: true,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: isDark ? Colors.white10 : Colors.black12),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, _) => Text(
                value.toInt().toString(),
                style: TextStyle(
                  fontSize: 10,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, _) => Text(
                "${value.toInt() + 1}",
                style: TextStyle(
                  fontSize: 10,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ),
          ),
        ),
        barGroups: data.asMap().entries.map((e) {
          return BarChartGroupData(
            x: e.key,
            barRods: [
              BarChartRodData(
                toY: e.value,
                width: 10,
                borderRadius: BorderRadius.circular(4),
                color: theme.colorScheme.primary,
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

/// ================= CATEGORY PIE =================
class CategoryPieChart extends StatelessWidget {
  final List<Expense> expenses;
  final bool isDark;

  const CategoryPieChart({
    super.key,
    required this.expenses,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final categoryTotals = context.read<ExpenseProvider>().getCategoryTotals();

    if (categoryTotals.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text("No expenses to show")),
      );
    }

    final colors = [
      Theme.of(context).colorScheme.primary,
      Colors.green,
      Colors.orange,
      Colors.red,
      Colors.purple,
      Colors.teal,
    ];

    int i = 0;

    final sections = categoryTotals.entries.map((e) {
      return PieChartSectionData(
        value: e.value,
        title: "${e.key}\n${e.value.toStringAsFixed(0)}",
        color: colors[i++ % colors.length],
        radius: 55,
        titleStyle: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white : Colors.white, // always visible
        ),
      );
    }).toList();

    return SizedBox(
      height: 250,
      child: PieChart(
        PieChartData(
          sections: sections,
          sectionsSpace: 2,
          centerSpaceRadius: 30,
        ),
      ),
    );
  }
}
