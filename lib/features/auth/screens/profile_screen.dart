// ignore_for_file: dead_code, dead_null_aware_expression

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// hide the Firebase AuthProvider so only your provider is visible
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import '../../expense/providers/expense_provider.dart';
import '../../export/expense_export_service.dart';
import '../providers/auth_provider.dart';
import '../../../shared/theme/theme_provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final User? user = authProvider.user; // explicitly nullable

    // provider may not have produced a user yet
    if (user == null) {
      return const Center(child: CircularProgressIndicator());
    }

    // The parent (MainScreen) already provides an AppBar and
    // title via the bottom navigation. We simply return the
    // content for the profile tab so that we don't end up with
    // two app bars/titles stacked on top of each other.
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // User Info
          ListTile(
            leading: const Icon(Icons.account_circle, size: 50),
            title: Text(user.email ?? '', style: const TextStyle(fontSize: 18)),
            subtitle: Text('UID: ${user.uid ?? ''}'),
          ),

          const SizedBox(height: 20),

          // Theme Toggle
          Card(
            child: ListTile(
              leading: const Icon(Icons.brightness_6),
              title: const Text('Theme'),
              trailing: Switch(
                value: themeProvider.themeMode == ThemeMode.dark,
                onChanged: (value) => themeProvider.toggleTheme(),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Export Expenses CSV
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
                await ExportService.exportToCSV(expenses);
              },
            ),
          ),

          const SizedBox(height: 20),

          // Logout Button
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
                  context, // ignore: use_build_context_synchronously
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
