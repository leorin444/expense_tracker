import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

/// ---------------- Pie Chart Widget ----------------
class ExpensePieChart extends StatelessWidget {
  final List<PieChartSectionData> sections;
  final double height;

  const ExpensePieChart({super.key, required this.sections, this.height = 200});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: PieChart(
        PieChartData(
          sections: sections,
          sectionsSpace: 2,
          centerSpaceRadius: 40,
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }
}

/// ---------------- Weekly Bar Chart ----------------
class WeeklyBarChart extends StatelessWidget {
  final List<double> weeklyTotals;
  final Color barColor;
  final double maxY;

  const WeeklyBarChart({
    super.key,
    required this.weeklyTotals,
    this.barColor = Colors.blueAccent,
    this.maxY = 1000,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY,
          barGroups: List.generate(weeklyTotals.length, (i) {
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: weeklyTotals[i],
                  color: barColor,
                  width: 14,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            );
          }),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toInt().toString(),
                    style: const TextStyle(fontSize: 10),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                  return Text(
                    days[value.toInt() % 7],
                    style: const TextStyle(fontSize: 12),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }
}

/// ---------------- Monthly Bar Chart ----------------
class MonthlyBarChart extends StatelessWidget {
  final List<double> monthlyTotals;
  final Color barColor;
  final double maxY;

  const MonthlyBarChart({
    super.key,
    required this.monthlyTotals,
    this.barColor = Colors.green,
    this.maxY = 1000,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY,
          barGroups: List.generate(monthlyTotals.length, (i) {
            return BarChartGroupData(
              x: i + 1,
              barRods: [
                BarChartRodData(
                  toY: monthlyTotals[i],
                  color: barColor,
                  width: 6,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            );
          }),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) => Text(
                  value.toInt().toString(),
                  style: const TextStyle(fontSize: 10),
                ),
              ),
            ),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }
}
