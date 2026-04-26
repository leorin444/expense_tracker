import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';

// 🔥 IMPORTANT: add this
import 'features/category/models/category.dart';

import 'features/expense/models/expense.dart';
import 'features/finance/models/finance_profile.dart';

import 'features/expense/providers/expense_provider.dart';
import 'features/expense/screens/dashboard_screen.dart';
import 'features/expense/screens/heatmap_calendar_screen.dart';
import 'features/expense/screens/analytics_screen.dart';
import 'features/auth/screens/profile_screen.dart';

import 'features/expense/data/expense_local_datasource.dart';
import 'features/expense/repository/expense_repository.dart';

import 'features/finance/providers/finance_provider.dart';
import 'features/discipline/providers/discipline_provider.dart';
import 'features/dayend/providers/dayend_provider.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/category/providers/category_provider.dart';
import 'features/auth/screens/register_screen.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/forgot_password_screen.dart';
import 'shared/theme/theme_provider.dart';
import 'firebase_options.dart';

import 'features/expense/providers/analytics_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ---------------- FIREBASE INIT ----------------

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // ---------------- HIVE INIT ----------------
  await Hive.initFlutter();
  if (!Hive.isAdapterRegistered(0)) {
    Hive.registerAdapter(ExpenseAdapter());
  }
  if (!Hive.isAdapterRegistered(1)) {
    Hive.registerAdapter(CategoryAdapter());
  }
  if (!Hive.isAdapterRegistered(2)) {
    Hive.registerAdapter(FinanceProfileAdapter());
  }

  // 🔥 OPEN BOXES
  await Hive.openBox<Expense>('expensesBox');
  await Hive.openBox<FinanceProfile>('financeProfilesBox');
  await Hive.openBox<Category>('categoriesBox'); // ✅ important
  // ---------------- DATA LAYER ----------------
  final datasource = ExpenseLocalDataSource();
  final repository = ExpenseRepository(datasource);

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

    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   context.read<ExpenseProvider>().syncAllExpenses();
    // });
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
            '/register': (context) => const RegisterScreen(),
            '/forgot-password': (context) => const ForgotPasswordScreen(),
            '/login': (context) => const LoginScreen(),
          },

          home: StreamBuilder(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasData) {
                return const MainScreen();
              }

              return const LoginScreen();
            },
          ),
        );
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_currentIndex]),
        centerTitle: true,
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        actions: null,
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
