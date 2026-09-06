import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/finance_provider.dart';

class FinanceProfileViewScreen extends StatelessWidget {
  const FinanceProfileViewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceProvider>();

    final profile = finance.profile;

    if (profile == null) {
      return const Scaffold(
        body: Center(child: Text("No financial profile found")),
      );
    }

    final extraIncome = finance.extraIncomeSources;

    return Scaffold(
      appBar: AppBar(title: const Text("Financial Profile")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            /// ================= BASE INFO =================
            ListTile(
              title: const Text("Monthly Income"),
              trailing: Text("Rs ${finance.baseIncome}"),
            ),
            ListTile(
              title: const Text("Savings Percentage"),
              trailing: Text("${profile.savingsPercentage}%"),
            ),
            ListTile(
              title: const Text("Savings Amount"),
              trailing: Text("Rs ${finance.savingsAmount.toStringAsFixed(2)}"),
            ),
            ListTile(
              title: const Text("Spendable Amount"),
              trailing: Text(
                "Rs ${finance.spendableAmount.toStringAsFixed(2)}",
              ),
            ),

            const Divider(height: 30),

            /// ================= TOTALS =================
            ListTile(
              title: const Text("Extra Income Total"),
              trailing: Text(
                "Rs ${finance.extraIncomeTotal.toStringAsFixed(2)}",
              ),
            ),
            ListTile(
              title: const Text("Total Income"),
              trailing: Text("Rs ${finance.totalIncome.toStringAsFixed(2)}"),
            ),

            const SizedBox(height: 20),

            /// ================= EXTRA INCOME LIST =================
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Extra Income Sources",
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 10),

            if (extraIncome.isEmpty)
              const Text("No extra income added yet.")
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: extraIncome.length,
                itemBuilder: (context, index) {
                  final item = extraIncome[index];

                  return Card(
                    child: ListTile(
                      title: Text(item['source'] ?? ''),
                      subtitle: Text(
                        item['date'] != null
                            ? DateTime.parse(item['date']).toString()
                            : '',
                      ),
                      trailing: Text(
                        "Rs ${item['amount']}",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
