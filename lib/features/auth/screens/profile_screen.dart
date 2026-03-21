import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;

import '../../expense/providers/expense_provider.dart';
import '../../export/expense_export_service.dart';
import '../providers/auth_provider.dart';
import '../../../shared/theme/theme_provider.dart';
import '../../finance/providers/finance_provider.dart';
import '../../finance/screens/finance_setup_screen.dart';
import '../../finance/screens/FinanceProfileViewScreen.dart';
import '../../category/screens/category_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _confirmReset(BuildContext context) async {
    final financeProvider = context.read<FinanceProvider>();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Confirm Reset"),
        content: const Text(
          "Are you sure you want to reset financial settings?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Reset"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await financeProvider.resetFinance();
      _showSnackBar(context, "Finance settings reset");
    }
  }

  Widget _buildMenuCard(BuildContext context, List<Widget> children) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
      child: Column(children: children),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final User? user = authProvider.user;
    final financeProvider = context.watch<FinanceProvider>();
    final financeProfile = financeProvider.profile;

    if (user == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          /// ================= USER INFO =================
          _buildMenuCard(context, [
            ListTile(
              leading: CircleAvatar(
                radius: 26,
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: Text(
                  user.email![0].toUpperCase(),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              title: Text(user.email ?? ''),
              subtitle: const Text("Account"),
            ),
          ]),

          const SizedBox(height: 16),

          /// ================= SETTINGS =================
          _buildMenuCard(context, [
            SwitchListTile(
              secondary: const Icon(Icons.brightness_6),
              title: const Text('Dark Mode'),
              value: themeProvider.themeMode == ThemeMode.dark,
              onChanged: (_) => themeProvider.toggleTheme(),
            ),
          ]),

          const SizedBox(height: 16),

          /// ================= FINANCE =================
          _buildMenuCard(context, [
            ListTile(
              leading: const Icon(Icons.account_balance_wallet),
              title: const Text("Financial Setup"),
              subtitle: financeProfile == null
                  ? const Text("Not configured")
                  : const Text("Tap to view"),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                if (financeProfile == null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const FinanceSetupScreen(),
                    ),
                  );
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const FinanceProfileViewScreen(),
                    ),
                  );
                }
              },
            ),
          ]),

          const SizedBox(height: 16),

          /// ================= CATEGORY MANAGEMENT =================
          _buildMenuCard(context, [
            ListTile(
              leading: const Icon(Icons.category),
              title: const Text("Manage Categories"),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CategoryScreen()),
                );
              },
            ),
          ]),

          const SizedBox(height: 16),

          /// ================= DATA =================
          _buildMenuCard(context, [
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('Export Expenses'),
              onTap: () async {
                final expenses = context.read<ExpenseProvider>().expenses;

                if (expenses.isEmpty) {
                  _showSnackBar(context, 'No expenses to export');
                  return;
                }

                try {
                  await ExportService.exportToCSV(expenses);
                  _showSnackBar(context, 'Export successful');
                } catch (e) {
                  _showSnackBar(context, 'Export failed: $e');
                }
              },
            ),
          ]),

          const SizedBox(height: 16),

          /// ================= RESET =================
          _buildMenuCard(context, [
            ListTile(
              leading: const Icon(Icons.refresh, color: Colors.red),
              title: const Text(
                'Reset Finance Settings',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () => _confirmReset(context),
            ),
          ]),

          const SizedBox(height: 24),

          /// ================= LOGOUT =================
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
