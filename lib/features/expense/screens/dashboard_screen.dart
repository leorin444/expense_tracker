// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../providers/expense_provider.dart';
import '../../finance/providers/finance_provider.dart';
import '../../dayend/providers/dayend_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../shared/theme/theme_provider.dart';
import '../models/expense.dart';
import 'expense_form_screen.dart';
import '../../finance/screens/finance_setup_screen.dart';
import '../screens/expense_calendar_screen.dart';
import '../../export/expense_export_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final provider = context.read<ExpenseProvider>();
      await provider.loadExpenses();
      await provider.fetchCloudExpenses(); // fetch from cloud on start
    });
  }

  @override
  Widget build(BuildContext context) {
    final expenseProvider = context.watch<ExpenseProvider>();
    final expenses = expenseProvider.expenses;
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

    final onPrimary = Theme.of(context).colorScheme.onPrimary;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Money Manager'),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: onPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ExpenseCalendarScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () {
              final expenses = context.read<ExpenseProvider>().expenses;
              ExportService.exportToCSV(expenses);
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: Text(
                DateFormat('dd/MM/yyyy').format(now),
                style: TextStyle(fontSize: 16, color: onPrimary),
              ),
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: onPrimary),
            onSelected: (value) {
              if (value == 'theme') {
                context.read<ThemeProvider>().toggleTheme();
              } else if (value == 'logout') {
                context.read<AuthProvider>().logout();
              }
            },
            itemBuilder: (_) {
              final isDark =
                  context.read<ThemeProvider>().themeMode == ThemeMode.dark;
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
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            children: [
              if (financeProfile == null) const _SetupFinanceCard(),
              const SizedBox(height: 16),
              if (financeProfile != null) ...[
                Row(
                  children: [
                    Expanded(
                      child: _infoCard(
                        title: 'Total Expenses',
                        value: totalAmount,
                        limit: financeProfile.spendableAmount,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _infoCard(
                        title: 'This Month',
                        value: monthlyTotal,
                        limit: financeProfile.spendableAmount,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                if (monthlyTotal > financeProfile.spendableAmount * 0.9)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.warning, color: Colors.red),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "Warning: You are close to exceeding your monthly budget",
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 16),

                _sectionCard(
                  title: "Category Spending",
                  child: SizedBox(
                    height: 200,
                    child: PieChart(
                      PieChartData(
                        sections: expenseProvider.getCategoryTotals().entries.map((
                          entry,
                        ) {
                          final index = expenseProvider
                              .getCategoryTotals()
                              .keys
                              .toList()
                              .indexOf(entry.key);

                          final colors = [
                            Colors.blue,
                            Colors.green,
                            Colors.orange,
                            Colors.red,
                            Colors.purple,
                            Colors.teal,
                          ];

                          return PieChartSectionData(
                            color: colors[index % colors.length],
                            value: entry.value,
                            title:
                                '${entry.key}\n${entry.value.toStringAsFixed(0)}',
                            radius: 70,
                            titleStyle: const TextStyle(
                              fontSize: 12,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        }).toList(),
                        sectionsSpace: 2,
                        centerSpaceRadius: 40,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Builder(
                      builder: (context) {
                        final data = context
                            .read<ExpenseProvider>()
                            .getCategoryTotals();

                        if (data.isEmpty) {
                          return const Text("No spending insights yet");
                        }

                        final top = data.entries.reduce(
                          (a, b) => a.value > b.value ? a : b,
                        );

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Top Spending Category",
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                const Icon(Icons.trending_up),
                                const SizedBox(width: 10),
                                Text(
                                  top.key,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  "Rs ${top.value.toStringAsFixed(0)}",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 16),

              if (recentExpenses.isNotEmpty) ...[
                Text(
                  'Recent Expenses',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                ...recentExpenses.map(
                  (expense) => ExpenseCard(expense: expense),
                ),
              ] else
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text("No expenses yet"),
                  ),
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: "add_expense",
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: onPrimary,
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
          const SizedBox(height: 12),
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

  Widget _infoCard({
    required String title,
    required double value,
    required double limit,
  }) {
    final progress = (limit == 0 ? 0.0 : (value / limit).clamp(0.0, 1.0));
    Color progressColor;
    String msg;

    if (progress >= 1) {
      progressColor = Colors.red;
      msg = "Budget exceeded!";
    } else if (progress >= 0.9) {
      progressColor = Colors.orange;
      msg = "Near budget limit";
    } else {
      progressColor = Colors.green;
      msg = "Within budget";
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title),
            const SizedBox(height: 8),
            Text(
              "Rs ${value.toStringAsFixed(2)}",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: progress,
              color: progressColor,
              minHeight: 8,
              backgroundColor: Colors.grey[200],
            ),
            const SizedBox(height: 4),
            Text(msg, style: TextStyle(fontSize: 12, color: progressColor)),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _SetupFinanceCard extends StatelessWidget {
  const _SetupFinanceCard();

  @override
  Widget build(BuildContext context) {
    return Card(
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
  }
}

class ExpenseCard extends StatelessWidget {
  final Expense expense;
  const ExpenseCard({super.key, required this.expense});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<ExpenseProvider>();
    final onPrimary = Theme.of(context).colorScheme.onPrimary;

    return Dismissible(
      key: ValueKey(expense.id),
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
      onDismissed: (_) async {
        final removedExpense = expense;
        await provider.removeExpense(expense.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Expense deleted!'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () async =>
                  await provider.addExistingExpense(removedExpense),
            ),
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
        child: Icon(Icons.delete, color: onPrimary),
      ),
      child: Card(
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.grey.withValues(alpha: 0.2),
            child: const Icon(Icons.category),
          ),
          title: Text(expense.title),
          subtitle: Text(
            '${expense.category} • ${expense.date.day}/${expense.date.month}/${expense.date.year}',
          ),
          trailing: Text("Rs ${expense.amount.toStringAsFixed(2)}"),
        ),
      ),
    );
  }
}
