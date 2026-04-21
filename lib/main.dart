import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'modules/sleep_analysis/providers/sleep_analysis_provider.dart';
import 'modules/onboarding/providers/onboarding_provider.dart';
import 'modules/journal/providers/journal_provider.dart';
import 'modules/paywall/providers/subscription_provider.dart';
import 'modules/onboarding/screens/welcome_screen.dart';
import 'core/providers/auth_provider.dart';
import 'screens/main_nav_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const SnoreClinicsApp());
}

class SnoreClinicsApp extends StatelessWidget {
  const SnoreClinicsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => OnboardingProvider()..loadProfile()),
        ChangeNotifierProvider(create: (_) => SleepAnalysisProvider()),
        ChangeNotifierProvider(create: (_) => JournalProvider()..loadEntries()),
        ChangeNotifierProvider(create: (_) => SubscriptionProvider()..init()),
      ],
      child: MaterialApp(
        title: 'SnoreClinics AI',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const _AppGate(),
        onGenerateRoute: AppRouter.generateRoute,
      ),
    );
  }
}

/// Decides whether to show the onboarding flow or main app on cold launch.
class _AppGate extends StatefulWidget {
  const _AppGate();
  @override
  State<_AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<_AppGate> {
  bool _ready = false;
  String? _lastUid;

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    // Give the provider a moment to load from shared_preferences
    await Future.delayed(const Duration(milliseconds: 200));
    if (mounted) setState(() => _ready = true);
  }

  void _syncSession(BuildContext context, String? currentUid) {
    if (_lastUid == currentUid) return;
    _lastUid = currentUid;

    // Trigger global data refresh
    Future.microtask(() {
      if (!mounted) return;
      context.read<OnboardingProvider>().loadProfile();
      context.read<JournalProvider>().loadEntries();
      context.read<SleepAnalysisProvider>().loadHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(
          child: Text('🌙', style: TextStyle(fontSize: 64)),
        ),
      );
    }

    // Listen for auth changes to trigger global reloads
    final auth = context.watch<AuthProvider>();
    _syncSession(context, auth.uid);

    final isComplete = context.watch<OnboardingProvider>().isComplete;
    return isComplete ? const MainNavScreen() : const WelcomeScreen();
  }
}
