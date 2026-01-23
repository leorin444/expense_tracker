import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../finance/providers/finance_provider.dart';
import '../providers/expense_provider.dart';
import '../models/expense.dart';
import '../../finance/screens/finance_setup_screen.dart';
import 'expense_form_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final expenses = context.watch<ExpenseProvider>().expenses;
    final financeProvider = context.watch<FinanceProvider>();
    final financeProfile = financeProvider.profile;

    final totalAmount = expenses.fold<double>(0, (sum, e) => sum + e.amount);

    final now = DateTime.now();
    final monthlyExpenses = expenses
        .where((e) => e.date.year == now.year && e.date.month == now.month)
        .toList();

    final monthlyTotal = monthlyExpenses.fold<double>(
      0,
      (sum, e) => sum + e.amount,
    );

    final recentExpenses = expenses.take(5).toList();

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Expense Tracker'),
        centerTitle: true,
        backgroundColor: Colors.teal[600],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ------------------ Finance Card ------------------
                if (financeProfile == null)
                  _setupFinanceCard(context)
                else
                  _financeCard(financeProfile),

                const SizedBox(height: 16),

                if (financeProfile != null)
                  _totalCard(
                    context,
                    totalAmount,
                    financeProfile.spendableAmount,
                  ),
                const SizedBox(height: 16),

                if (financeProfile != null)
                  _monthlyCard(
                    context,
                    monthlyTotal,
                    financeProfile.spendableAmount,
                  ),
                const SizedBox(height: 16),

                if (recentExpenses.isNotEmpty) ...[
                  Text(
                    'Recent Expenses',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  ...recentExpenses.map((e) => _expenseCard(context, e)),
                ],
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.teal[600],
        child: const Icon(Icons.add),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ExpenseFormScreen()),
        ),
      ),
    );
  }

  // ------------------ Expense Card ------------------
  Widget _expenseCard(BuildContext context, Expense e) {
    final provider = context.read<ExpenseProvider>();

    return Dismissible(
      key: ValueKey(e.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Delete expense?'),
            content: const Text('This action cannot be undone.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) {
        provider.removeExpense(e.id);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Expense deleted!')));
      },
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: _categoryColor(e.category).withOpacity(0.2),
            child: Icon(
              _categoryIcon(e.category),
              color: _categoryColor(e.category),
            ),
          ),
          title: Text(
            e.title,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text('${e.category} • ${_formatDate(e.date)}'),
          trailing: Text(
            'Rs ${e.amount.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  // ------------------ Total Card ------------------
  Widget _totalCard(BuildContext context, double total, double spendableLimit) {
    final progress = (total / spendableLimit).clamp(0.0, 1.0);

    Color progressColor;
    String message;

    if (progress >= 1) {
      progressColor = Colors.red;
      message = 'You exceeded your spendable amount!';
    } else if (progress >= 0.9) {
      progressColor = Colors.orange;
      message = 'Near your spendable limit!';
    } else {
      progressColor = Colors.white;
      message = 'You are within your limit.';
    }

    return Card(
      color: Colors.teal[600],
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Total Expenses',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            Text(
              'Rs ${total.toStringAsFixed(2)} / Rs ${spendableLimit.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 12,
                backgroundColor: Colors.white24,
                valueColor: AlwaysStoppedAnimation(progressColor),
              ),
            ),
            const SizedBox(height: 8),
            Text(message, style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }

  // ------------------ Monthly Card ------------------
  Widget _monthlyCard(
    BuildContext context,
    double monthlyTotal,
    double spendableLimit,
  ) {
    Color cardColor;
    String message;

    if (monthlyTotal > spendableLimit) {
      cardColor = Colors.red[400]!;
      message =
          'You exceeded your spendable amount by Rs ${(monthlyTotal - spendableLimit).toStringAsFixed(2)}!';
    } else if (monthlyTotal > 0.9 * spendableLimit) {
      cardColor = Colors.orange[400]!;
      message =
          'Near your spendable limit! Rs ${(spendableLimit - monthlyTotal).toStringAsFixed(2)} remaining.';
    } else {
      cardColor = Colors.teal[600]!;
      message =
          'Within your spendable amount. Rs ${(spendableLimit - monthlyTotal).toStringAsFixed(2)} remaining.';
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This Month',
              style: Theme.of(
                context,
              ).textTheme.titleMedium!.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              'Rs ${monthlyTotal.toStringAsFixed(2)} / Rs ${spendableLimit.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: const TextStyle(fontSize: 14, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _financeCard(financeProfile) => Card(
    elevation: 4,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Monthly Income: Rs ${financeProfile.monthlyIncome.toStringAsFixed(2)}',
          ),
          const SizedBox(height: 6),
          Text(
            'Savings (${financeProfile.savingsPercentage}%): Rs ${financeProfile.savingsAmount.toStringAsFixed(2)}',
          ),
          const SizedBox(height: 6),
          Text(
            'Spendable: Rs ${financeProfile.spendableAmount.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    ),
  );

  Widget _setupFinanceCard(BuildContext context) => Card(
    elevation: 4,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: ListTile(
      title: const Text('Setup your finances'),
      subtitle: const Text('Add income & savings rules to activate adviser'),
      trailing: const Icon(Icons.arrow_forward),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const FinanceSetupScreen()),
      ),
    ),
  );

  String _formatDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

  IconData _categoryIcon(String c) {
    switch (c) {
      case 'Food':
        return Icons.restaurant;
      case 'Transport':
        return Icons.directions_car;
      case 'Bills':
        return Icons.receipt;
      case 'Shopping':
        return Icons.shopping_bag;
      default:
        return Icons.category;
    }
  }

  Color _categoryColor(String c) {
    switch (c) {
      case 'Food':
        return Colors.orange;
      case 'Transport':
        return Colors.blue;
      case 'Bills':
        return Colors.red;
      case 'Shopping':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}
