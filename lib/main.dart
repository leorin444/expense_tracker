import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/services/api_service.dart';
import 'core/services/hive_service.dart';
import 'core/services/sync_service.dart';
import 'features/expense/data/expense_remote_datasource.dart';
import 'features/expense/repository/expense_repository.dart';
import 'package:firebase_core/firebase_core.dart';
import 'features/expense/providers/expense_provider.dart';
import 'features/expense/screens/dashboard_screen.dart';
import 'features/expense/screens/heatmap_calendar_screen.dart';
import 'features/expense/screens/analytics_screen.dart';
import 'features/auth/screens/profile_screen.dart';
import 'features/discipline/providers/discipline_provider.dart';
import 'features/dayend/providers/dayend_provider.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/category/providers/category_provider.dart';
import 'features/auth/screens/register_screen.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/forgot_password_screen.dart';
import 'features/sync/screens/sync_screen.dart';
import 'shared/theme/theme_provider.dart';
import 'firebase_options.dart';

import 'features/expense/providers/analytics_provider.dart';
import 'features/finance/providers/finance_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ---------------- FIREBASE INIT ----------------

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  // ---------------- HIVE INIT ----------------
  await HiveService.init();

  // ---------------- DATA LAYER ----------------
  final apiService = ApiService();
  final remoteDataSource = ExpenseRemoteDataSource(apiService);
  final repository = ExpenseRepository(remoteDataSource);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => FinanceProvider()),
        ChangeNotifierProvider(create: (_) => DisciplineProvider()),
        ChangeNotifierProvider(create: (_) => DayEndProvider()),
        ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(
          create: (_) {
            final provider = CategoryProvider();
            provider.init(); // 🔥 important
            return provider;
          },
        ),
        ChangeNotifierProvider(create: (_) => AnalyticsProvider()),
        ChangeNotifierProvider(create: (_) => ExpenseProvider(repository)),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'Expense Tracker',
          debugShowCheckedModeBanner: false,

          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.teal,
              brightness: Brightness.light,
            ),
            useMaterial3: true,
          ),

          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.teal,
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
          ),

          themeMode: themeProvider.themeMode,

          routes: {
            '/': (context) => const AuthWrapper(),
            '/register': (context) => const RegisterScreen(),
            '/forgot-password': (context) => const ForgotPasswordScreen(),
            '/login': (context) => const LoginScreen(),
            '/main': (context) => const MainScreen(),
          },

          home: const AuthWrapper(),
        );
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          return const MainScreen();
        }

        return const LoginScreen();
      },
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  bool _isSyncing = false;
  final SyncService _syncService = SyncService();

  final List<Widget> _screens = const [
    DashboardScreen(),
    HeatmapCalendarScreen(),
    AnalyticsScreen(),
    ProfileScreen(),
  ];

  final List<String> _titles = const [
    "Dashboard",
    "Calendar",
    "Analytics",
    "Profile",
  ];

  Future<void> _handleSync() async {
    setState(() => _isSyncing = true);
    try {
      final result = await _syncService.syncAll();

      if (!mounted) return;
      final categoryProvider = context.read<CategoryProvider>();
      final expenseProvider = context.read<ExpenseProvider>();
      final financeProvider = context.read<FinanceProvider>();

      // Refresh local providers from server
      await categoryProvider.fetchCategoriesFromServer();
      if (!mounted) return;
      await expenseProvider.fetchExpensesFromServer();
      if (!mounted) return;
      if (financeProvider.currentUserId != null) {
        await financeProvider.fetchFinanceFromServer(financeProvider.currentUserId!);
      }
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.isSuccess
                ? (result.pushedCount > 0
                    ? 'Sync complete: ${result.pushedCount} item(s) synced'
                    : 'All data is up to date')
                : (result.errorMessage ?? 'Sync completed with warnings'),
          ),
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'View',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SyncScreen()),
              );
            },
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_currentIndex]),
        centerTitle: true,
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        actions: [
          IconButton(
            icon: _isSyncing 
                ? const SizedBox(
                    width: 20, 
                    height: 20, 
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                  )
                : const Icon(Icons.sync),
            onPressed: _isSyncing ? null : _handleSync,
            tooltip: 'Fast Sync (Tap) / Open Sync Center (Long press)',
          ),
          IconButton(
            icon: const Icon(Icons.cloud_sync_outlined),
            tooltip: 'Sync Center',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SyncScreen()),
              );
            },
          ),
        ],
      ),

      body: _screens[_currentIndex],

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: theme.colorScheme.primary,
        unselectedItemColor: theme.colorScheme.onSurface.withValues(alpha: 0.6),
        showUnselectedLabels: false,
        showSelectedLabels: true,

        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },

        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month),
            label: 'Calendar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: 'Analytics',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

