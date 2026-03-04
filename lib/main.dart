import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'features/expense/providers/expense_provider.dart';
import 'features/expense/screens/dashboard_screen.dart';
import 'features/expense/models/expense.dart';
import 'features/finance/providers/finance_provider.dart';
import 'features/discipline/providers/discipline_provider.dart';
import 'features/dayend/providers/dayend_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  Hive.registerAdapter(ExpenseAdapter());
  await Hive.openBox<Expense>('expensesBox');

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ExpenseProvider()),
        ChangeNotifierProvider(create: (_) => FinanceProvider()),
        ChangeNotifierProvider(create: (_) => DisciplineProvider()),
        ChangeNotifierProvider(create: (_) => DayEndProvider()),
      ],
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
      home: const DashboardScreen(),
    );
  }
}
