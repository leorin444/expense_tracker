import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;

import '../../expense/providers/expense_provider.dart';
import '../../export/expense_export_service.dart';
import '../providers/auth_provider.dart';
import '../../../shared/theme/theme_provider.dart';
import '../../finance/providers/finance_provider.dart';
import '../../finance/screens/finance_setup_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final User? user = authProvider.user;

    if (user == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          /// USER PROFILE
          Card(
            child: ListTile(
              leading: CircleAvatar(
                radius: 26,
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: Text(
                  user.email![0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              title: Text(
                user.email ?? '',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: const Text("Account"),
            ),
          ),

          const SizedBox(height: 16),

          /// THEME TOGGLE
          Card(
            child: ListTile(
              leading: const Icon(Icons.brightness_6),
              title: const Text('Theme'),
              trailing: Switch(
                value: themeProvider.themeMode == ThemeMode.dark,
                onChanged: (value) {
                  themeProvider.toggleTheme();
                },
              ),
            ),
          ),

          const SizedBox(height: 16),

          /// FINANCIAL SETUP
          Card(
            child: ListTile(
              leading: const Icon(Icons.account_balance_wallet),
              title: const Text("Financial Setup"),
              subtitle: const Text("Edit your finance configuration"),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FinanceSetupScreen()),
                );
              },
            ),
          ),

          const SizedBox(height: 16),

          /// EXPORT EXPENSES
          Card(
            child: ListTile(
              leading: const Icon(Icons.download),
              title: const Text('Export Expenses'),
              onTap: () async {
                final expenses = context.read<ExpenseProvider>().expenses;

                if (expenses.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('No expenses to export')),
                  );
                  return;
                }

                try {
                  await ExportService.exportToCSV(expenses);

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Expenses exported successfully'),
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
                }
              },
            ),
          ),

          const SizedBox(height: 16),

          /// RESET FINANCE RULES
          Card(
            child: ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text('Reset Income & Saving Rules'),
              onTap: () {
                context.read<FinanceProvider>().resetFinance();

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Finance settings reset')),
                );
              },
            ),
          ),

          const SizedBox(height: 24),

          /// LOGOUT BUTTON
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () async {
                await authProvider.logout();

                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/login',
                  (route) => false,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
