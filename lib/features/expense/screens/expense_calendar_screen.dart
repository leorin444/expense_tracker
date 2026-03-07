import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../providers/expense_provider.dart';

class ExpenseCalendarScreen extends StatefulWidget {
  const ExpenseCalendarScreen({super.key});

  @override
  State<ExpenseCalendarScreen> createState() => _ExpenseCalendarScreenState();
}

class _ExpenseCalendarScreenState extends State<ExpenseCalendarScreen> {
  DateTime selectedDay = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpenseProvider>();

    final expenses = provider.getExpensesByDate(selectedDay);

    return Scaffold(
      appBar: AppBar(title: const Text("Expense Calendar")),
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.utc(2022),
            lastDay: DateTime.utc(2030),
            focusedDay: selectedDay,
            selectedDayPredicate: (day) => isSameDay(day, selectedDay),

            onDaySelected: (day, _) {
              setState(() => selectedDay = day);
            },
          ),

          Expanded(
            child: ListView.builder(
              itemCount: expenses.length,
              itemBuilder: (_, i) {
                final e = expenses[i];

                return ListTile(
                  title: Text(e.title),
                  subtitle: Text(e.category),
                  trailing: Text("Rs ${e.amount}"),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
