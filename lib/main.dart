import 'package:flutter/material.dart';
import 'shared/theme/app_theme.dart';
import 'features/expense/screens/expense_list_screen.dart';

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
      home: const ExpenseListScreen(), //  THIS IS CRITICAL
    );
  }
}
