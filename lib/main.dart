import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';
import 'theme/theme_provider.dart';
import 'screens/discovery_screen.dart';
import 'screens/streak_review_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/auth/login_screen.dart';
import 'services/fcm_service.dart';
import 'screens/vendor/vendor_onboarding_screen.dart';
import 'screens/vendor/vendor_shell.dart';
import 'screens/vendor/waiting_approval_screen.dart';
import 'screens/vendor/vendor_rejected_screen.dart';
import 'screens/vendor/vendor_suspended_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'widgets/bottom_nav_bar.dart';

final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
final _navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Keep the full Firestore cache so cached documents are available
  // instantly on every re-open, eliminating the loading flash.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  FCMService.messengerKey = _scaffoldMessengerKey;
  FCMService.navigatorKey = _navigatorKey;
  // Not awaited — the permission dialog (Android 13+) and token fetch
  // run after the UI is visible instead of blocking the first frame.
  FCMService.initialize();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const BinPerksApp(),
    ),
  );
}

class BinPerksApp extends StatelessWidget {
  const BinPerksApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return MaterialApp(
      title: 'Bin Perks',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: _scaffoldMessengerKey,
      navigatorKey: _navigatorKey,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: const AuthGate(),
    );
  }
}

// ── Auth gate ────────────────────────────────────────────────────

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          final currentUser = FirebaseAuth.instance.currentUser;
          if (currentUser != null) {
            return _RoleRouter(user: currentUser);
          }
          return const _Splash();
        }
        if (!snap.hasData) return const LoginScreen();
        return _RoleRouter(user: snap.data!);
      },
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();
  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
      body: const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );
  }
}

// _RoleRouter uses two live streams so it reacts immediately when:
// – the user doc is written after signup (fixes the race condition where
//   authStateChanges fires before Firestore doc creation completes)
// – the business doc appears after onboarding (keeps vendor locked to
//   onboarding until they finish)
class _RoleRouter extends StatelessWidget {
  final User user;
  const _RoleRouter({required this.user});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, userSnap) {
        if (userSnap.connectionState == ConnectionState.waiting && !userSnap.hasData) {
          return const _Splash();
        }
        final data = userSnap.data?.data() as Map<String, dynamic>?;
        final role = data?['role'] as String? ?? 'customer';

        if (role == 'admin') return const AdminDashboardScreen();
        if (role != 'vendor') return const AppShell();

        // Vendor: gate on whether their business doc exists and is approved
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('businesses')
              .doc(user.uid)
              .snapshots(),
          builder: (context, bizSnap) {
            if (bizSnap.connectionState == ConnectionState.waiting && !bizSnap.hasData) {
              return const _Splash();
            }
            if (bizSnap.data?.exists == true) {
              final bizData = bizSnap.data?.data() as Map<String, dynamic>?;
              final status = bizData?['status'] as String? ?? 'pending';

              if (status == 'approved') return const VendorShell();
              if (status == 'rejected') return VendorRejectedScreen(businessData: bizData ?? {});
              if (status == 'suspended') return VendorSuspendedScreen(businessData: bizData ?? {});
              return const WaitingApprovalScreen();
            }
            return const VendorOnboardingScreen();
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Customer app shell
// ─────────────────────────────────────────────────────────────────

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => AppShellState();
}

class AppShellState extends State<AppShell> {
  int _currentIndex = 0;

  static const List<Widget> _screens = [
    DiscoveryScreen(),
    StreakReviewScreen(),
    ProfileScreen(),
  ];

  void setTab(int index) => setState(() => _currentIndex = index);

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Only allow the system pop (exit) when already on the first tab
      canPop: _currentIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          // Back pressed on a non-home tab → return to Discover
          setState(() => _currentIndex = 0);
        }
      },
      child: Scaffold(
        extendBody: true,
        body: IndexedStack(index: _currentIndex, children: _screens),
        bottomNavigationBar: BinPerksBottomNav(
          currentIndex: _currentIndex,
          onTap: setTab,
        ),
      ),
    );
  }
}
