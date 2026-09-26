import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_routes.dart';
import 'app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/contract_provider.dart';
import 'providers/contractor_address_provider.dart';
import 'providers/contractor_provider.dart';
import 'providers/document_provider.dart';
import 'providers/theme_mode_provider.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/login/login_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeModeProvider()..init()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ContractProvider()),
        ChangeNotifierProvider(create: (_) => DocumentProvider()),
        ChangeNotifierProvider(create: (_) => ContractorProvider()),
        ChangeNotifierProvider(create: (_) => ContractorAddressProvider()),
      ],
      child: Consumer<ThemeModeProvider>(
        builder: (context, theme, _) => MaterialApp(
          title: 'qontract',
          themeMode: theme.themeMode,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          routes: AppRoutes.routes,
          home: const HomeGate(),
        ),
      ),
    );
  }
}

/// Session gate: restores a saved session, then shows either the
/// dashboard (authenticated) or the login screen.
class HomeGate extends StatefulWidget {
  const HomeGate({super.key});

  @override
  State<HomeGate> createState() => _HomeGateState();
}

class _HomeGateState extends State<HomeGate> {
  bool _restoring = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _restore();
    });
  }

  Future<void> _restore() async {
    await context.read<AuthProvider>().checkSession();
    if (mounted) setState(() => _restoring = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_restoring) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final auth = context.watch<AuthProvider>();
    return auth.isAuthenticated
        ? const DashboardScreen()
        : const LoginScreen();
  }
}
