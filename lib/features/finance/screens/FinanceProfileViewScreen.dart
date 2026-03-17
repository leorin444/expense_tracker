import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/finance_provider.dart';

class FinanceProfileViewScreen extends StatelessWidget {
  const FinanceProfileViewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<FinanceProvider>().profile!;

    return Scaffold(
      appBar: AppBar(title: const Text("Financial Profile")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ListTile(
              title: const Text("Monthly Income"),
              trailing: Text("Rs ${profile.monthlyIncome}"),
            ),
            ListTile(
              title: const Text("Savings Percentage"),
              trailing: Text("${profile.savingsPercentage}%"),
            ),
            ListTile(
              title: const Text("Savings Amount"),
              trailing: Text("Rs ${profile.savingsAmount.toStringAsFixed(2)}"),
            ),
            ListTile(
              title: const Text("Spendable Amount"),
              trailing: Text(
                "Rs ${profile.spendableAmount.toStringAsFixed(2)}",
              ),
            ),
          ],
        ),
      ),
    );
  }
}
