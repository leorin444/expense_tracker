import 'package:flutter/material.dart';
import 'shared/theme/app_theme.dart';
import 'features/expense/screens/expense_list_screen.dart';
import 'features/expense/screens/add_expense_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Expense Tracker',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: '/',
      routes: {
        '/': (context) => ExpenseListScreen(),
        '/add-expense': (context) => AddExpenseScreen(),
      },
    );
  }
}
