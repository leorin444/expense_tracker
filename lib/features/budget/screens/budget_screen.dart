import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../expense/providers/expense_provider.dart';
import '../providers/budget_provider.dart';

class BudgetScreen extends StatelessWidget {
  const BudgetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final budgetProvider = context.watch<BudgetProvider>();
    final expenses = context.watch<ExpenseProvider>().expenses;

    return Scaffold(
      appBar: AppBar(title: const Text("Budgets")),
      body: ListView(
        children: budgetProvider.budgets.map((b) {
          final spent = budgetProvider.spentForCategory(b.category, expenses);
          final percent = b.limit == 0
              ? 0.0
              : (spent / b.limit).clamp(0.0, 1.0).toDouble();

          return Card(
            margin: const EdgeInsets.all(12),
            child: ListTile(
              title: Text(b.category),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(value: percent),
                  const SizedBox(height: 6),
                  Text("Rs ${spent.toStringAsFixed(0)} / ${b.limit}"),
                ],
              ),
            ),
          );
        }).toList(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showDialog(BuildContext context) {
    final categoryController = TextEditingController();
    final limitController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Set Budget"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: categoryController),
            TextField(controller: limitController),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              context.read<BudgetProvider>().setBudget(
                categoryController.text,
                double.parse(limitController.text),
              );
              Navigator.pop(context);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }
}
