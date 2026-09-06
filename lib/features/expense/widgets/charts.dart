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

/// ================= SPENDING TREND LINE CHART =================
class SpendingTrendLineChart extends StatelessWidget {
  final List<Expense> expenses;
  final bool isDark;

  const SpendingTrendLineChart({
    super.key,
    required this.expenses,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final dailyData = context.read<AnalyticsProvider>().monthlyTotals(expenses);
    final theme = Theme.of(context);

    if (dailyData.isEmpty || dailyData.every((e) => e == 0)) {
      return const SizedBox(
        height: 200,
        child: Center(
          child: Text("No spending data this month", style: TextStyle(fontSize: 13)),
        ),
      );
    }

    final maxY = dailyData.reduce((a, b) => a > b ? a : b) * 1.25;
    final spots = dailyData.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble() + 1, e.value);
    }).toList();

    return SizedBox(
      height: 220,
      child: LineChart(
        LineChartData(
          minX: 1,
          maxX: dailyData.length.toDouble(),
          minY: 0,
          maxY: maxY > 0 ? maxY : 100,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: isDark ? Colors.white10 : Colors.black12, strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 42,
                getTitlesWidget: (value, meta) {
                  if (value == 0) return const SizedBox();
                  return Text(
                    value >= 1000
                        ? '${(value / 1000).toStringAsFixed(1)}k'
                        : value.toInt().toString(),
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: (dailyData.length / 6).clamp(1, 10).toDouble(),
                getTitlesWidget: (value, meta) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Day ${value.toInt()}',
                      style: TextStyle(
                        fontSize: 9.5,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.35,
              color: theme.colorScheme.primary,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) =>
                    FlDotCirclePainter(
                  radius: 3,
                  color: theme.colorScheme.primary,
                  strokeWidth: 1.5,
                  strokeColor: isDark ? Colors.black : Colors.white,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    theme.colorScheme.primary.withValues(alpha: 0.35),
                    theme.colorScheme.primary.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ],
        ),
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
        child: Center(child: Text("No expenses to show", style: TextStyle(fontSize: 13))),
      );
    }

    final colors = [
      Theme.of(context).colorScheme.primary,
      Colors.teal,
      Colors.orange,
      Colors.purple,
      Colors.pink,
      Colors.indigo,
      Colors.amber,
      Colors.cyan,
    ];

    int i = 0;
    final totalExpense = categoryTotals.values.fold(0.0, (a, b) => a + b);

    final sections = categoryTotals.entries.map((e) {
      final percentage = totalExpense > 0 ? (e.value / totalExpense * 100) : 0.0;
      final color = colors[i++ % colors.length];

      return PieChartSectionData(
        value: e.value,
        title: '${percentage.toStringAsFixed(1)}%',
        color: color,
        radius: 60,
        titleStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();

    i = 0;
    return Column(
      children: [
        SizedBox(
          height: 200,
          child: PieChart(
            PieChartData(
              sections: sections,
              sectionsSpace: 2,
              centerSpaceRadius: 36,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: categoryTotals.entries.map((e) {
            final color = colors[i++ % colors.length];
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text(
                  '${e.key} (Rs ${e.value.toStringAsFixed(0)})',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }
}
