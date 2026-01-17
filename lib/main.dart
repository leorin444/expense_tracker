import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'features/expense/providers/expense_provider.dart';
import 'features/expense/screens/dashboard_screen.dart';
import 'features/expense/screens/expense_list_screen.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => ExpenseProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Expense Tracker',
      theme: ThemeData(primarySwatch: Colors.teal),
      home:  DashboardScreen(),
    );
  }
}