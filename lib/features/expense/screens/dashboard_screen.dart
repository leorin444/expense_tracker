// ignore_for_file: use_build_context_synchronously

import 'package:expense_tracker/features/finance/models/finance_profile.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';

import '../providers/expense_provider.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;

import '../../finance/providers/finance_provider.dart';
import '../../dayend/providers/dayend_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/expense.dart';
import 'expense_form_screen.dart';
import '../../finance/screens/finance_setup_screen.dart';
import '../services/insight_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String getFirstName() {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return "User";

    if (user.displayName != null && user.displayName!.isNotEmpty) {
      return user.displayName!.split(" ").first;
    }

    if (user.email != null) {
      final name = user.email!.split('@').first;
      return name[0].toUpperCase() + name.substring(1);
    }

    return "User";
  }

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
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.read<AuthProvider>();
    final dayEnd = context.read<DayEndProvider>();
    if (auth.user != null && dayEnd.currentUserId != auth.user!.uid) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        dayEnd.setCurrentUser(auth.user!.uid);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final expenseProvider = context.watch<ExpenseProvider>();
    final expenses = expenseProvider.expenses;
    final financeProvider = context.watch<FinanceProvider>();
    if (financeProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final financeProfile = financeProvider.profile;
    final dayEnd = context.watch<DayEndProvider>();
    final firstName = getFirstName();
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
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            children: [
              _buildUserHeader(firstName),
              if (financeProfile == null) const _SetupFinanceCard(),
              const SizedBox(height: 16),
              if (financeProfile != null) ...[
                _buildBudgetCards(totalAmount, monthlyTotal, financeProfile),
                const SizedBox(height: 16),
                _buildCategoryChart(expenseProvider),
                const SizedBox(height: 16),
                _buildTopCategoryCard(
                  expenseProvider,
                  expenses,
                  financeProfile,
                ),
              ],
              const SizedBox(height: 16),
              if (recentExpenses.isNotEmpty)
                _buildRecentExpensesSection(recentExpenses, expenseProvider)
              else
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      children: const [
                        Icon(Icons.receipt_long, size: 40, color: Colors.grey),
                        SizedBox(height: 10),
                        Text("No expenses yet"),
                      ],
                    ),
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
            heroTag: "reset_finance",
            backgroundColor: Colors.orange[600],
            child: const Icon(Icons.refresh),
            onPressed: () => _confirmResetFinance(context, financeProvider),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildUserHeader(String firstName) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: Theme.of(context).colorScheme.primary,
            child: Text(
              firstName[0],
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Welcome", style: Theme.of(context).textTheme.bodySmall),
              Text(
                firstName,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetCards(
    double totalAmount,
    double monthlyTotal,
    FinanceProfile profile,
  ) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _infoCard(
                title: 'Total Expenses',
                value: totalAmount,
                limit: context.read<FinanceProvider>().spendableAmount,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _infoCard(
                title: 'This Month',
                value: monthlyTotal,
                limit: context.read<FinanceProvider>().spendableAmount,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (monthlyTotal >
            context.read<FinanceProvider>().spendableAmount * 0.9)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
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
      ],
    );
  }

  Widget _buildInsightsCard(List<Expense> expenses, FinanceProfile profile) {
    final insights = InsightService.generateInsights(
      expenses,
      context.read<FinanceProvider>().spendableAmount,
    );
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                const Text(
                  "Smart Insights",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 12),

            ...insights.map(
              (i) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.circle, size: 6),
                    const SizedBox(width: 8),
                    Expanded(child: Text(i)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChart(ExpenseProvider provider) {
    return _sectionCard(
      title: "Category Spending",
      child: SizedBox(
        height: 200,
        child: PieChart(
          PieChartData(
            sections: provider.getCategoryTotals().entries.map((entry) {
              final index = provider.getCategoryTotals().keys.toList().indexOf(
                entry.key,
              );
              final colors = [
                Theme.of(context).colorScheme.primary,
                Colors.green,
                Colors.orange,
                Colors.red,
                Colors.purple,
                Colors.teal,
              ];
              return PieChartSectionData(
                color: colors[index % colors.length],
                value: entry.value,
                title: '${entry.key}\n${entry.value.toStringAsFixed(0)}',
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
    );
  }

  Widget _buildTopCategoryCard(
    ExpenseProvider provider,
    List<Expense> expenses,
    FinanceProfile? financeProfile,
  ) {
    final data = provider.getCategoryTotals();
    if (data.isEmpty) return const SizedBox();

    final top = data.entries.reduce((a, b) => a.value > b.value ? a : b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Top Spending Category",
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),

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
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),

            const SizedBox(height: 16),

            /// ✅ Insights moved here safely
            if (financeProfile != null)
              _buildInsightsCard(expenses, financeProfile),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentExpensesSection(
    List<Expense> expenses,
    ExpenseProvider provider,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Recent Expenses', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        ...expenses.map(
          (expense) => ExpenseCard(expense: expense, provider: provider),
        ),
      ],
    );
  }

  void _confirmResetFinance(BuildContext context, FinanceProvider provider) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reset Financial Setup?'),
        content: const Text(
          'Are you sure you want to reset your financial setup?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await provider.resetFinance();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Financial setup reset successfully'),
                ),
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
    IconData icon;
    String msg;

    if (progress >= 1) {
      progressColor = Colors.red;
      icon = Icons.error;
      msg = "Budget exceeded!";
    } else if (progress >= 0.9) {
      progressColor = Colors.orange;
      icon = Icons.warning;
      msg = "Near limit";
    } else {
      progressColor = Colors.green;
      icon = Icons.check_circle;
      msg = "Safe";
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title),
            const SizedBox(height: 8),

            /// 💰 Amount
            Text(
              "Rs ${value.toStringAsFixed(2)}",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 6),

            /// 📊 Progress Bar
            LinearProgressIndicator(
              value: progress,
              color: progressColor,
              minHeight: 8,
              backgroundColor: Colors.grey[300],
            ),

            const SizedBox(height: 6),

            /// ⚠️ Status Row
            Row(
              children: [
                Icon(icon, color: progressColor, size: 16),
                const SizedBox(width: 6),
                Text(msg, style: TextStyle(fontSize: 12, color: progressColor)),
              ],
            ),
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
  final ExpenseProvider provider;

  const ExpenseCard({super.key, required this.expense, required this.provider});

  @override
  Widget build(BuildContext context) {
    final messenger = ScaffoldMessenger.of(context);
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

        messenger.clearSnackBars();
        messenger.showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 3),
            content: const Text('Expense deleted!'),
            dismissDirection: DismissDirection.horizontal,
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () async {
                await provider.addExistingExpense(removedExpense);
              },
            ),
          ),
        );

        Future.delayed(const Duration(seconds: 3), () {
          messenger.hideCurrentSnackBar();
        });
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
          onTap: () async {
            // Navigate to expense form for edit/view
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ExpenseFormScreen(expense: expense),
              ),
            );
          },
          leading: CircleAvatar(
            backgroundColor: Colors.grey.withOpacity(0.2),
            child: const Icon(Icons.category),
          ),
          title: Text(expense.title),
          subtitle: Text("Rs ${expense.amount.toStringAsFixed(2)}"),
        ),
      ),
    );
  }
}
