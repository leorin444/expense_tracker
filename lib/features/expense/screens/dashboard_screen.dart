import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../finance/providers/finance_provider.dart';
import '../providers/expense_provider.dart';
import '../models/expense.dart';
import '../../finance/screens/finance_setup_screen.dart';
import '../../dayend/providers/dayend_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../shared/theme/theme_provider.dart';
import 'expense_form_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final expenses = context.watch<ExpenseProvider>().expenses;
    final financeProvider = context.watch<FinanceProvider>();
    final financeProfile = financeProvider.profile;
    final dayEnd = context.watch<DayEndProvider>();

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
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Expense Tracker'),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Center(
              child: Text(
                '${now.day}/${now.month}/${now.year}',
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: Theme.of(context).colorScheme.onPrimary),
            onSelected: (value) {
              if (value == 'theme') {
                context.read<ThemeProvider>().toggleTheme();
              } else if (value == 'logout') {
                context.read<AuthProvider>().logout();
              }
            },
            itemBuilder: (BuildContext context) {
              final isDark = context.read<ThemeProvider>().themeMode == ThemeMode.dark;
              return [
                PopupMenuItem<String>(
                  value: 'theme',
                  child: Row(
                    children: [
                      Icon(isDark ? Icons.light_mode : Icons.dark_mode),
                      const SizedBox(width: 8),
                      Text(isDark ? 'Light Mode' : 'Dark Mode'),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout),
                      SizedBox(width: 8),
                      Text('Logout'),
                    ],
                  ),
                ),
              ];
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ---------------- Finance Setup Card ----------------
                if (financeProfile == null) _setupFinanceCard(context),

                const SizedBox(height: 16),

                // ---------------- Total & Monthly Cards Side by Side ----------------
                if (financeProfile != null)
                  Row(
                    children: [
                      Expanded(
                        child: _totalCard(
                          context,
                          totalAmount,
                          financeProfile.spendableAmount,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _monthlyCard(
                          context,
                          monthlyTotal,
                          financeProfile.spendableAmount,
                        ),
                      ),
                    ],
                  ),

                const SizedBox(height: 16),

                // ---------------- Recent Expenses ----------------
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

      // ---------------- Floating Buttons ----------------
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: "add_expense",
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            child: const Icon(Icons.add),
            onPressed: () {
              if (!dayEnd.canAddExpense()) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Day is closed. Cannot add expense.'),
                  ),
                );
                return;
              }
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ExpenseFormScreen()),
              );
            },
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: "day_end",
            backgroundColor: Colors.orange[600],
            child: const Icon(Icons.today),
            onPressed: () => _confirmDayEnd(context),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  // ---------------- Confirm Day End ----------------
  void _confirmDayEnd(BuildContext context) {
    final dayEnd = context.read<DayEndProvider>();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Close Today?'),
        content: const Text(
          'After closing, no more expenses can be added for today.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              dayEnd.closeToday();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Day closed successfully')),
              );
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  // ---------------- Expense Card ----------------
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
          color: Theme.of(context).colorScheme.error,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.delete, color: Theme.of(context).colorScheme.onError),
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

  // ---------------- Total Card ----------------
  Widget _totalCard(BuildContext context, double total, double spendableLimit) {
    final progress = (total / spendableLimit).clamp(0.0, 1.0);

    Color progressColor;
    String message;

    if (progress >= 1) {
      progressColor = Colors.red;
      message = 'Exceeded spendable amount!';
    } else if (progress >= 0.9) {
      progressColor = Colors.orange;
      message = 'Near spendable limit!';
    } else {
      progressColor = Colors.white;
      message = 'Within limit.';
    }

    return Card(
      color: Theme.of(context).colorScheme.primary,
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Total Expenses',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.8)),
            ),
            const SizedBox(height: 8),
            Text(
              'Rs ${total.toStringAsFixed(2)} / Rs ${spendableLimit.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 12,
                backgroundColor:
                    Theme.of(context).colorScheme.onPrimary.withOpacity(0.24),
                valueColor: AlwaysStoppedAnimation(progressColor),
              ),
            ),
            const SizedBox(height: 8),
            Text(message,
                style: TextStyle(color: Theme.of(context).colorScheme.onPrimary)),
          ],
        ),
      ),
    );
  }

  // ---------------- Monthly Card ----------------
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
          'Exceeded by Rs ${(monthlyTotal - spendableLimit).toStringAsFixed(2)}';
    } else if (monthlyTotal > 0.9 * spendableLimit) {
      cardColor = Colors.orange[400]!;
      message =
          'Near limit! Rs ${(spendableLimit - monthlyTotal).toStringAsFixed(2)} remaining.';
    } else {
      cardColor = Theme.of(context).colorScheme.primary;
      message =
          'Within limit. Rs ${(spendableLimit - monthlyTotal).toStringAsFixed(2)} remaining.';
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
              ).textTheme.titleMedium!.copyWith(color: Theme.of(context).colorScheme.onPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'Rs ${monthlyTotal.toStringAsFixed(2)} / Rs ${spendableLimit.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onPrimary),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- Finance Setup Card ----------------
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

  // ---------------- Helpers ----------------
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
