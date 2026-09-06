import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/services/sync_service.dart';
import '../../../core/services/api_service.dart';
import '../../category/providers/category_provider.dart';
import '../../expense/providers/expense_provider.dart';
import '../../finance/providers/finance_provider.dart';

class SyncScreen extends StatefulWidget {
  const SyncScreen({super.key});

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  final SyncService _syncService = SyncService();
  final ApiService _apiService = ApiService();

  bool _isSyncing = false;
  bool _isCheckingServer = false;
  bool? _isServerReachable;
  String? _lastSyncMessage;
  bool _lastSyncSuccess = true;
  final List<String> _syncLogs = [];

  @override
  void initState() {
    super.initState();
    _checkServerConnectivity();
  }

  Future<void> _checkServerConnectivity() async {
    setState(() => _isCheckingServer = true);
    final reachable = await _apiService.checkHealth();
    if (mounted) {
      setState(() {
        _isServerReachable = reachable;
        _isCheckingServer = false;
      });
    }
  }

  void _addLog(String log) {
    final timestamp = DateFormat('HH:mm:ss').format(DateTime.now());
    setState(() {
      _syncLogs.insert(0, '[$timestamp] $log');
      if (_syncLogs.length > 30) {
        _syncLogs.removeLast();
      }
    });
  }

  Future<void> _performFullSync() async {
    if (_isSyncing) return;

    setState(() {
      _isSyncing = true;
      _lastSyncMessage = null;
    });

    _addLog('Starting full synchronization...');

    try {
      // 1. Push Phase
      _addLog('Pushing pending offline actions to server...');
      final result = await _syncService.syncAll();

      if (result.isSuccess) {
        _addLog('Push complete: ${result.pushedCount} action(s) synced.');
        _lastSyncSuccess = true;
        _lastSyncMessage = 'Sync successful! All offline changes saved to server.';
      } else {
        _lastSyncSuccess = false;
        _lastSyncMessage = result.errorMessage ?? 'Sync partially completed with errors.';
        _addLog('Push warning: ${result.errorMessage}');
      }

      // 2. Pull Phase (Refresh providers)
      _addLog('Pulling latest categories from server...');
      if (!mounted) return;
      final categoryProvider = context.read<CategoryProvider>();
      final expenseProvider = context.read<ExpenseProvider>();
      final financeProvider = context.read<FinanceProvider>();

      await categoryProvider.fetchCategoriesFromServer();
      if (!mounted) return;
      _addLog('Pulling latest expenses from server...');
      await expenseProvider.fetchExpensesFromServer();
      if (!mounted) return;
      _addLog('Pulling latest finance profile...');
      if (financeProvider.currentUserId != null) {
        await financeProvider.fetchFinanceFromServer(financeProvider.currentUserId!);
      }

      _addLog('Synchronization finished.');
    } catch (e) {
      _lastSyncSuccess = false;
      _lastSyncMessage = 'Unexpected sync error: $e';
      _addLog('Error: $e');
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
        _checkServerConnectivity();
      }
    }
  }

  Future<void> _pullFreshData() async {
    setState(() => _isSyncing = true);
    _addLog('Starting manual pull from live server...');

    try {
      if (!mounted) return;
      final categoryProvider = context.read<CategoryProvider>();
      final expenseProvider = context.read<ExpenseProvider>();
      final financeProvider = context.read<FinanceProvider>();

      _addLog('1/3 Pulling categories from server...');
      await categoryProvider.fetchCategoriesFromServer();
      if (!mounted) return;

      _addLog('2/3 Pulling expenses from server...');
      await expenseProvider.fetchExpensesFromServer();
      if (!mounted) return;

      _addLog('3/3 Pulling finance profile from server...');
      final uid = financeProvider.currentUserId ?? FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await financeProvider.fetchFinanceFromServer(uid);
      }
      if (!mounted) return;

      final count = expenseProvider.expenses.length;
      _addLog('Pull complete! Found and loaded $count expense(s).');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Refreshed: $count expense(s) loaded from server')),
      );
    } catch (e) {
      _addLog('Pull failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Pull failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  Future<void> _confirmClearQueue() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear Sync Queue?'),
        content: const Text(
          'This will discard all pending offline changes that have not been uploaded to the server yet. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear Queue'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _syncService.clearQueue();
      _addLog('Sync queue cleared manually.');
      setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sync queue cleared')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pendingCount = _syncService.getPendingCount();
    final breakdown = _syncService.getPendingBreakdown();
    final lastSyncTime = _syncService.getLastSyncTime();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Sync Center'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Check Connection',
            onPressed: _isCheckingServer ? null : _checkServerConnectivity,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _checkServerConnectivity();
          setState(() {});
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            /// ─── Server Status Card ───
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: _isCheckingServer
                          ? Colors.grey.withValues(alpha: 0.2)
                          : (_isServerReachable == true
                              ? Colors.green.withValues(alpha: 0.2)
                              : Colors.orange.withValues(alpha: 0.2)),
                      child: Icon(
                        _isCheckingServer
                            ? Icons.hourglass_top
                            : (_isServerReachable == true ? Icons.cloud_done : Icons.cloud_off),
                        color: _isCheckingServer
                            ? Colors.grey
                            : (_isServerReachable == true ? Colors.green : Colors.orange),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isCheckingServer
                                ? 'Checking server connection...'
                                : (_isServerReachable == true
                                    ? 'Server Online & Reachable'
                                    : 'Offline / Standalone Mode'),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'API: ${ApiService.baseUrl}',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            /// ─── Pending Changes & Metrics Card ───
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Pending Sync Queue',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: pendingCount > 0
                                ? Colors.amber.withValues(alpha: 0.2)
                                : Colors.green.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            pendingCount > 0 ? '$pendingCount Pending' : 'Up to date',
                            style: TextStyle(
                              color: pendingCount > 0 ? Colors.orange.shade800 : Colors.green.shade800,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildChip(Icons.receipt, 'Expenses: ${breakdown['expenses'] ?? 0}'),
                        _buildChip(Icons.category, 'Categories: ${breakdown['categories'] ?? 0}'),
                        _buildChip(Icons.account_balance, 'Finance: ${breakdown['finance'] ?? 0}'),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      children: [
                        const Icon(Icons.history, size: 16, color: Colors.grey),
                        const SizedBox(width: 6),
                        Text(
                          lastSyncTime != null
                              ? 'Last Synced: ${DateFormat('MMM d, y - hh:mm a').format(lastSyncTime)}'
                              : 'Last Synced: Never',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            if (_lastSyncMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _lastSyncSuccess
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _lastSyncSuccess ? Colors.green.shade300 : Colors.red.shade300,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _lastSyncSuccess ? Icons.check_circle : Icons.error,
                      color: _lastSyncSuccess ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _lastSyncMessage!,
                        style: TextStyle(
                          color: _lastSyncSuccess ? Colors.green.shade900 : Colors.red.shade900,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            /// ─── Action Buttons ───
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isSyncing ? null : _performFullSync,
                icon: _isSyncing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.sync),
                label: Text(
                  _isSyncing ? 'Syncing...' : 'Sync Now (Push & Pull)',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isSyncing ? null : _pullFreshData,
                    icon: const Icon(Icons.cloud_download_outlined),
                    label: const Text('Pull from Server'),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                if (pendingCount > 0) ...[
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: _isSyncing ? null : _confirmClearQueue,
                    icon: const Icon(Icons.delete_sweep, color: Colors.red),
                    label: const Text('Clear', style: TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 24),

            /// ─── Live Activity Logs ───
            const Text(
              'Sync Activity Log',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Container(
              height: 180,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.dividerColor.withValues(alpha: 0.3)),
              ),
              child: _syncLogs.isEmpty
                  ? const Center(
                      child: Text(
                        'No sync activity yet. Tap "Sync Now" to start.',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _syncLogs.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            _syncLogs[index],
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              color: _syncLogs[index].contains('Error') ||
                                      _syncLogs[index].contains('warning')
                                  ? Colors.red.shade700
                                  : theme.textTheme.bodyMedium?.color,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(IconData icon, String label) {
    return Chip(
      avatar: Icon(icon, size: 14),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }
}
