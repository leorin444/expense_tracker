import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../providers/expense_provider.dart';
import '../models/expense.dart';

class HeatmapCalendarScreen extends StatefulWidget {
  const HeatmapCalendarScreen({super.key});

  @override
  State<HeatmapCalendarScreen> createState() => _HeatmapCalendarScreenState();
}

class _HeatmapCalendarScreenState extends State<HeatmapCalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  Map<DateTime, double> _dailyTotals = {};

  @override
  void initState() {
    super.initState();
    _loadDailyTotals();
  }

  void _loadDailyTotals() {
    final expenses = context.read<ExpenseProvider>().expenses;

    final Map<DateTime, double> totals = {};
    for (var expense in expenses) {
      final day = DateTime(
        expense.date.year,
        expense.date.month,
        expense.date.day,
      );
      totals.update(
        day,
        (value) => value + expense.amount,
        ifAbsent: () => expense.amount,
      );
    }

    setState(() {
      _dailyTotals = totals;
    });
  }

  Color _colorForAmount(double amount) {
    // Adjust intensity based on amount spent
    if (amount == 0) return Colors.grey[200]!;

    if (amount < 500) return Colors.green[200]!;
    if (amount < 1000) return Colors.green[400]!;
    if (amount < 2000) return Colors.green[600]!;
    return Colors.green[800]!;
  }

  List<Expense> _getExpensesForDay(DateTime day) {
    final expenses = context.read<ExpenseProvider>().expenses;
    return expenses
        .where(
          (e) =>
              e.date.year == day.year &&
              e.date.month == day.month &&
              e.date.day == day.day,
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    // this widget is shown inside MainScreen; avoid its own Scaffold so the
    // parent handles the AppBar and overall page structure.
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.utc(2023, 1, 1),
            lastDay: DateTime.utc(2100, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            calendarBuilders: CalendarBuilders(
              defaultBuilder: (context, day, _) {
                final amount =
                    _dailyTotals[DateTime(day.year, day.month, day.day)] ?? 0;
                return Container(
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: _colorForAmount(amount),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${day.day}',
                    style: TextStyle(
                      color: amount > 0 ? Colors.white : Colors.black54,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              },
              todayBuilder: (context, day, _) {
                final amount =
                    _dailyTotals[DateTime(day.year, day.month, day.day)] ?? 0;
                return Container(
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: _colorForAmount(amount),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${day.day}',
                    style: TextStyle(
                      color: amount > 0 ? Colors.white : Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          if (_selectedDay != null)
            Expanded(
              child: Consumer<ExpenseProvider>(
                builder: (context, provider, _) {
                  final expenses = _getExpensesForDay(_selectedDay!);
                  if (expenses.isEmpty) {
                    return const Center(
                      child: Text("No expenses for this day"),
                    );
                  }
                  return ListView.builder(
                    itemCount: expenses.length,
                    itemBuilder: (_, index) {
                      final e = expenses[index];
                      return Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 3,
                        child: ListTile(
                          title: Text(e.title),
                          subtitle: Text(
                            '${e.category} • Rs ${e.amount.toStringAsFixed(2)}',
                          ),
                          trailing: Text(
                            '${e.date.hour.toString().padLeft(2, '0')}:${e.date.minute.toString().padLeft(2, '0')}',
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
